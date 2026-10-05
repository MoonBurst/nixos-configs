#!/usr/bin/env python3
# HimalayaSync.py — reads a stream of "FOLDER<TAB>JSON_LINE" records from
# stdin (one per folder), parses each folder's envelopes, deduplicates by
# (from.addr, subject, date), assigns a virtual folder label, and writes
# the merged result to ~/.cache/himalaya/emails.json.
#
# Priority order for dedupe (lower index wins):
#   inbox / steam / reddit    0   -- the message "belongs" here
#   sent / drafts / spam / trash  1
#   starred / important       2
#   archive (All Mail only)   3
#
# Cached message bodies are preserved across syncs by dedupe key so a
# refetch of envelopes does not throw away bodies already downloaded.

import sys
import json
import os
import re

cache_file = os.path.expanduser("~/.cache/himalaya/emails.json")

FOLDER_MAP = {
    "[gmail]/all mail": "archive",
    "[gmail]/sent mail": "sent",
    "[gmail]/drafts": "drafts",
    "[gmail]/spam": "spam",
    "[gmail]/trash": "trash",
    "[gmail]/starred": "starred",
    "[gmail]/important": "important",
}

PRIORITY = {
    "inbox": 0, "steam": 0, "reddit": 0,
    "sent": 1, "drafts": 1, "spam": 1, "trash": 1,
    "starred": 2, "important": 2,
    "archive": 3,
}


def dedupe_key_from_parts(addr, subject, date):
    return "{}|{}|{}".format(
        (addr or "").lower().strip(),
        (subject or "").strip(),
        (date or "").strip(),
    )


def dedupe_key(item):
    f = item.get("from") or {}
    addr = (f.get("addr") or "") if isinstance(f, dict) else ""
    return dedupe_key_from_parts(addr, item.get("subject", ""), item.get("date", ""))


# ---- Load previous cache to preserve bodies ---------------------------------
cached_bodies = {}
if os.path.exists(cache_file):
    try:
        with open(cache_file, "r", encoding="utf-8") as fh:
            existing = json.load(fh)
            if isinstance(existing, list):
                for item in existing:
                    body = item.get("body_content")
                    if body:
                        cached_bodies[dedupe_key(item)] = body
    except Exception:
        pass


# ---- Folder categorization --------------------------------------------------
def categorize(raw_folder, from_name, from_addr, subject):
    f = (raw_folder or "inbox").lower()
    s = "{} {} {}".format(from_name, from_addr, subject).lower()

    # Physical folder names take priority when we can recognize them
    if "trash" in f: return "trash"
    if "spam" in f: return "spam"
    if "sent" in f: return "sent"
    if "draft" in f: return "drafts"
    if "steam" in f: return "steam"
    if "reddit" in f: return "reddit"
    if "all mail" in f: return "archive"
    if "starred" in f: return "starred"
    if "important" in f: return "important"

    # Gmail IMAP returns "[Gmail]/All Mail" etc. Normalize with the map
    mapped = FOLDER_MAP.get(f)
    if mapped:
        return mapped

    # INBOX → per-sender heuristics for virtual Steam / Reddit folders
    if f == "inbox":
        if "steampowered.com" in s or "valvesoftware.com" in s:
            return "steam"
        if "redditmail.com" in s or "reddit.com" in s:
            return "reddit"
        return "inbox"

    return "inbox"


# ---- Address parsing --------------------------------------------------------
def parse_addresses(from_raw):
    from_name = ""
    from_addr = ""
    if isinstance(from_raw, dict):
        from_name = from_raw.get("name") or from_raw.get("addr") or "Unknown"
        from_addr = from_raw.get("addr") or ""
    elif isinstance(from_raw, str):
        m = re.search(r"<([^>]+)>", from_raw)
        if m:
            from_addr = m.group(1)
            from_name = from_raw.split("<")[0].strip() or from_addr
        else:
            from_addr = from_raw
            from_name = from_raw
    elif isinstance(from_raw, list) and from_raw:
        first = from_raw[0]
        if isinstance(first, dict):
            from_name = first.get("name") or first.get("addr") or "Unknown"
            from_addr = first.get("addr") or ""
        else:
            from_addr = str(first)
            from_name = str(first)
    return from_name, from_addr


# ---- Parse stdin ------------------------------------------------------------
by_key = {}

for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    folder, tab, raw_json = line.partition("\t")
    if not tab:
        continue
    try:
        envelopes = json.loads(raw_json)
    except Exception as e:
        sys.stderr.write("HimalayaSync: JSON parse error for {}: {}\n".format(folder, e))
        continue
    if not isinstance(envelopes, list):
        continue

    for env in envelopes:
        msg_id = str(env.get("id", ""))
        if not msg_id:
            continue

        subject = env.get("subject") or "(No Subject)"
        date = env.get("date") or ""
        from_name, from_addr = parse_addresses(env.get("from"))
        flags = [str(x).lower() for x in env.get("flags", [])] or ["unseen"]
        has_att = bool(env.get("has_attachment") or env.get("has-attachment") or False)
        target_folder = categorize(folder, from_name, from_addr, subject)

        item = {
            "id": msg_id,
            "folder": target_folder,
            # Physical IMAP folder name. The virtual `folder` label above is
            # only for the sidebar UI; body fetches must use this value
            # because himalaya resolves message IDs per-folder.
            "physical_folder": folder,
            "subject": subject,
            "date": date,
            "from": {"name": from_name or "Unknown", "addr": from_addr},
            "flags": flags,
            "has-attachment": has_att,
            "body_content": cached_bodies.get(
                dedupe_key_from_parts(from_addr, subject, date), ""
            ),
        }

        key = dedupe_key(item)
        existing = by_key.get(key)
        if existing is None:
            by_key[key] = item
        else:
            new_prio = PRIORITY.get(target_folder, 99)
            old_prio = PRIORITY.get(existing.get("folder"), 99)
            if new_prio < old_prio:
                by_key[key] = item


output = list(by_key.values())

os.makedirs(os.path.dirname(cache_file), exist_ok=True)
tmp_file = "{}.tmp.{}".format(cache_file, os.getpid())
with open(tmp_file, "w", encoding="utf-8") as fh:
    json.dump(output, fh, indent=2, ensure_ascii=False)
os.replace(tmp_file, cache_file)
