{ pkgs, osConfig, lib, config, ... }:

let
  homeDir = toString config.home.homeDirectory;
  myEmail = "moonburstplays@gmail.com";

  # NATIVE BUILD: Escaped characters force evaluation at runtime, preventing compile-time secret leaks
  syncMailHelper = pkgs.writeShellScriptBin "sync-mail-cache" ''
    CACHE_DIR="${homeDir}/.cache/himalaya"
    CACHE_FILE="$CACHE_DIR/emails.json"
    CONFIG_FILE="${homeDir}/.config/himalaya/config.toml"
    MBSYNC_FILE="${homeDir}/.config/mbsync/mbsyncrc"

    export HIMALAYA_GMAIL_ADDRESS="${myEmail}"
    export HIMALAYA_GMAIL_PASSWORD="$(${pkgs.coreutils}/bin/cat ${osConfig.sops.secrets.gmail_app_password.path})"

    ${pkgs.coreutils}/bin/mkdir -p "$CACHE_DIR"

    # Step 1: Run background delta download synchronization pass
    ${pkgs.isync}/bin/mbsync -c "$MBSYNC_FILE" gmail

    # Step 2: Compile full mail metadata down to a fast static JSON array cache file
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
    email = "${myEmail}"

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
    login = "${myEmail}"
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
    Host imap.gmail.com
    Port 993
    User "${myEmail}"
    PassCmd "cat ${osConfig.sops.secrets.gmail_app_password.path}"
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
      "username": "${myEmail}",
      "passwordCmd": "cat ${osConfig.sops.secrets.gmail_app_password.path}",
      "boxes": [ "INBOX" ],
      "onNewMail": "${syncMailHelper}/bin/sync-mail-cache",
      "onNewMailPost": "${pkgs.libnotify}/bin/notify-send 'New Mail Received'",
      "wait": 1
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
      ExecStart = "${pkgs.goimapnotify}/bin/goimapnotify -conf %h/.config/goimapnotify/goimapnotify.json";
      Restart = "always";
      RestartSec = "10";
    };
    Install = { WantedBy = [ "default.target" ]; };
  };
}
