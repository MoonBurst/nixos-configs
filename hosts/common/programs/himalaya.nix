{ pkgs, osConfig, lib, config, ... }:

let
  homeDir = toString config.home.homeDirectory;

  syncMailHelper = pkgs.writeScriptBin "sync-mail-cache" ''
    #!${pkgs.python3}/bin/python3
    import os
    import json
    import subprocess
    import shutil
    from concurrent.futures import ThreadPoolExecutor

    cache_dir = os.path.expanduser("~/.cache/himalaya")
    cache_file = os.path.join(cache_dir, "emails.json")
    config_file = os.path.expanduser("~/.config/himalaya/config.toml")
    mbsync_file = os.path.expanduser("~/.config/mbsync/mbsyncrc")
    queue_dir = os.path.join(cache_dir, "queue")

    try:
        with open("${osConfig.sops.secrets.gmail_address.path}", "r") as f:
            user_addr = f.read().strip()
        with open("${osConfig.sops.secrets.gmail_app_password.path}", "r") as f:
            user_pass = f.read().strip()
        os.environ["HIMALAYA_GMAIL_ADDRESS"] = user_addr
        os.environ["HIMALAYA_GMAIL_PASSWORD"] = user_pass
    except Exception:
        pass

    os.makedirs(queue_dir, exist_ok=True)

    if os.path.exists(queue_dir):
        for filename in os.listdir(queue_dir):
            file_path = os.path.join(queue_dir, filename)
            if os.path.isfile(file_path):
                temp_processing_path = f"/tmp/sending_{filename}"
                try:
                    shutil.move(file_path, temp_processing_path)
                except Exception:
                    continue

                with open(temp_processing_path, "r") as f:
                    draft_content = f.read()

                os.environ["HOSTALIASES"] = "/etc/hosts"
                res = subprocess.run(
                    ["${pkgs.himalaya}/bin/himalaya", "--config", config_file, "message", "send"],
                    input=draft_content, capture_output=True, text=True
                )

                if res.returncode == 0:
                    subprocess.run(["${pkgs.libnotify}/bin/notify-send", "Mail System", "Email sent successfully!", "-i", "mail-message-new"])
                    try:
                        os.remove(temp_processing_path)
                    except Exception:
                        pass
                else:
                    with open("/tmp/himalaya-send-error.log", "w") as err_f:
                        err_f.write(res.stderr)
                    subprocess.run(["${pkgs.libnotify}/bin/notify-send", "Mail System", "Failed to send email. Check /tmp/himalaya-send-error.log", "-u", "critical", "-i", "mail-message-alert"])
                    try:
                        shutil.move(temp_processing_path, file_path)
                    except Exception:
                        pass

    # Run the background sync passes sequentially
    subprocess.run(["${pkgs.isync}/bin/mbsync", "-c", mbsync_file, "gmail:INBOX"], capture_output=True)
    subprocess.run(["${pkgs.isync}/bin/mbsync", "-c", mbsync_file, "gmail"], capture_output=True)

    folder_map = {
        "inbox": "inbox", "all": "all", "drafts": "drafts", "sent": "sent",
        "trash": "trash", "spam": "spam", "starred": "starred", "important": "important"
    }

    def fetch_folder_data(target_folder):
        qml_label = folder_map[target_folder]
        res = subprocess.run([
            "${pkgs.himalaya}/bin/himalaya", "--config", config_file,
            "--output", "json", "envelope", "list", "--folder", target_folder, "--page-size", "500"
        ], capture_output=True, text=True)

        items = []
        if res.returncode == 0 and res.stdout.strip():
            try:
                raw_data = json.loads(res.stdout)
                envelopes = raw_data if isinstance(raw_data, list) else raw_data.get("envelopes", raw_data.get("items", []))
                for item in envelopes:
                    if isinstance(item, dict):
                        item["folder"] = qml_label
                        items.append(item)
            except Exception:
                pass
        return items

    master_list = []
    with ThreadPoolExecutor(max_workers=8) as executor:
        results = executor.map(fetch_folder_data, folder_map.keys())
        for folder_items in results:
            master_list.extend(folder_items)

    with open(cache_file + ".tmp", "w") as f:
        json.dump(master_list, f, indent=2)

    os.replace(cache_file + ".tmp", cache_file)
  '';
in
{
  home.packages = [
    pkgs.himalaya pkgs.isync pkgs.libnotify pkgs.ripgrep pkgs.gawk syncMailHelper
  ];

  # =========================================================================
  # Himalaya Core Configuration (FIXED: Corrected root folder namespace)
  # =========================================================================

  xdg.configFile."himalaya/config.toml".text = ''
    [accounts.gmail]
    default = true
    display-name = "Moonburst"
    email = "$HIMALAYA_GMAIL_ADDRESS"

    [accounts.gmail.backend]
    type = "maildir"
    root-dir = "${homeDir}/.local/share/mail/gmail"
    maildirpp = true

    # FIXED: Realigned the inbox key target mapping back to the standard plain native IMAP root layer
    [accounts.gmail.folder.aliases]
    inbox = "INBOX"
    all = ".[Gmail].All Mail"
    drafts = ".[Gmail].Drafts"
    sent = ".[Gmail].Sent Mail"
    trash = ".[Gmail].Trash"
    spam = ".[Gmail].Spam"
    starred = ".[Gmail].Starred"
    important = ".[Gmail].Important"

    [accounts.gmail.message.send.backend]
    type = "smtp"
    host = "://gmail.com"
    port = 465
    auth.type = "password"
    login = "$HIMALAYA_GMAIL_ADDRESS"
    auth.cmd = "echo $HIMALAYA_GMAIL_PASSWORD"

    [accounts.gmail.message.send.backend.encryption]
    type = "tls"

    [accounts.gmail.message.read]
    text-mime-header = "text/plain"

    [accounts.gmail.envelope.list]
    page-size = 500
  '';
  # =========================================================================
  # mbsync Local Configuration
  # =========================================================================

  xdg.configFile."mbsync/mbsyncrc".text = ''
    SyncState *
    IMAPAccount gmail
    Host ://gmail.com
    Port 993
    UserCmd "echo $HIMALAYA_GMAIL_ADDRESS"
    PassCmd "echo $HIMALAYA_GMAIL_PASSWORD"
    TLSType IMAPS
    CertificateFile /etc/ssl/certs/ca-certificates.crt
    AuthMechs PLAIN

    IMAPStore gmail-remote
    Account gmail

    MaildirStore gmail-local
    SubFolders Maildir++
    Inbox ${homeDir}/.local/share/mail/gmail/

    Channel gmail
    Far :gmail-remote:
    Near :gmail-local:
    Patterns "INBOX" "[Gmail]/All Mail" "[Gmail]/Drafts" "[Gmail]/Trash" "[Gmail]/Sent Mail" "[Gmail]/Spam" "[Gmail]/Starred" "[Gmail]/Important"
    Create Near
    Sync Pull Push
  '';

  home.activation.ensureMailDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${homeDir}/.local/share/mail/gmail/{cur,new,tmp}
    $DRY_RUN_CMD mkdir -p ${homeDir}/.cache/himalaya/queue
  '';

  # =========================================================================
  # Systemd User Services: Automated Inotify Path and Timer Engines
  # =========================================================================

  systemd.user.services.himalaya-sync = {
    Unit = { Description = "Himalaya background sync and queue dispatcher mail service pass"; };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c 'export HIMALAYA_GMAIL_ADDRESS=\$(${pkgs.coreutils}/bin/cat ${osConfig.sops.secrets.gmail_address.path} | ${pkgs.gnused}/bin/sed s/[[:space:]]//g); export HIMALAYA_GMAIL_PASSWORD=\$(${pkgs.coreutils}/bin/cat ${osConfig.sops.secrets.gmail_app_password.path} | ${pkgs.gnused}/bin/sed s/[[:space:]]//g); export HOSTALIASES=/etc/hosts; exec ${syncMailHelper}/bin/sync-mail-cache'";
    };
  };

  systemd.user.paths.himalaya-outbox-watcher = {
    Unit = { Description = "Monitor outbox queue folder path to trigger email transmissions instantly"; };
    Path = {
      PathChanged = "${homeDir}/.cache/himalaya/queue";
      Unit = "himalaya-sync.service";
    };
    Install = { WantedBy = [ "default.target" ]; };
  };

  systemd.user.timers.himalaya-incoming-timer = {
    Unit = { Description = "Automated timer engine pulls incoming mail from servers every 5 minutes"; };
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
      Unit = "himalaya-sync.service";
    };
    Install = { WantedBy = [ "timers.target" ]; };
  };
}
