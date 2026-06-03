{ pkgs, osConfig, lib, ... }:

let
gmailAddressFile = osConfig.sops.secrets.gmail_address.path;
gmailPassFile = osConfig.sops.secrets.gmail_app_password.path;
in
{
home.packages = [
pkgs.himalaya
pkgs.goimapnotify
pkgs.isync
pkgs.libnotify
];

# =========================================================================

# Himalaya Configuration

# =========================================================================

xdg.configFile."himalaya/config.toml".text = ''
[accounts.gmail]
default = true
display-name = "Moonburst"


email = "moonburstplays@gmail.com"

backend.type = "maildir"
backend.root-dir = "/home/moonburst/.local/share/mail/gmail"
backend.maildirpp = false

[accounts.gmail.folder.aliases]
inbox = "INBOX"
drafts = "[Gmail]/Drafts"
sent = "[Gmail]/Sent Mail"
trash = "[Gmail]/Trash"
spam = "[Gmail]/Spam"

[accounts.gmail.message.send.backend]
type = "smtp"
host = "smtp.gmail.com"
port = 465

login = "moonburstplays@gmail.com"

encryption.type = "tls"

auth.type = "password"
auth.cmd = "${pkgs.coreutils}/bin/cat ${gmailPassFile}"


'';

# =========================================================================

# mbsync Configuration

# =========================================================================

home.file.".mbsyncrc".text = ''
IMAPAccount gmail
Host imap.gmail.com
UserOpenCmd "${pkgs.coreutils}/bin/cat ${gmailAddressFile}"
PassCmd "${pkgs.coreutils}/bin/cat ${gmailPassFile}"
TLSType IMAPS


IMAPStore gmail-remote
Account gmail

MaildirStore gmail-local
SubFolders Verbatim
Path ~/.local/share/mail/gmail/
Inbox ~/.local/share/mail/gmail/INBOX

Channel gmail
Far :gmail-remote:
Near :gmail-local:
Patterns *
Create Near
Sync All
Expunge Near
SyncState *


'';

# =========================================================================

# goimapnotify Configuration

# =========================================================================

xdg.configFile."goimapnotify/goimapnotify.json".text =
builtins.toJSON {
host = "imap.gmail.com";
port = 993;
tls = true;


  usernameCmd =
    "${pkgs.coreutils}/bin/cat ${gmailAddressFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r '";

  passwordCmd =
    "${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r '";

  boxes = [ "INBOX" ];

  onNewMail =
    "${pkgs.bash}/bin/sh $HOME/.config/goimapnotify/sync-and-notify.sh";
};


xdg.configFile."goimapnotify/sync-and-notify.sh" = {
executable = true;


text = ''
  #!/bin/sh

  ${pkgs.isync}/bin/mbsync -c "$HOME/.mbsyncrc" gmail

  if [ $? -eq 0 ]; then
    ${pkgs.libnotify}/bin/notify-send \
      -i mail-unread \
      "Himalaya Mail" \
      "New email received in your Inbox!"
  else
    ${pkgs.libnotify}/bin/notify-send \
      -i dialog-error \
      "Himalaya Mail" \
      "Mail synchronization failed."
  fi
'';

};

# =========================================================================

# Maildir Creation

# =========================================================================

home.activation.ensureMailDir =
let
mkdir = "${pkgs.coreutils}/bin/mkdir";
in
lib.hm.dag.entryAfter [ "writeBoundary" ] ''
$DRY_RUN_CMD ${mkdir} -p $HOME/.local/share/mail/gmail
'';

# =========================================================================

# goimapnotify Service

# =========================================================================

systemd.user.services.go-imapnotify = {
Unit = {
Description = "Real-time IMAP IDLE mail synchronization daemon via mbsync";
After = [ "network.target" ];
};


Service = {
  Type = "simple";
  ExecStart =
    "${pkgs.goimapnotify}/bin/goimapnotify -conf %h/.config/goimapnotify/goimapnotify.json";

  Restart = "always";
  RestartSec = "10";
};

Install = {
  WantedBy = [ "default.target" ];
};

};
}
