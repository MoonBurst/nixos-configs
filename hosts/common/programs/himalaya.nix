{ pkgs, osConfig, lib, config, ... }:

let
  homeDir = toString config.home.homeDirectory;

  syncMailHelper = pkgs.writeScriptBin "sync-mail-cache" ''
    #!${pkgs.python3}/bin/python3
    import os
    import json
    import subprocess
    from concurrent.futures import ThreadPoolExecutor

    cache_dir = os.path.expanduser("~/.cache/himalaya")
    cache_file = os.path.join(cache_dir, "emails.json")
    config_file = os.path.expanduser("~/.config/himalaya/config.toml")
    mbsync_file = os.path.expanduser("~/.config/mbsync/mbsyncrc")

    try:
        with open("${osConfig.sops.secrets.gmail_address.path}", "r") as f:
            user_addr = f.read().strip()
        with open("${osConfig.sops.secrets.gmail_app_password.path}", "r") as f:
            user_pass = f.read().strip()
        os.environ["HIMALAYA_GMAIL_ADDRESS"] = user_addr
        os.environ["HIMALAYA_GMAIL_PASSWORD"] = user_pass
    except Exception:
        pass

    os.makedirs(cache_dir, exist_ok=True)

    # Step 1: Run bidirectional push-sync mail synchronization pass
    subprocess.run(["${pkgs.isync}/bin/mbsync", "-c", mbsync_file, "gmail"], capture_output=True)

    folder_map = {
        "inbox": "inbox",
        "all": "all",
        "drafts": "drafts",
        "sent": "sent",
        "trash": "trash",
        "spam": "spam",
        "starred": "starred",
        "important": "important"
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

    # FIXED: Corrected built-in syntax to perform a clean atomic file swap pass on disk
    os.replace(cache_file + ".tmp", cache_file)
  '';
in
{
  home.packages = [
    pkgs.himalaya
    pkgs.goimapnotify
    pkgs.isync
    pkgs.libnotify
    pkgs.ripgrep
    pkgs.gawk
    syncMailHelper
  ];

  # =========================================================================
  # Himalaya Core Configuration (MIME Read and Maildir Structures)
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

    [accounts.gmail.folder.aliases]
    inbox = ".[Gmail].Inbox"
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
    encryption.type = "tls"
    auth.type = "password"
    login = "$HIMALAYA_GMAIL_ADDRESS"
    auth.cmd = "cat ${osConfig.sops.secrets.gmail_app_password.path}"

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
    UserCmd "cat ${osConfig.sops.secrets.gmail_address.path} | tr -d '\\n\\r '"
    PassCmd "cat ${osConfig.sops.secrets.gmail_app_password.path} | tr -d '\\n\\r '"
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

  # =========================================================================
  # IMAP Monitoring Engine Automation
  # =========================================================================

  xdg.configFile."goimapnotify/goimapnotify.json".text = ''
    {
      "host": "://gmail.com",
      "port": 993,
      "tls": true,
      "tlsOptions": {
        "rejectUnauthorized": true
      },
      "usernameCmd": "echo \$HIMALAYA_GMAIL_ADDRESS",
      "passwordCmd": "echo \$HIMALAYA_GMAIL_PASSWORD",
      "boxes": [ "INBOX" ],
      "onNewMail": "${syncMailHelper}/bin/sync-mail-cache",
      "onNewMailPost": "${pkgs.libnotify}/bin/notify-send 'New Mail Received'"
    }
  '';

  home.activation.ensureMailDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${homeDir}/.local/share/mail/gmail/{cur,new,tmp}
  '';

  systemd.user.services.go-imapnotify = {
    Unit = {
      Description = "Real-time IMAP IDLE mail synchronization daemon via mbsync";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c 'export HIMALAYA_GMAIL_ADDRESS=\$(${pkgs.coreutils}/bin/cat ${osConfig.sops.secrets.gmail_address.path} | ${pkgs.gnused}/bin/sed s/[[:space:]]//g); export HIMALAYA_GMAIL_PASSWORD=\$(${pkgs.coreutils}/bin/cat ${osConfig.sops.secrets.gmail_app_password.path} | ${pkgs.gnused}/bin/sed s/[[:space:]]//g); exec ${pkgs.goimapnotify}/bin/goimapnotify -conf %h/.config/goimapnotify/goimapnotify.json'";
      Restart = "always";
      RestartSec = "5";
    };
    Install = { WantedBy = [ "default.target" ]; };
  };
}
