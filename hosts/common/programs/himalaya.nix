{ pkgs, osConfig, lib, config, ... }:

let
  homeDir = toString config.home.homeDirectory;

  syncMailHelper = pkgs.writeScriptBin "sync-mail-cache" ''#!${pkgs.python3}/bin/python3
import os, sys, json, subprocess, time, glob, configparser, sqlite3, getpass
from concurrent.futures import ThreadPoolExecutor

# FIXED: Dynamically fetch the current running username (works for any user)
real_user = getpass.getuser()
target_home = f"/home/{real_user}"

gmail_address = ""
gmail_password = ""

try:
    with open("/run/secrets/gmail_address", "r") as s: gmail_address = s.read().strip()
    with open("/run/secrets/gmail_app_password", "r") as s: gmail_password = s.read().strip()
except Exception as e:
    print(f"[Secrets Error]: Failed to read runtime secrets: {e}", flush=True)

cache_dir = f"{target_home}/.cache/himalaya"
cache_file = os.path.join(cache_dir, "emails.json")
mbsync_dir = f"{target_home}/.config/mbsync"
mbsync_file = os.path.join(mbsync_dir, "mbsyncrc")
himalaya_config_dir = f"{target_home}/.config/himalaya"
himalaya_config = os.path.join(himalaya_config_dir, "config.toml")

# Track back-filling intervals
last_backfill = 0

# Generate configuration files dynamically with valid hostnames and credentials
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
page-size = 500
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
Patterns "INBOX" "[Gmail]/All Mail" "[Gmail]/Drafts" "[Gmail]/Trash" "[Gmail]/Sent Mail" "[Gmail]/Spam" "[Gmail]/Starred"
Create Near
Sync All
Expunge Both
MaxMessages 5
""")

env_copy = os.environ.copy()
if gmail_address: env_copy["HIMALAYA_GMAIL_ADDRESS"] = gmail_address
if gmail_password: env_copy["HIMALAYA_GMAIL_PASSWORD"] = gmail_password

# ============================================================================
# NATIVE SYSTEM NOTIFICATION HELPER
# ============================================================================
def send_notification(title, message):
    try:
        subprocess.run(["${pkgs.libnotify}/bin/notify-send", "-a", "Mail Client", "-i", "mail-message", title, message])
    except Exception as e: print(f"[Notification Error]: {e}", flush=True)

# ============================================================================
# AUTOMATIC SQLITE OFFLINE DATABASE LOCATOR & DUPLICATE FILE FINDERS
# ============================================================================
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
    except Exception as e: print(f"[Queue Processor] Error finding duplicates: {e}", flush=True)
    return duplicates

# ============================================================================
# STANDARD INDEPENDENT COMMAND DISPATCHER (ZERO UID CONFLICTS)
# ============================================================================
def run_himalaya(args, folder):
    cmd = ["${pkgs.himalaya}/bin/himalaya", "--config", himalaya_config] + args + ["--folder", folder]
    return subprocess.run(cmd, capture_output=True, text=True, env=env_copy)

# ============================================================================
# LEAN TRANSACTIONAL SQLITE QUEUE ENGINE WITH ON-DEMAND BODY FETCHING
# ============================================================================
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

        print(f"[Queue Processor] Processing {len(rows)} pending action(s).", flush=True)
        actions_taken = False
        for row in rows:
            row_id, action, arg1, arg2, arg3 = row[0], row[1], row[2], row[3], row[4]

            # Simplified, standard execution (Gmail & mbsync handle folder propagation automatically!)
            if action == "DELETE":
                res = run_himalaya(["message", "delete", str(arg1)], arg2)
                if res.returncode == 0:
                    print(f"[Queue] Successfully deleted {arg1} from '{arg2}'", flush=True)
                    actions_taken = True
            elif action == "STAR":
                res = run_himalaya(["flag", "add", str(arg1), "flagged"], arg2)
                if res.returncode == 0:
                    print(f"[Queue] Successfully starred {arg1} in '{arg2}'", flush=True)
                    actions_taken = True
            elif action == "UNSTAR":
                res = run_himalaya(["flag", "remove", str(arg1), "flagged"], arg2)
                if res.returncode == 0:
                    print(f"[Queue] Successfully unstarred {arg1} in '{arg2}'", flush=True)
                    actions_taken = True
            elif action == "READ":
                res = run_himalaya(["flag", "add", str(arg1), "seen"], arg2)
                if res.returncode == 0:
                    print(f"[Queue] Successfully marked READ {arg1} in '{arg2}'", flush=True)
                    actions_taken = True
            elif action == "UNREAD":
                res = run_himalaya(["flag", "remove", str(arg1), "seen"], arg2)
                if res.returncode == 0:
                    print(f"[Queue] Successfully marked UNREAD {arg1} in '{arg2}'", flush=True)
                    actions_taken = True
            elif action == "SEND":
                raw_rfc_message = f"From: {gmail_address}\nTo: {arg1}\nSubject: {arg2}\nMIME-Version: 1.0\nContent-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: 8bit\n\n{arg3}"
                res = subprocess.run(["${pkgs.himalaya}/bin/himalaya", "--config", himalaya_config, "message", "send", "-"], input=raw_rfc_message, capture_output=True, text=True, env=env_copy)
                if res.returncode == 0:
                    send_notification("Email Sent", f"Successfully dispatched message to {arg1}")
                    actions_taken = True
                else: send_notification("Delivery Failure", f"Failed to send message to {arg1}")
            elif action == "CONTACT":
                contacts_file = f"{target_home}/Documents/Contacts"
                try:
                    os.makedirs(os.path.dirname(contacts_file), exist_ok=True)
                    contact_entry = f"{arg1} <{arg2}>" if arg1 else arg2
                    with open(contacts_file, "a") as cf: cf.write(f"\n{contact_entry}")
                    send_notification("Contact Saved", f"Successfully added {contact_entry} to contacts list.")
                    actions_taken = True
                except Exception as e: print(f"[Queue Error] Failed to write contact: {e}", flush=True)

            # ON-DEMAND BODY FETCHING (FALLBACK FOR OLDER/UNPREFETCHED MESSAGES)
            elif action == "FETCH_BODY":
                print(f"[Queue Processor] Lazy Fetching plain text body for message {arg1}...", flush=True)
                res = run_himalaya(["message", "read", str(arg1)], arg2)
                if res.returncode == 0:
                    raw_body = res.stdout.strip()
                    split_idx = raw_body.find("\n\n")
                    if split_idx == -1: split_idx = raw_body.find("\r\n\r\n")
                    if split_idx != -1: raw_body = raw_body[split_idx:].strip()
                    clean_body = "".join(ch for ch in raw_body if ord(ch) >= 32 or ch in "\n\r\t")

                    # 1. Output the active body to a standard temp file for instantaneous QML retrieval
                    temp_body_file = "/tmp/qmail_active_body.txt"
                    with open(temp_body_file, "w") as tf:
                        tf.write(f"{arg1}\n{clean_body}")

                    # 2. Write back to local cache permanently for future offline loads
                    if os.path.exists(cache_file):
                        try:
                            with open(cache_file, "r") as f: data = json.load(f)
                            clean_f = arg2.replace(".[Gmail].", "").lower()
                            for item in data:
                                if str(item.get("id")) == str(arg1) and item.get("folder") == clean_f:
                                    item["body_content"] = clean_body
                                    break
                            with open(cache_file, "w") as f: json.dump(data, f, indent=2)
                        except Exception as ce: print(f"[Queue Error] Cache write back error: {ce}", flush=True)
                else: print(f"[Queue Error] Failed to fetch body for {arg1}: {res.stderr.strip()}", flush=True)

            cursor.execute("DELETE FROM queue WHERE id = ?", (row_id,))
        conn.commit()
        conn.close()

        if actions_taken:
            rebuild_local_ui_cache()
            return True
    except Exception as e: print(f"[Queue Processor Error]: {e}", flush=True)
    return False

# Helper function to prevent indentation and nesting errors
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
    print("Rebuilding emails.json layout index cache vectors...", flush=True)
    folder_map = {
      "INBOX": "inbox", ".[Gmail].All Mail": "all", ".[Gmail].Drafts": "drafts",
      ".[Gmail].Sent Mail": "sent", ".[Gmail].Trash": "trash", ".[Gmail].Spam": "spam", ".[Gmail].Starred": "starred"
    }
    existing_bodies = load_existing_bodies(cache_file)
    old_ids = set()
    if os.path.exists(cache_file):
        try:
            with open(cache_file, "r") as f:
                for item in json.load(f):
                    m_id = item.get("message-id") or item.get("id")
                    if m_id: old_ids.add(m_id)
        except Exception: pass

    def fetch_folder_data(target_folder):
        qml_label = folder_map[target_folder]
        cmd = ["${pkgs.himalaya}/bin/himalaya", "--config", himalaya_config, "--output", "json", "envelope", "list", "--folder", target_folder, "--page-size", "500"]
        res = subprocess.run(cmd, capture_output=True, text=True, env=env_copy)
        items = []
        if res.returncode == 0 and res.stdout.strip():
            try:
                raw_data = json.loads(res.stdout)
                envelopes = raw_data if isinstance(raw_data, list) else raw_data.get("envelopes", raw_data.get("items", []))

                # Hybrid Pre-Fetching Rule:
                # - If the email is already cached, reuse the body.
                # - If the email is new, ONLY pre-fetch the body content if it is one of the top 15 most recent emails on disk.
                # - If it is older, start empty. It will be fetched instantly on-demand when clicked.
                for idx, item in enumerate(envelopes):
                    if isinstance(item, dict):
                        item["folder"] = qml_label
                        msg_id = item.get("id")
                        msg_unique_id = item.get("message-id") or msg_id

                        if msg_unique_id in existing_bodies:
                            item["body_content"] = existing_bodies[msg_unique_id]
                        elif msg_id and idx < 15: # LIMIT PRE-FETCH TO RECENT 15
                            read_cmd = ["${pkgs.himalaya}/bin/himalaya", "--config", himalaya_config, "message", "read", str(msg_id), "--folder", target_folder]
                            read_res = subprocess.run(read_cmd, capture_output=True, text=True, env=env_copy)
                            if read_res.returncode == 0:
                                raw_body = read_res.stdout.strip()
                                split_idx = raw_body.find("\n\n")
                                if split_idx == -1: split_idx = raw_body.find("\r\n\r\n")
                                if split_idx != -1: raw_body = raw_body[split_idx:].strip()
                                item["body_content"] = "".join(ch for ch in raw_body if ord(ch) >= 32 or ch in "\n\r\t")
                            else: item["body_content"] = ""
                        else:
                            item["body_content"] = ""
                        items.append(item)
            except Exception: pass
        return items

    master_list = []
    seen_signatures = set()
    with ThreadPoolExecutor(max_workers=8) as executor:
        results = executor.map(fetch_folder_data, folder_map.keys())
        for folder_items in results:
            for item in folder_items:
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
    print("[Live Queue Engine] Front-end UI cache synchronization pass finalized.", flush=True)

# ============================================================================
# GENTLE IDLE BACKGROUND BACK-FILLER ENGINE (Zero Resource footprint)
# ============================================================================
def run_gentle_backfill():
    global last_backfill
    current_time = time.time()
    if current_time - last_backfill < 30: return # Only run every 30 seconds
    last_backfill = current_time

    if not os.path.exists(cache_file): return

    try:
        with open(cache_file, "r") as f: data = json.load(f)

        # Identify a tiny, safe batch of up to 5 older uncached emails
        uncached_items = []
        for item in data:
            if not item.get("body_content") or item.get("body_content").strip() == "":
                uncached_items.append(item)
                if len(uncached_items) >= 5: break

        if not uncached_items: return # All emails are fully cached!

        print(f"[Background Backfill] Gentle-loading {len(uncached_items)} older message bodies...", flush=True)
        cache_updated = False

        for item in uncached_items:
            target_id = item.get("id")
            folder_label = item.get("folder")

            dup_folder = "INBOX"
            if folder_label == "starred": dup_folder = ".[Gmail].Starred"
            elif folder_label == "all": dup_folder = ".[Gmail].All Mail"
            elif folder_label == "drafts": dup_folder = ".[Gmail].Drafts"
            elif folder_label == "sent": dup_folder = ".[Gmail].Sent Mail"
            elif folder_label == "trash": dup_folder = ".[Gmail].Trash"
            elif folder_label == "spam": dup_folder = ".[Gmail].Spam"

            res = run_himalaya(["message", "read", str(target_id)], dup_folder)
            if res.returncode == 0:
                raw_body = res.stdout.strip()
                split_idx = raw_body.find("\n\n")
                if split_idx == -1: split_idx = raw_body.find("\r\n\r\n")
                if split_idx != -1: raw_body = raw_body[split_idx:].strip()
                item["body_content"] = "".join(ch for ch in raw_body if ord(ch) >= 32 or ch in "\n\r\t")
                cache_updated = True
                time.sleep(0.2) # Soft micro-sleep to prevent any CPU/server spikes

        if cache_updated:
            with open(cache_file + ".tmp", "w") as f: json.dump(data, f, indent=2)
            os.replace(cache_file + ".tmp", cache_file)
            print("[Background Backfill] Successfully cached batch. Visual database updated.", flush=True)
    except Exception as e: print(f"[Background Backfill Error]: {e}", flush=True)

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "--daemon":
    print("[Live Queue Engine] Instantiating high-performance reactive loop...", flush=True)
    last_sync = 0
    while True:
        process_live_text_queue()
        run_gentle_backfill() # Run the gentle background back-filler quietly on each idle loop pass
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
  home.packages = [ pkgs.himalaya pkgs.isync pkgs.libnotify syncMailHelper ];

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
