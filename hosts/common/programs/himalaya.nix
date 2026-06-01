{ pkgs, osConfig, ... }:

{
  home.packages = [
    pkgs.himalaya
  ];

  home.activation.generateHimalayaConfig = let
    cat = "${pkgs.coreutils}/bin/cat";
    mkdir = "${pkgs.coreutils}/bin/mkdir";
    tr = "${pkgs.coreutils}/bin/tr";
  in ''
    ${mkdir} -p ~/.config/himalaya

    EMAIL=$(${cat} '${osConfig.sops.secrets.gmail_address.path}' | ${tr} -d '\n' | ${tr} -d ' ')
    PASS_PATH='${osConfig.sops.secrets.gmail_app_password.path}'

    cat > ~/.config/himalaya/config.toml <<EOF
[accounts.gmail]
default = true
display-name = "Moonburst"
email = "$EMAIL"

[accounts.gmail.backend]
type = "imap"
host = "imap.gmail.com"
port = 993
login = "$EMAIL"

[accounts.gmail.backend.encryption]
type = "tls"

[accounts.gmail.backend.auth]
type = "password"
cmd = "${cat} $PASS_PATH"

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
login = "$EMAIL"

[accounts.gmail.message.send.backend.encryption]
type = "tls"

[accounts.gmail.message.send.backend.auth]
type = "password"
cmd = "${cat} $PASS_PATH"
EOF
  '';
}
