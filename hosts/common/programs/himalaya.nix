{ pkgs, osConfig, lib, config, ... }:

let
  homeDir = toString config.home.homeDirectory;

  syncMailHelper = pkgs.writeScriptBin "sync-mail-cache" ''#!${pkgs.python3}/bin/python3
import os, sys, json, subprocess, time, glob, configparser, sqlite3, getpass, re, shutil, mimetypes, socket, email.utils
from concurrent.futures import ThreadPoolExecutor

# Force all prints to immediately flush to systemd journal logs
_original_print = print
def print(*args, **kwargs):
    kwargs.setdefault('flush', True)
    _original_print(*args, **kwargs)

# Resolve usernames and directories dynamically
real_user = getpass.getuser()
target_home = f"/home/{real_user}"

gmail_address = ""
gmail_password = ""

try:
    with open("/run/secrets/gmail_address", "r") as s: gmail_address = s.read().strip()
    with open("/run/secrets/gmail_app_password", "r") as s: gmail_password = s.read().strip()
except Exception as e:
    print(f"[Secrets Error]: Failed to read runtime secrets: {e}")

cache_dir = f"{target_home}/.cache/himalaya"
cache_file = os.path.join(cache_dir, "emails.json")
mbsync_dir = f"{target_home}/.config/mbsync"
mbsync_file = os.path.join(mbsync_dir, "mbsyncrc")
himalaya_config_dir = f"{target_home}/.config/himalaya"
himalaya_config = os.path.join(himalaya_config_dir, "config.toml")
last_backfill = 0

# Generate dynamic configuration files with verified credentials
if gmail_address and gmail_password:
    os.makedirs(himalaya_config_dir, exist_ok=True)
    with open(himalaya_config, "w") as f:
        f.write(f"""[accounts.gmail]
default = true
display-name = "Moonburst"
email = "{gmail_address}"

[accounts.gmail.backend]
type = "maildir"
root-dir = "{target_home}/.local/share/mail/gmail"
maildirpp = true
delimiter = "."

[accounts.gmail.folder.aliases]
inbox = "INBOX"
all = ".[Gmail].All Mail"
steam = ".Steam"
drafts = ".[Gmail].Drafts"
sent = ".[Gmail].Sent Mail"
trash = ".[Gmail].Trash"
spam = ".[Gmail].Spam"
starred = ".[Gmail].Starred"

[accounts.gmail.message.send.backend]
type = "smtp"
host = "smtp.gmail.com"
port = 465
auth.type = "password"
login = "{gmail_address}"
auth.cmd = "echo '{gmail_password}'"

[accounts.gmail.message.send.backend.encryption]
type = "tls"

[accounts.gmail.message.read]
text-mime-header = "text/plain"

[accounts.gmail.envelope.list]
page-size = 100000
""")

    os.makedirs(mbsync_dir, exist_ok=True)
    with open(mbsync_file, "w") as f:
        f.write(f"""SyncState *
IMAPAccount gmail
Host imap.gmail.com
Port 993
User "{gmail_address}"
Pass "{gmail_password}"
TLSType IMAPS
CertificateFile /etc/ssl/certs/ca-certificates.crt
AuthMechs PLAIN
PipelineDepth 1

IMAPStore gmail-remote
Account gmail

MaildirStore gmail-local
SubFolders Maildir++
Inbox {target_home}/.local/share/mail/gmail

Channel gmail
Far :gmail-remote:
Near :gmail-local:
Patterns "INBOX" "Steam" "[Gmail]/All Mail" "[Gmail]/Drafts" "[Gmail]/Trash" "[Gmail]/Sent Mail" "[Gmail]/Spam" "[Gmail]/Starred"
Create Near
Sync All
Expunge Both
""")

env_copy = os.environ.copy()
if gmail_address: env_copy["HIMALAYA_GMAIL_ADDRESS"] = gmail_address
if gmail_password: env_copy["HIMALAYA_GMAIL_PASSWORD"] = gmail_password

def send_notification(title, message):
    try:
        subprocess.run(["${pkgs.libnotify}/bin/notify-send", "-a", "Mail Client", "-i", "mail-message", title, message])
    except Exception as e: print(f"[Notification Error]: {e}")

# Unified downloader and /tmp to Downloads folder movement router
def download_and_route_attachments(msg_id, folder, destination_dir, is_preview=False):
    # GUARD: Only skip download if we are generating cached previews and they already exist
    if is_preview and os.path.exists(destination_dir) and os.listdir(destination_dir):
        print(f"[Attachment Router] Previews already exist in {destination_dir}. Skipping download.")
        class DummyResult:
            returncode = 0
            stdout = ""
            stderr = ""
        return DummyResult()

    os.makedirs(destination_dir, exist_ok=True)
    cmd = ["${pkgs.himalaya}/bin/himalaya", "--config", himalaya_config, "attachment", "download", str(msg_id), "--folder", folder]
    res = subprocess.run(cmd, capture_output=True, text=True, env=env_copy, cwd=destination_dir)

    output_logs = res.stdout + "\n" + res.stderr
    downloaded_paths = re.findall(r'Downloading\s+"([^"]+)"', output_logs)

    # WRITE DEBUG LOG TO TMP FOR DIAGNOSTICS
    try:
        with open("/tmp/himalaya_last_download.log", "w") as lf:
            lf.write(f"DESTINATION: {destination_dir}\n")
            lf.write(f"RAW STDOUT/STDERR:\n{output_logs}\n")
            lf.write(f"PARSED PATHS: {downloaded_paths}\n")
    except Exception as le:
        print(f"[Debug Log Error] Failed to write file: {le}")

    for src_path in downloaded_paths:
        # Resolve paths relative to the destination_dir if they are not absolute
        actual_src = src_path if os.path.isabs(src_path) else os.path.join(destination_dir, src_path)
        if os.path.exists(actual_src):
            filename = os.path.basename(actual_src)
            dest_path = os.path.join(destination_dir, filename)
            if os.path.abspath(actual_src) != os.path.abspath(dest_path):
                try:
                    shutil.move(actual_src, dest_path)
                    print(f"[Attachment Router] Routed attachment: {actual_src} -> {dest_path}")
                except Exception as me:
                    print(f"[Attachment Router Error] Failed to route attachment: {me}")
        else:
            print(f"[Attachment Router Warning] Resolved path does not exist: {actual_src}")
    return res

def get_sqlite_db_path():
    search_paths = [
        f"{target_home}/.local/share/*/QML/OfflineStorage/Databases",
        f"{target_home}/.local/share/QML/OfflineStorage/Databases",
        f"{target_home}/.local/share/quickshell/QML/OfflineStorage/Databases",
    ]
    for pattern in search_paths:
        for ini_path in glob.glob(os.path.join(pattern, "*.ini")):
            try:
                config = configparser.ConfigParser()
                config.read(ini_path)
                if config.has_section("General") and config.get("General", "Name") == "QMailQueue":
                    return ini_path.replace(".ini", ".sqlite")
            except Exception: pass
    return None

def find_duplicate_items(cache_file_path, target_id, target_folder_clean):
    duplicates = []
    if not os.path.exists(cache_file_path): return duplicates
    try:
        with open(cache_file_path, "r") as f:
            data = json.load(f)
            target_item = next((item for item in data if str(item.get("id")) == str(target_id) and item.get("folder") == target_folder_clean), None)

            if target_item:
                target_sub = (target_item.get("subject") or "").strip()
                target_date = (target_item.get("date") or "").strip()
                t_from = target_item.get("from") or {}
                target_sender = (t_from.get("addr") or t_from.get("name") or target_item.get("sender") or "").strip()

                for item in data:
                    item_id, item_folder = item.get("id"), item.get("folder")
                    if str(item_id) == str(target_id) and item_folder == target_folder_clean: continue
                    i_from = item.get("from") or {}
                    item_sender = (i_from.get("addr") or i_from.get("name") or item.get("sender") or "").strip()
                    if (item.get("subject") or "").strip() == target_sub and (item.get("date") or "").strip() == target_date and item_sender == target_sender:
                        duplicates.append((item_id, item_folder))
    except Exception as e: print(f"[Queue Processor] Error finding duplicates: {e}")
    return duplicates

def run_himalaya(args, folder):
    cmd = ["${pkgs.himalaya}/bin/himalaya", "--config", himalaya_config] + args + ["--folder", folder]
    return subprocess.run(cmd, capture_output=True, text=True, env=env_copy)

# Lean Transactional SQLite Queue Engine
def process_live_text_queue():
    db_path = get_sqlite_db_path()
    if not db_path or not os.path.exists(db_path): return False

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("CREATE TABLE IF NOT EXISTS queue (id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT, arg1 TEXT, arg2 TEXT, arg3 TEXT)")
        conn.commit()
        cursor.execute("SELECT id, action, arg1, arg2, arg3 FROM queue ORDER BY id ASC")
        rows = cursor.fetchall()
        if not rows:
            conn.close()
            return False

        print(f"[Queue Processor] Processing {len(rows)} pending action(s).")
        actions_taken = False
        for row in rows:
            row_id, action, arg1, arg2, arg3 = row[0], row[1], row[2], row[3], row[4]

            if action == "DELETE":
                res = run_himalaya(["message", "delete", str(arg1)], arg2)
                if res.returncode == 0:
                    print(f"[Queue] Successfully deleted {arg1} from '{arg2}'")
                    actions_taken = True
            elif action == "STAR":
                res = run_himalaya(["flag", "add", str(arg1), "flagged"], arg2)
                if res.returncode == 0:
                    print(f"[Queue] Successfully starred {arg1} in '{arg2}'")
                    actions_taken = True
            elif action == "UNSTAR":
                res = run_himalaya(["flag", "remove", str(arg1), "flagged"], arg2)
                if res.returncode == 0:
                    print(f"[Queue] Successfully unstarred {arg1} in '{arg2}'")
                    actions_taken = True
            elif action == "READ":
                res = run_himalaya(["flag", "add", str(arg1), "seen"], arg2)
                if res.returncode == 0:
                    print(f"[Queue] Successfully marked READ {arg1} in '{arg2}'")
                    actions_taken = True
            elif action == "UNREAD":
                res = run_himalaya(["flag", "remove", str(arg1), "seen"], arg2)
                if res.returncode == 0:
                    print(f"[Queue] Successfully marked UNREAD {arg1} in '{arg2}'")
                    actions_taken = True
            elif action == "SEND":
                # Highly simplified, bulletproof filename and body extraction regex
                attachments = re.findall(r'filename="([^"]+)"', arg3)
                clean_body = re.sub(r'<#part[\s\S]*?</#part>', "", arg3).strip()

                print(f"[Queue Processor] Sending mail. Found attachments list: {attachments}")

                if attachments:
                    from email.mime.multipart import MIMEMultipart
                    from email.mime.text import MIMEText
                    from email.mime.base import MIMEBase
                    from email import encoders

                    msg = MIMEMultipart()
                    msg['MIME-Version'] = '1.0'
                    msg['From'] = gmail_address
                    msg['To'] = arg1
                    msg['Subject'] = arg2
                    msg.attach(MIMEText(clean_body, 'plain', 'utf-8'))

                    for filepath in attachments:
                        if os.path.exists(filepath):
                            try:
                                filename = os.path.basename(filepath)

                                # Guess MIME type dynamically based on file extension
                                ctype, encoding = mimetypes.guess_type(filepath)
                                if ctype is None or encoding is not None:
                                    ctype = "application/octet-stream"
                                maintype, subtype = ctype.split("/", 1)

                                with open(filepath, "rb") as f:
                                    part = MIMEBase(maintype, subtype)
                                    part.set_payload(f.read())
                                encoders.encode_base64(part)
                                part.add_header("Content-Disposition", "attachment", filename=filename)
                                msg.attach(part)
                                print(f"[Queue Processor] Successfully attached file to RFC payload (MIME: {ctype}): {filepath}")
                            except Exception as e:
                                print(f"[Queue Error] Failed to attach {filepath}: {e}")
                        else:
                            print(f"[Queue Warning] Attachment file not found: {filepath}")
                    raw_rfc_message = msg.as_string()
                else:
                    raw_rfc_message = f"From: {gmail_address}\nTo: {arg1}\nSubject: {arg2}\nMIME-Version: 1.0\nContent-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: 8bit\n\n{arg3}"

                res = subprocess.run(["${pkgs.himalaya}/bin/himalaya", "--config", himalaya_config, "message", "send", "-"], input=raw_rfc_message, capture_output=True, text=True, env=env_copy)
                if res.returncode == 0:
                    send_notification("Email Sent", f"Successfully dispatched message to {arg1}")
                    actions_taken = True
                else:
                    send_notification("Delivery Failure", f"Failed to send message to {arg1}")
                    print(f"[Queue Error] Send failure: {res.stderr.strip()}")
            elif action == "DRAFT":
                # Construction and file-handling of offline-first drafts
                # arg1: To (recipient), arg2: Subject, arg3: Body (content text)
                raw_rfc_message = f"From: {gmail_address}\nTo: {arg1}\nSubject: {arg2}\nMIME-Version: 1.0\nContent-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: 8bit\nDate: {email.utils.formatdate(localtime=True)}\n\n{arg3}"
                draft_dir = f"{target_home}/.local/share/mail/gmail/.[Gmail].Drafts/new"
                os.makedirs(draft_dir, exist_ok=True)

                hostname = socket.gethostname()
                pid = os.getpid()
                t = time.time()
                filename = f"{int(t)}.M{int((t - int(t)) * 1000000)}P{pid}Q1.{hostname}"
                filepath = os.path.join(draft_dir, filename)

                try:
                    with open(filepath, "w") as df:
                        df.write(raw_rfc_message)
                    print(f"[Queue Processor] Draft successfully saved to Maildir: {filepath}")
                    actions_taken = True
                except Exception as e:
                    print(f"[Queue Error] Failed to write draft to local storage: {e}")
            elif action == "CONTACT":
                contacts_file = f"{target_home}/Documents/Contacts"
                try:
                    os.makedirs(os.path.dirname(contacts_file), exist_ok=True)
                    contact_entry = f"{arg1} <{arg2}>" if arg1 else arg2
                    with open(contacts_file, "a") as cf: cf.write(f"\n{contact_entry}")
                    send_notification("Contact Saved", f"Successfully added {contact_entry} to contacts list.")
                    actions_taken = True
                except Exception as e: print(f"[Queue Error] Failed to write contact: {e}")
            elif action == "FETCH_BODY":
                print(f"[Queue Processor] Lazy Fetching message details for message {arg1}...")
                res = subprocess.run(["${pkgs.himalaya}/bin/himalaya", "--config", himalaya_config, "message", "read", str(arg1), "--folder", arg2], capture_output=True, text=True, env=env_copy)
                if res.returncode == 0:
                    clean_body = res.stdout.strip()
                    split_idx = clean_body.find("\n\n")
                    if split_idx == -1: split_idx = clean_body.find("\r\n\r\n")
                    if split_idx != -1: clean_body = clean_body[split_idx:].strip()

                    # Trigger file-system first visual preview extraction
                    preview_dir = f"{target_home}/.cache/himalaya/previews/{arg1}"
                    download_and_route_attachments(arg1, arg2, preview_dir, is_preview=True)
                    local_files = os.listdir(preview_dir) if os.path.exists(preview_dir) else []
                    attachments = [
                        {
                            "filename": fname,
                            "mime": "image/png" if fname.lower().endswith(".png") else ("text/plain" if fname.lower().endswith((".txt", ".zshrc", ".log", ".sh", ".conf")) else "application/octet-stream"),
                            "local_path": os.path.join(preview_dir, fname)
                        } for fname in local_files
                    ]

                    # Output active body to local temp file
                    temp_body_file = "/tmp/qmail_active_body.txt"
                    with open(temp_body_file, "w") as tf: tf.write(f"{arg1}\n{clean_body}")

                    # Write back to local cache permanently for future offline loads
                    if os.path.exists(cache_file):
                        try:
                            with open(cache_file, "r") as f: data = json.load(f)
                            clean_f = arg2.replace(".[Gmail].", "").lower()
                            for item in data:
                                if str(item.get("id")) == str(arg1) and item.get("folder") == clean_f:
                                    item["body_content"] = clean_body
                                    item["attachments"] = attachments
                                    break
                            with open(cache_file, "w") as f: json.dump(data, f, indent=2)
                        except Exception as ce: print(f"[Queue Error] Cache write back error: {ce}")
                else: print(f"[Queue Error] Failed to fetch body for {arg1}: {res.stderr.strip()}")

            elif action == "DOWNLOAD_ATTACHMENTS":
                target_id = arg1
                target_folder = arg2
                downloads_dir = f"{target_home}/Downloads"

                folder_mapping = {
                    "inbox": "INBOX", "starred": ".[Gmail].Starred", "all": ".[Gmail].All Mail", "steam": ".Steam",
                    "drafts": ".[Gmail].Drafts", "sent": ".[Gmail].Sent Mail", "trash": ".[Gmail].Trash", "spam": ".[Gmail].Spam"
                }
                canonical_folder = folder_mapping.get(target_folder.lower(), target_folder)

                print(f"[Queue Processor] Extracting all attachments for message {target_id} from folder '{canonical_folder}' to ~/Downloads...")
                res = download_and_route_attachments(target_id, canonical_folder, downloads_dir, is_preview=False)

                if res.returncode == 0:
                    print(f"[Queue Processor] Successfully extracted attachments for {target_id} to {downloads_dir}.")
                    send_notification("Attachments Downloaded", f"Successfully saved all extracted files to ~/Downloads")
                    try:
                        subprocess.run(["${pkgs.xdg-utils}/bin/xdg-open", downloads_dir])
                    except Exception as oe:
                        print(f"[Queue Processor Error] Failed to automatically open downloads folder: {oe}")
                else:
                    print(f"[Queue Processor Error] Failed to extract attachments: {res.stderr.strip()}")

            elif action == "MOVE":
                target_id = arg1
                source_folder = arg2
                dest_folder = arg3

                folder_mapping = {
                    "inbox": "INBOX", "starred": ".[Gmail].Starred", "all": ".[Gmail].All Mail", "steam": ".Steam",
                    "drafts": ".[Gmail].Drafts", "sent": ".[Gmail].Sent Mail", "trash": ".[Gmail].Trash", "spam": ".[Gmail].Spam"
                }
                canonical_source = folder_mapping.get(source_folder.lower(), source_folder)
                canonical_dest = folder_mapping.get(dest_folder.lower(), dest_folder)

                print(f"[Queue Processor] Moving message {target_id} from folder '{canonical_source}' to '{canonical_dest}'...")
                res = run_himalaya(["message", "move", canonical_dest, str(target_id)], canonical_source)
                if res.returncode == 0:
                    print(f"[Queue Processor] Successfully moved message {target_id} to '{canonical_dest}'.")
                    actions_taken = True
                else:
                    print(f"[Queue Processor Error] Failed to move message: {res.stderr.strip()}")

            cursor.execute("DELETE FROM queue WHERE id = ?", (row_id,))
        conn.commit()
        conn.close()

        if actions_taken:
            print("[Queue Processor] Pushing local modifications to remote mail servers...")
            subprocess.run(["${pkgs.isync}/bin/mbsync", "-c", mbsync_file, "gmail"], env=env_copy)
            rebuild_local_ui_cache()
            return True
    except Exception as e: print(f"[Queue Processor Error]: {e}")
    return False

def load_existing_bodies(cache_file_path):
    bodies = {}
    if not os.path.exists(cache_file_path): return bodies
    try:
        with open(cache_file_path, "r") as f:
            data = json.load(f)
            if isinstance(data, list):
                for item in data:
                    m_id = item.get("message-id") or item.get("id")
                    if m_id and item.get("body_content"): bodies[m_id] = item["body_content"]
    except Exception: pass
    return bodies

def rebuild_local_ui_cache():
    print("Rebuilding emails.json layout index cache vectors...")

    # Priority order maps the target directories to the local cache identifier.
    # Inbox, Starred, Steam, and Trash take priority over the master "All Mail" list.
    # Moving ".Steam" to the absolute top of the folder list ensures that all Steam emails
    # are strictly cataloged in the Steam tab, even if a copy resides in the Inbox.
    priority_folders = [
        (".Steam", "steam"),
        (".[Gmail].Starred", "starred"),
        ("INBOX", "inbox"),
        (".[Gmail].Trash", "trash"),
        (".[Gmail].Drafts", "drafts"),
        (".[Gmail].Sent Mail", "sent"),
        (".[Gmail].Spam", "spam"),
        (".[Gmail].All Mail", "all")
    ]

    existing_bodies = load_existing_bodies(cache_file)
    old_ids = set()
    if os.path.exists(cache_file):
        try:
            with open(cache_file, "r") as f:
                for item in json.load(f):
                    m_id = item.get("message-id") or item.get("id")
                    if m_id: old_ids.add(m_id)
        except Exception: pass

    def fetch_folder_data(target_folder, qml_label):
        cmd = ["${pkgs.himalaya}/bin/himalaya", "--config", himalaya_config, "--output", "json", "envelope", "list", "--folder", target_folder, "--page-size", "100000"]
        res = subprocess.run(cmd, capture_output=True, text=True, env=env_copy)
        items = []
        if res.returncode == 0 and res.stdout.strip():
            try:
                raw_data = json.loads(res.stdout)
                envelopes = raw_data if isinstance(raw_data, list) else raw_data.get("envelopes", raw_data.get("items", []))

                for idx, item in enumerate(envelopes):
                    if isinstance(item, dict):
                        item["folder"] = qml_label
                        msg_id = item.get("id")
                        msg_unique_id = item.get("message-id") or msg_id
                        has_att = item.get("has-attachment") or item.get("has_attachment") or False

                        if msg_unique_id in existing_bodies:
                            item["body_content"] = existing_bodies[msg_unique_id]
                        elif msg_id and idx < 15:
                            read_cmd = ["${pkgs.himalaya}/bin/himalaya", "--config", himalaya_config, "message", "read", str(msg_id), "--folder", target_folder]
                            read_res = subprocess.run(read_cmd, capture_output=True, text=True, env=env_copy)
                            if read_res.returncode == 0:
                                clean_body = read_res.stdout.strip()
                                split_idx = clean_body.find("\n\n")
                                if split_idx == -1: split_idx = clean_body.find("\r\n\r\n")
                                if split_idx != -1: clean_body = clean_body[split_idx:].strip()
                                item["body_content"] = clean_body
                            else:
                                item["body_content"] = ""
                        else:
                            item["body_content"] = ""

                        if has_att and msg_id:
                            print(f"[Cache Pre-fetch] Found attachments in message {msg_id}. Pre-downloading previews...")
                            preview_dir = f"{target_home}/.cache/himalaya/previews/{msg_id}"
                            download_and_route_attachments(msg_id, target_folder, preview_dir, is_preview=True)
                            local_files = os.listdir(preview_dir) if os.path.exists(preview_dir) else []
                            item["attachments"] = [
                                {
                                    "filename": fname,
                                    "mime": "image/png" if fname.lower().endswith(".png") else ("text/plain" if fname.lower().endswith((".txt", ".zshrc", ".log", ".sh", ".conf")) else "application/octet-stream"),
                                    "local_path": os.path.join(preview_dir, fname)
                                } for fname in local_files
                            ]
                        else:
                            item["attachments"] = []

                        items.append(item)
            except Exception: pass
        return items

    folder_results = {}
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(fetch_folder_data, target_folder, qml_label): target_folder for target_folder, qml_label in priority_folders}
        for future in futures:
            target_folder = futures[future]
            try:
                folder_results[target_folder] = future.result()
            except Exception:
                folder_results[target_folder] = []

    master_list = []
    seen_signatures = set()

    # Process collected folders strictly in the priority order.
    # An email found in primary folders will block duplicates from being saved inside "all" (All Mail).
    for target_folder, qml_label in priority_folders:
        for item in folder_results.get(target_folder, []):
            subject = (item.get("subject") or "").strip()
            date = (item.get("date") or "").strip()
            t_from = item.get("from") or {}
            sender = (t_from.get("addr") or t_from.get("name") or item.get("sender") or "").strip()

            sig = f"{subject}|{date}|{sender}"
            if sig not in seen_signatures:
                seen_signatures.add(sig)
                master_list.append(item)

    if old_ids and len(old_ids) > 0:
        new_emails = [item for item in master_list if (item.get("message-id") or item.get("id")) not in old_ids and item.get("folder") == "inbox"]
        if new_emails:
            for email in new_emails[:3]:
                sender = email.get("from", {}).get("name") or email.get("from", {}).get("addr") or "Unknown"
                send_notification(f"New Email from {sender}", email.get("subject") or "(No Subject)")
            if len(new_emails) > 3: send_notification("New Messages Received", f"You have received {len(new_emails) - 3} other new messages.")

    os.makedirs(cache_dir, exist_ok=True)
    with open(cache_file + ".tmp", "w") as f: json.dump(master_list, f, indent=2)
    os.replace(cache_file + ".tmp", cache_file)
    print("[Live Queue Engine] Front-end UI cache synchronization pass finalized.")

def run_gentle_backfill():
    global last_backfill
    current_time = time.time()
    if current_time - last_backfill < 30: return
    last_backfill = current_time

    if not os.path.exists(cache_file): return

    try:
        with open(cache_file, "r") as f: data = json.load(f)

        uncached_items = []
        for item in data:
            if not item.get("body_content") or item.get("body_content").strip() == "":
                uncached_items.append(item)
                if len(uncached_items) >= 5: break

        if not uncached_items: return

        print(f"[Background Backfill] Gentle-loading {len(uncached_items)} older message bodies...")
        cache_updated = False

        for item in uncached_items:
            target_id = item.get("id")
            folder_label = item.get("folder")
            has_att = item.get("has-attachment") or item.get("has_attachment") or False

            dup_folder = "INBOX"
            if folder_label == "starred": dup_folder = ".[Gmail].Starred"
            elif folder_label == "steam": dup_folder = ".Steam"
            elif folder_label == "all": dup_folder = ".[Gmail].All Mail"
            elif folder_label == "drafts": dup_folder = ".[Gmail].Drafts"
            elif folder_label == "sent": dup_folder = ".[Gmail].Sent Mail"
            elif folder_label == "trash": dup_folder = ".[Gmail].Trash"
            elif folder_label == "spam": dup_folder = ".[Gmail].Spam"

            res = subprocess.run(["${pkgs.himalaya}/bin/himalaya", "--config", himalaya_config, "message", "read", str(target_id), "--folder", dup_folder], capture_output=True, text=True, env=env_copy)
            if res.returncode == 0:
                clean_body = res.stdout.strip()
                split_idx = clean_body.find("\n\n")
                if split_idx == -1: split_idx = clean_body.find("\r\n\r\n")
                if split_idx != -1: clean_body = clean_body[split_idx:].strip()

                if has_att and target_id:
                    print(f"[Background Backfill] Found attachments in message {target_id}. Pre-downloading previews...")
                    preview_dir = f"{target_home}/.cache/himalaya/previews/{target_id}"
                    download_and_route_attachments(target_id, dup_folder, preview_dir, is_preview=True)
                    local_files = os.listdir(preview_dir) if os.path.exists(preview_dir) else []
                    attachments = [
                        {
                            "filename": fname,
                            "mime": "image/png" if fname.lower().endswith(".png") else ("text/plain" if fname.lower().endswith((".txt", ".zshrc", ".log", ".sh", ".conf")) else "application/octet-stream"),
                            "local_path": os.path.join(preview_dir, fname)
                        } for fname in local_files
                    ]
                else:
                    attachments = []

                item["body_content"] = clean_body
                item["attachments"] = attachments
                cache_updated = True
                time.sleep(0.2)

        if cache_updated:
            with open(cache_file + ".tmp", "w") as f: json.dump(data, f, indent=2)
            os.replace(cache_file + ".tmp", cache_file)
            print("[Background Backfill] Successfully cached batch. Visual database updated.")
    except Exception as e: print(f"[Background Backfill Error]: {e}")

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "--daemon":
    print("[Live Queue Engine] Instantiating high-performance reactive loop...", flush=True)
    last_sync = 0
    while True:
        process_live_text_queue()
        run_gentle_backfill()
        current_time = time.time()
        if current_time - last_sync > 300:
            print(f"Starting scheduled background mbsync sync pass...", flush=True)
            subprocess.run(["${pkgs.isync}/bin/mbsync", "-c", mbsync_file, "gmail"], env=env_copy)
            rebuild_local_ui_cache()
            last_sync = current_time
        time.sleep(0.1)
    sys.exit(0)

if __name__ == "__main__":
    subprocess.run(["${pkgs.isync}/bin/mbsync", "-c", mbsync_file, "gmail"], env=env_copy)
    rebuild_local_ui_cache()
  '';
in
{
  home.packages = [ pkgs.himalaya pkgs.isync pkgs.libnotify pkgs.xdg-utils syncMailHelper ];

  systemd.user.services.himalaya-sync = {
    Unit = {
      Description = "Himalaya active live-queue listener and mail engine sync process pass";
      After = [ "network.target" ] ;
    };
    Service = {
      Type = "simple";
      ExecStart = "${syncMailHelper}/bin/sync-mail-cache --daemon";
      Restart = "always";
      RestartSec = "2";
    };
    Install = { WantedBy = [ "default.target" ]; };
  };
}
