{ pkgs, osConfig, lib, config, ... }:

let
  homeDir = toString config.home.homeDirectory;

  # This script reads decrypted secrets directly from /run/secrets/ at runtime
  syncMailHelper = pkgs.writeScriptBin "sync-mail-cache" ''
    #!${pkgs.python3}/bin/python3
    import os, sys, json, subprocess
    from concurrent.futures import ThreadPoolExecutor

    gmail_address = ""
    gmail_password = ""

    # Safely load the absolute secret values from your decrypted SOPS memory mounts
    try:
        with open("/run/secrets/gmail_address", "r") as s:
            gmail_address = s.read().strip()
    except Exception: pass

    try:
        with open("/run/secrets/gmail_app_password", "r") as s:
            gmail_password = s.read().strip()
    except Exception: pass

    if not gmail_address: gmail_address = os.environ.get("HIMALAYA_GMAIL_ADDRESS", "")
    if not gmail_password: gmail_password = os.environ.get("HIMALAYA_GMAIL_PASSWORD", "")

    cache_dir = os.path.expanduser("~/.cache/himalaya")
    cache_file = os.path.join(cache_dir, "emails.json")
    mbsync_file = os.path.expanduser("~/.config/mbsync/mbsyncrc")

    # Set up our isolated environment copy for background child synchronization processes
    env_copy = os.environ.copy()
    if gmail_address: env_copy["HIMALAYA_GMAIL_ADDRESS"] = gmail_address
    if gmail_password: env_copy["HIMALAYA_GMAIL_PASSWORD"] = gmail_password

    print("Starting mbsync backend transfer...")
    res = subprocess.run(["${pkgs.isync}/bin/mbsync", "-c", mbsync_file, "gmail"], capture_output=True, text=True, env=env_copy)
    if res.returncode != 0:
        print(f"Mbsync Error:\n{res.stderr}")
        sys.exit(1)

    folder_map = {
      "inbox": "inbox",
      "[Gmail]/All Mail": "all",
      "[Gmail]/Drafts": "drafts",
      "[Gmail]/Sent Mail": "sent",
      "[Gmail]/Trash": "trash",
      "[Gmail]/Spam": "spam",
      "[Gmail]/Important": "important",
      "[Gmail]/Starred": "starred"
    }

    def fetch_folder_data(target_folder):
        qml_label = folder_map[target_folder]
        cmd = [
            "${pkgs.himalaya}/bin/himalaya",
            "--config", os.path.expanduser("~/.config/himalaya/config.toml"),
            "--output", "json",
            "envelope", "list",
            "--folder", target_folder,
            "--page-size", "500"
        ]

        res = subprocess.run(cmd, capture_output=True, text=True, env=env_copy)

        items = []
        if res.returncode == 0 and res.stdout.strip():
            try:
                raw_data = json.loads(res.stdout)
                envelopes = raw_data if isinstance(raw_data, list) else raw_data.get("envelopes", raw_data.get("items", []))
                for item in envelopes:
                    if isinstance(item, dict):
                        item["folder"] = qml_label
                        items.append(item)
            except Exception: pass
        return items

    master_list = []
    with ThreadPoolExecutor(max_workers=8) as executor:
        results = executor.map(fetch_folder_data, folder_map.keys())
        for folder_items in results: master_list.extend(folder_items)

    with open(cache_file + ".tmp", "w") as f:
        json.dump(master_list, f, indent=2)
    os.replace(cache_file + ".tmp", cache_file)
    print("Mail cache sync finalized successfully.")
  '';
in {
  home.packages = [
    pkgs.himalaya
    pkgs.isync
    pkgs.libnotify
    syncMailHelper
  ];

  xdg.configFile."himalaya/config.toml" = {
    force = true;
    text = ''
      [accounts.gmail]
      default = true
      display-name = "Moonburst"
      email = "$HIMALAYA_GMAIL_ADDRESS"

      [accounts.gmail.backend]
      type = "maildir"
      root-dir = "${homeDir}/.local/share/mail/gmail/"
      maildirpp = true
      delimiter = "/"

      [accounts.gmail.folder.aliases]
      inbox = "INBOX"
      all = "[Gmail]/All Mail"
      drafts = "[Gmail]/Drafts"
      sent = "[Gmail]/Sent Mail"
      trash = "[Gmail]/Trash"
      spam = "[Gmail]/Spam"
      starred = "[Gmail]/Starred"
      important = "[Gmail]/Important"

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
  };

  xdg.configFile."mbsync/mbsyncrc" = {
    force = true;
    text = ''
      SyncState *

      IMAPAccount gmail
      Host ://gmail.com
      Port 993
      UserCmd "echo $HIMALAYA_GMAIL_ADDRESS"
      PassCmd "echo $HIMALAYA_GMAIL_PASSWORD"
      TLSType IMAPS
      CertificateFile /etc/ssl/certs/ca-certificates.crt
      AuthMechs PLAIN
      PipelineDepth 1

      IMAPStore gmail-remote
      Account gmail

      MaildirStore gmail-local
      SubFolders Verbatim
      Path ${homeDir}/.local/share/mail/gmail/

      Channel gmail
      Far :gmail-remote:
      Near :gmail-local:
      Patterns "INBOX" "[Gmail]/All Mail" "[Gmail]/Drafts" "[Gmail]/Trash" "[Gmail]/Sent Mail" "[Gmail]/Spam" "[Gmail]/Starred" "[Gmail]/Important"
      Create Near
      Sync All
      Expunge Both
    '';
  };

  home.activation.ensureMailDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${homeDir}/.cache/himalaya/queue
  '';

  systemd.user.services.himalaya-sync = {
    Unit = {
      Description = "Himalaya background sync and queue dispatcher mail service pass";
      After = [ "network.target" ] ;
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c 'export HIMALAYA_GMAIL_ADDRESS=\$(${pkgs.coreutils}/bin/cat ${osConfig.sops.secrets.gmail_address.path} | ${pkgs.gnused}/bin/sed s/[[:space:]]//g); export HIMALAYA_GMAIL_PASSWORD=\$(${pkgs.coreutils}/bin/cat ${osConfig.sops.secrets.gmail_app_password.path} | ${pkgs.gnused}/bin/sed s/[[:space:]]//g); export PATH=${pkgs.coreutils}/bin:${pkgs.glibc}/bin:\$PATH; exec ${syncMailHelper}/bin/sync-mail-cache'";
    };
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
