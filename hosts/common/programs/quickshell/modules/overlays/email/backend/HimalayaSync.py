#!/usr/bin/env python3
import sys
import json
import os
import re

cache_file = os.path.expanduser("~/.cache/himalaya/emails.json")
cached_bodies = {}

# Preserve existing cached message bodies
if os.path.exists(cache_file):
    try:
        with open(cache_file, "r", encoding="utf-8") as f:
            existing = json.load(f)
            if isinstance(existing, list):
                for item in existing:
                    if "id" in item and item.get("body_content"):
                        cached_bodies[str(item["id"])] = item["body_content"]
    except Exception:
        pass

raw_input = sys.stdin.read().strip()
if not raw_input:
    sys.exit(0)

try:
    envelopes = json.loads(raw_input)
except Exception as e:
    sys.stderr.write(f"HimalayaSync JSON parse error: {e}\n")
    sys.exit(1)

if not isinstance(envelopes, list):
    sys.exit(0)

def categorize(raw_folder, from_name, from_addr, subject):
    f = (raw_folder or "inbox").lower()
    s = f"{from_name} {from_addr} {subject}".lower()
    if "trash" in f: return "trash"
    if "spam" in f: return "spam"
    if "sent" in f: return "sent"
    if "draft" in f: return "drafts"
    if "steampowered.com" in s or "valvesoftware.com" in s or "steam" in s:
        return "steam"
    if "redditmail.com" in s or "reddit.com" in s or "reddit" in s:
        return "reddit"
    return "inbox"

output = []
for env in envelopes:
    msg_id = str(env.get("id", ""))
    if not msg_id:
        continue

    subject = env.get("subject") or "(No Subject)"
    date = env.get("date") or ""

    from_raw = env.get("from")
    from_name = ""
    from_addr = ""

    if isinstance(from_raw, dict):
        from_name = from_raw.get("name") or from_raw.get("addr") or "Unknown"
        from_addr = from_raw.get("addr") or ""
    elif isinstance(from_raw, str):
        match = re.search(r"<([^>]+)>", from_raw)
        if match:
            from_addr = match.group(1)
            from_name = from_raw.split("<")[0].strip() or from_addr
        else:
            from_addr = from_raw
            from_name = from_raw
    elif isinstance(from_raw, list) and len(from_raw) > 0:
        first = from_raw[0]
        if isinstance(first, dict):
            from_name = first.get("name") or first.get("addr") or "Unknown"
            from_addr = first.get("addr") or ""
        else:
            from_addr = str(first)
            from_name = str(first)

    flags = [str(x).lower() for x in env.get("flags", [])]
    if not flags:
        flags = ["unseen"]

    has_att = bool(env.get("has_attachment") or env.get("has-attachment") or False)
    target_folder = categorize("inbox", from_name, from_addr, subject)

    output.append({
        "id": msg_id,
        "folder": target_folder,
        "subject": subject,
        "date": date,
        "from": {
            "name": from_name or "Unknown",
            "addr": from_addr
        },
        "flags": flags,
        "has-attachment": has_att,
        "body_content": cached_bodies.get(msg_id, "")
    })

os.makedirs(os.path.dirname(cache_file), exist_ok=True)
tmp_file = f"{cache_file}.tmp.{os.getpid()}"
with open(tmp_file, "w", encoding="utf-8") as f:
    json.dump(output, f, indent=2, ensure_ascii=False)
os.replace(tmp_file, cache_file)
