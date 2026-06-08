#!/usr/bin/env python3
import os
import sys
import json
import email
from email.policy import default
import re

def main():
    if len(sys.argv) < 2:
        print("Error: Missing target ID parameter.")
        sys.exit(1)

    target_id = str(sys.argv[1]).strip()
    raw_folder = str(sys.argv[2]).strip().upper() if len(sys.argv) > 2 else "INBOX"

    cache_path = os.path.expanduser("~/.cache/himalaya/emails.json")
    base_dir = os.path.expanduser("~/.local/share/mail/gmail")
    file_path = ""

    target_subject = ""
    target_from = ""

    # 1. Translate active QML folder name selections precisely to your new verbatim subfolders
    norm_folder = "inbox"
    verbatim_subfolder = ""

    if raw_folder in ["ALL MAIL", "ALL"]:
        norm_folder = "all"
        verbatim_subfolder = "[Gmail]/All Mail"
    elif raw_folder in ["TRASH"]:
        norm_folder = "trash"
        verbatim_subfolder = "[Gmail]/Trash"
    elif raw_folder in ["SPAM"]:
        norm_folder = "spam"
        verbatim_subfolder = "[Gmail]/Spam"
    elif raw_folder in ["SENT MAIL", "SENT"]:
        norm_folder = "sent"
        verbatim_subfolder = "[Gmail]/Sent Mail"
    elif raw_folder in ["DRAFTS"]:
        norm_folder = "drafts"
        verbatim_subfolder = "[Gmail]/Drafts"
    elif raw_folder in ["STARRED"]:
        norm_folder = "starred"
        verbatim_subfolder = "[Gmail]/Starred"
    elif raw_folder in ["IMPORTANT"]:
        norm_folder = "important"
        verbatim_subfolder = "[Gmail]/Important"

    # 2. Parse emails.json database cache using folder constraints to isolate IDs
    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8", errors="ignore") as f:
                data = json.load(f)

            items = data if isinstance(data, list) else next(
                (data[k] for k in ["envelopes", "items", "emails"] if k in data and isinstance(data[k], list)), []
            )

            for item in items:
                if not isinstance(item, dict):
                    continue
                env = item.get("envelope", item)
                item_folder = str(item.get("folder", "")).strip().lower()

                p_ids = []
                for obj in [item, env]:
                    if "id" in obj:
                        p_ids.append(str(obj["id"]["id"] if isinstance(obj["id"], dict) else obj["id"]))
                    if "uid" in obj:
                        p_ids.append(str(obj["uid"]))

                if any(pid.strip() == target_id for pid in p_ids if pid) and item_folder == norm_folder:
                    target_subject = env.get("subject", item.get("subject", ""))
                    from_data = env.get("from", item.get("from", ""))
                    target_from = from_data.get("addr", "") if isinstance(from_data, dict) else str(from_data)
                    file_path = item.get("filename", item.get("path", env.get("filename", env.get("path", ""))))
                    break
        except Exception:
            pass

    # Verify extracted cache path natively
    if file_path and os.path.exists(file_path):
        pass
    else:
        file_path = ""

    # 3. Target your physical subfolder directories directly using your new configuration paths
    target_dir = os.path.join(base_dir, verbatim_subfolder) if verbatim_subfolder else os.path.join(base_dir, "INBOX")
    search_pools = [target_dir]
    if target_dir != base_dir:
        search_pools.append(base_dir)

    # Clean up comparison signatures for deep fallback scanning
    clean_sub = target_subject.strip().lower() if target_subject else ""
    clean_from = re.sub(r'[^a-zA-Z0-9]', '', target_from.lower()) if target_from else ""

    # MATCH TRACK A: Search your newly moved directories using precise filename boundaries
    if not file_path:
        for pool in search_pools:
            for folder_type in ["cur", "new"]:
                search_path = os.path.join(pool, folder_type)
                if not os.path.exists(search_path):
                    continue
                for file in os.listdir(search_path):
                    # Anchor matching directly to filename sequence boundaries
                    if f"_{target_id}." in file or f",U={target_id}:" in file or file.endswith(f"_{target_id}"):
                        file_path = os.path.join(search_path, file)
                        break
                if file_path: break
            if file_path: break

    # MATCH TRACK B: Direct fallback search matching Subject Line + Sender Address
    if not file_path and (clean_sub or clean_from):
        for pool in search_pools:
            for folder_type in ["cur", "new"]:
                search_path = os.path.join(pool, folder_type)
                if not os.path.exists(search_path):
                    continue
                for file in os.listdir(search_path):
                    full_path = os.path.join(search_path, file)
                    try:
                        with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                            header_lines = [f.readline() for _ in range(40)]
                            header_chunk = "".join(header_lines).lower()

                            score = 0
                            if clean_sub and clean_sub in header_chunk: score += 10
                            if clean_from and clean_from in re.sub(r'[^a-zA-Z0-9]', '', header_chunk): score += 5

                            if score > best_score:
                                best_score = score
                                best_match = full_path
                                if score >= 15: break
                    except Exception: continue
                if file_path: break
            if file_path: break

    # MATCH TRACK C: Global emergency search across your entire directory tree
    if not file_path:
        for root, dirs, files in os.walk(base_dir):
            for file in files:
                if f"_{target_id}." in file or f",U={target_id}:" in file or file.endswith(f"_{target_id}"):
                    file_path = os.path.join(root, file)
                    break
            if file_path: break

    # 4. Extract and print out message text body content safely
    if file_path and os.path.exists(file_path):
        try:
            with open(file_path, "rb") as m_file:
                msg = email.message_from_binary_file(m_file, policy=default)

            body = msg.get_body(preferencelist=('plain', 'html'))
            if body:
                content = body.get_content()
                if body.get_content_type() == 'text/html':
                    content = re.sub(r'<[^>]+>', '', content)
                print(str(content).strip())
            else:
                parts = []
                for part in msg.walk():
                    if part.get_content_type() in ["text/plain", "text/html"]:
                        payload = part.get_payload(decode=True)
                        if payload:
                            text_str = payload.decode(part.get_content_charset() or "utf-8", errors="ignore")
                            if part.get_content_type() == 'text/html':
                                text_str = re.sub(r'<[^>]+>', '', text_str)
                            parts.append(text_str)
                print("".join(parts).strip() if parts else str(msg.get_payload()).strip())
        except Exception as err:
            print(f"Error parsing email content: {err}")
    else:
        print(f"Error: Unable to locate file on local disk for ID: {target_id}")

if __name__ == "__main__":
    main()
