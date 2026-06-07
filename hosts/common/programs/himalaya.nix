{ pkgs, osConfig, lib, config, ... }:

let
  gmailPassFile = osConfig.sops.secrets.gmail_app_password.path;
  gmailAddrFile = osConfig.sops.secrets.gmail_address.path;
  homeDir = config.home.homeDirectory;
in
{
  home.packages = [
    pkgs.himalaya
    pkgs.goimapnotify
    pkgs.isync
    pkgs.libnotify
    pkgs.ripgrep
    pkgs.gawk
  ];

  # =========================================================================
  # Declarative EmailProcesses.qml Configuration (Backend Workers Only)
  # =========================================================================

  home.file."nix/hosts/common/programs/quickshell/modules/overlays/launcher/Email/EmailProcesses.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Io

    Item {
        id: root

        required property QtObject controller

        signal mailListUpdated()
        signal messageLoaded()
        signal sendSucceeded()
        signal sendFailed()

        property var locallyDeletedIds: []

        function refreshMail() {
            controller.statusMessage = "Syncing mail cache..."
            forceCacheSyncDownstream.running = true
        }

        // FIXED: Utilized explicit Nix macro interpolation boundaries to substitute target path characters cleanly
        function updateMailListCommand() {
            mailList.command = [
                "${pkgs.bash}/bin/sh", "-c",
                "export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r ')\"; ${pkgs.himalaya}/bin/himalaya --config ${homeDir}/.config/himalaya/config.toml --output json envelope list --page 1 --page-size 500"
            ];
        }

        function sendEmail(from, to, subject, body) {
            sendEmailProcess.command = [
                "${pkgs.bash}/bin/sh", "-c",
                "export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r ')\"; ${pkgs.coreutils}/bin/cat > /tmp/qs-mail.eml <<'EOF'\nFrom: " + from + "\nTo: " + to + "\nSubject: " + subject + "\n\n" + body + "\nEOF\n" +
                "${pkgs.himalaya}/bin/himalaya message send < /tmp/qs-mail.eml"
            ];
            sendEmailProcess.running = true;
        }

        function loadMessage(messageId) {
            readMessage.command = [
                "${pkgs.bash}/bin/sh", "-c",
                "export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r ')\"; ${pkgs.himalaya}/bin/himalaya --config ${homeDir}/.config/himalaya/config.toml message read " + messageId
            ];
            readMessage.running = true;
        }

        function deleteMessage(messageId) {
            var tmpDeleted = root.locallyDeletedIds.slice();
            tmpDeleted.push(String(messageId));
            root.locallyDeletedIds = tmpDeleted;

            deleteMessageProcess.command = [
                "${pkgs.bash}/bin/sh", "-c",
                "export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r ')\"; " +
                "export HIMALAYA_GMAIL_PASSWORD=\"$(${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r ')\"; " +
                "${pkgs.himalaya}/bin/himalaya --config ${homeDir}/.config/himalaya/config.toml message delete --account gmail " + messageId + " 2>/tmp/himalaya-error.log"
            ];
            deleteMessageProcess.running = false
            deleteMessageProcess.running = true
        }

        Component.onCompleted: {
            readSopsSecret.running = true
        }

        Process {
            id: readSopsSecret
            command: [ "${pkgs.coreutils}/bin/cat", "${gmailAddrFile}" ]
            stdout: StdioCollector {
                onStreamFinished: {
                    controller.userEmailAddress = text.trim()
                    root.updateMailListCommand()
                    mailList.running = true
                }
            }
        }

        Process {
            id: forceCacheSyncDownstream
            command: [ "${pkgs.bash}/bin/sh", "-c", "export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r ')\"; export HIMALAYA_GMAIL_PASSWORD=\"$(${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r ')\"; ${pkgs.isync}/bin/mbsync -c ${homeDir}/.config/mbsync/mbsyncrc gmail" ]
            onRunningChanged: {
                if (!forceCacheSyncDownstream.running) {
                    mailList.running = false;
                    root.updateMailListCommand();
                    mailList.running = true;
                }
            }
        }

        Process {
            id: mailList
            stdout: StdioCollector {
                onStreamFinished: {
                    var raw = text.trim();
                    if (!raw.length) {
                        controller.emails = [];
                        root.mailListUpdated();
                        return;
                    }
                    try {
                        var parsedData = JSON.parse(raw);
                        var targetArray = [];
                        var rawItems = Array.isArray(parsedData) ? parsedData : (parsedData.envelopes || parsedData.items || []);
                        for (var i = 0; i < rawItems.length; i++) {
                            var item = rawItems[i];
                            var itemId = item.id ? String(item.id) : "";
                            if (root.locallyDeletedIds.indexOf(itemId) === -1) {
                                targetArray.push(item);
                            }
                        }
                        controller.emails = targetArray;
                        controller.statusMessage = targetArray.length + " message(s)";
                    } catch (e) {
                        controller.statusMessage = "Parse Error";
                    }
                    root.mailListUpdated();
                }
            }
        }

        Process { id: readMessage; stdout: StdioCollector { onStreamFinished: { controller.messageBody = text; root.messageLoaded(); } } }
        Process { id: sendEmailProcess; onRunningChanged: { if (!sendEmailProcess.running) root.refreshMail(); } }
        Process { id: deleteMessageProcess; onRunningChanged: { if (!deleteMessageProcess.running) root.refreshMail(); } }
    }
  '';
  # =========================================================================
  # Himalaya Live Configuration
  # =========================================================================

  xdg.configFile."himalaya/config.toml".text = ''
    [accounts.gmail]
    default = true
    display-name = "Moonburst"
    email = "$HIMALAYA_GMAIL_ADDRESS"

    [accounts.gmail.backend]
    type = "maildir"
    root-dir = "${homeDir}/.local/share/mail/gmail/[Gmail]/Important"
    maildirpp = false

    [accounts.gmail.folder.aliases]
    inbox = "."
    drafts = "${homeDir}/.local/share/mail/gmail/[Gmail]/Drafts"
    sent = "${homeDir}/.local/share/mail/gmail/[Gmail]/Sent Mail"
    trash = "${homeDir}/.local/share/mail/gmail/[Gmail]/Trash"
    spam = "${homeDir}/.local/share/mail/gmail/[Gmail]/Spam"

    [accounts.gmail.message.send.backend]
    type = "smtp"
    host = "://gmail.com"
    port = 465
    login = "$HIMALAYA_GMAIL_ADDRESS"
    encryption.type = "tls"
    auth.type = "password"
    auth.cmd = 'echo $HIMALAYA_GMAIL_PASSWORD'

    [accounts.gmail.message.read]
    text-mime-header = "text/plain"

    [accounts.gmail.envelope.list]
    page-size = 500
  '';

  # =========================================================================
  # mbsync Live Configuration
  # =========================================================================

  xdg.configFile."mbsync/mbsyncrc".text = ''
    SyncState *

    IMAPAccount gmail
    Host ://gmail.com
    TLSType IMAPS
    CertificateFile /etc/ssl/certs/ca-certificates.crt
    UserCmd "${pkgs.bash}/bin/sh -c '${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d \"\\n\\r \"'"
    PassCmd "${pkgs.bash}/bin/sh -c '${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d \"\\n\\r \"'"

    IMAPStore gmail-remote
    Account gmail

    MaildirStore gmail-local
    SubFolders Verbatim
    Path ${homeDir}/.local/share/mail/gmail/
    Inbox ${homeDir}/.local/share/mail/gmail/INBOX

    Channel gmail
    Far :gmail-remote:
    Near :gmail-local:
    Patterns * \![Gmail]/All_Mail \!" [Gmail]/All Mail"
    Create Near
    Sync All
    Expunge Near
    Expunge Far
  '';

  # =========================================================================
  # goimapnotify Configuration
  # =========================================================================

  xdg.configFile."goimapnotify/goimapnotify.json".text = builtins.toJSON {
    host = "://gmail.com";
    port = 993;
    tls = true;
    usernameCmd = "${pkgs.bash}/bin/sh -c '${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d \"\\\\n\\\\r \"'";
    passwordCmd = "${pkgs.bash}/bin/sh -c '${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d \"\\\\n\\\\r \"'";
    boxes = [ "[Gmail]/Important" ];
    onNewMail = "${pkgs.bash}/bin/sh -c 'export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d \"\\\\n\\\\r \")\"; export HIMALAYA_GMAIL_PASSWORD=\"$(${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d \"\\\\n\\\\r \")\"; ${pkgs.isync}/bin/mbsync -c ${homeDir}/.config/mbsync/mbsyncrc gmail'";
  };

  # =========================================================================
  # Maildir Directory Verification
  # =========================================================================

  home.activation.ensureMailDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p ${homeDir}/.local/share/mail/gmail
  '';

  # =========================================================================
  # Centralized background IMAP systemd worker service
  # =========================================================================

  systemd.user.services.go-imapnotify = {
    Unit = {
      Description = "Real-time IMAP IDLE mail synchronization daemon via mbsync";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/sh -c 'export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d \"\\\\n\\\\r \")\"; export HIMALAYA_GMAIL_PASSWORD=\"$(${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d \"\\\\n\\\\r \")\"; ${pkgs.goimapnotify}/bin/goimapnotify -conf %h/.config/goimapnotify/goimapnotify.json'";
      Restart = "always";
      RestartSec = "10";
    };
    Install = { WantedBy = [ "default.target" ]; };
  };
}
