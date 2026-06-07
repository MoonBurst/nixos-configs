{ pkgs, osConfig, lib, config, ... }:

let
  homeDir = toString config.home.homeDirectory;

  syncMailHelper = pkgs.writeShellScriptBin "sync-mail-cache" ''
    CACHE_DIR="${homeDir}/.cache/himalaya"
    CACHE_FILE="$CACHE_DIR/emails.json"
    CONFIG_FILE="${homeDir}/.config/himalaya/config.toml"
    MBSYNC_FILE="${homeDir}/.config/mbsync/mbsyncrc"

    export HIMALAYA_GMAIL_ADDRESS="$(${pkgs.coreutils}/bin/cat ${osConfig.sops.secrets.gmail_address.path} | ${pkgs.gnused}/bin/sed 's/[[:space:]]//g')"
    export HIMALAYA_GMAIL_PASSWORD="$(${pkgs.coreutils}/bin/cat ${osConfig.sops.secrets.gmail_app_password.path} | ${pkgs.gnused}/bin/sed 's/[[:space:]]//g')"

    ${pkgs.coreutils}/bin/mkdir -p "$CACHE_DIR"

    ${pkgs.isync}/bin/mbsync -c "$MBSYNC_FILE" gmail

    ${pkgs.himalaya}/bin/himalaya --config "$CONFIG_FILE" --output json envelope list --page-size 500 > "$CACHE_FILE.tmp"

    if [ -s "$CACHE_FILE.tmp" ]; then
        ${pkgs.coreutils}/bin/mv "$CACHE_FILE.tmp" "$CACHE_FILE"
    fi
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
    sent = "Sent"
    trash = ".[Gmail].Trash"
    spam = "Spam"

    [accounts.gmail.message.send.backend]
    type = "smtp"
    host = "smtp.gmail.com"
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
  # mbsync Local Configuration (FIXED: Uses echo to pass scrubbed env variables)
  # =========================================================================

  xdg.configFile."mbsync/mbsyncrc".text = ''
    SyncState *

    IMAPAccount gmail
    Host imap.gmail.com
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
    Patterns "INBOX" "[Gmail]/All Mail" "[Gmail]/Drafts" "[Gmail]/Trash"
    Create Near
    Sync Pull
  '';

  # =========================================================================
  # IMAP Monitoring Engine Automation
  # =========================================================================

  xdg.configFile."goimapnotify/goimapnotify.json".text = ''
    {
      "host": "imap.gmail.com",
      "port": 993,
      "tls": true,
      "tlsOptions": {
        "rejectUnauthorized": true
      },
      "usernameCmd": "cat ${osConfig.sops.secrets.gmail_address.path} | tr -d '\\n\\r '",
      "passwordCmd": "cat ${osConfig.sops.secrets.gmail_app_password.path} | tr -d '\\n\\r '",
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
      # FIXED: Exports variables explicitly to the environment block before launching go-imapnotify
      ExecStart = "${pkgs.bash}/bin/bash -c 'export HIMALAYA_GMAIL_ADDRESS=$(${pkgs.coreutils}/bin/cat ${osConfig.sops.secrets.gmail_address.path} | ${pkgs.gnused}/bin/sed s/[[:space:]]//g); export HIMALAYA_GMAIL_PASSWORD=$(${pkgs.coreutils}/bin/cat ${osConfig.sops.secrets.gmail_app_password.path} | ${pkgs.gnused}/bin/sed s/[[:space:]]//g); exec ${pkgs.goimapnotify}/bin/goimapnotify -conf %h/.config/goimapnotify/goimapnotify.json'";
      Restart = "always";
      RestartSec = "5";
    };
    Install = { WantedBy = [ "default.target" ]; };
  };
}
