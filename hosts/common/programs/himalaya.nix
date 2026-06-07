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
  ];

  # =========================================================================
  # Centralized EmailProcesses.qml Configuration (Optimized Context)
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

        function updateMailListCommand() {
            var shellPrefix = "export HIMALAYA_GMAIL_ADDRESS=\"$(cat " + gmailAddrFile + ")\"; ";

            if (controller.isImportantOnlyView) {
                mailList.command = [
                    "${pkgs.bash}/bin/sh", "-c",
                    shellPrefix + "${pkgs.himalaya}/bin/himalaya --config ${homeDir}/.config/himalaya/config.toml --output json envelope list --page 1 --page-size 500 --query flagged | ${pkgs.coreutils}/bin/tee /tmp/qs-raw-emails.json"
                ];
            } else {
                mailList.command = [
                    "${pkgs.bash}/bin/sh", "-c",
                    shellPrefix + "${pkgs.himalaya}/bin/himalaya --config ${homeDir}/.config/himalaya/config.toml --output json envelope list --page 1 --page-size 500 | ${pkgs.coreutils}/bin/tee /tmp/qs-raw-emails.json"
                ];
            }
        }

        function sendEmail(from, to, subject, body) {
            sendRawEmail(
                "From: " + from + "\n" +
                "To: " + to + "\n" +
                "Subject: " + subject + "\n\n" +
                body
            )
        }

        function sendRawMessage(content) {
            sendRawEmail(content)
        }

        function sendRawEmail(content) {
            var shellPrefix = "export HIMALAYA_GMAIL_ADDRESS=\"$(cat " + gmailAddrFile + ")\"; ";

            sendEmailProcess.command = [
                "${pkgs.bash}/bin/sh", "-c",
                shellPrefix + "${pkgs.coreutils}/bin/cat > /tmp/qs-mail.eml <<'EOF'\n" + content + "\nEOF\n" +
                "${pkgs.himalaya}/bin/himalaya message send < /tmp/qs-mail.eml > /tmp/himalaya-send.log 2> /tmp/himalaya-error.log"
            ]
            sendEmailProcess.running = false
            sendEmailProcess.running = true
        }

        function loadMessage(messageId) {
            var shellPrefix = "export HIMALAYA_GMAIL_ADDRESS=\"$(cat " + gmailAddrFile + ")\"; ";
            readMessage.command = [
                "${pkgs.bash}/bin/sh", "-c",
                shellPrefix + "${pkgs.himalaya}/bin/himalaya --config ${homeDir}/.config/himalaya/config.toml message read " + messageId
            ]
            readMessage.running = true
        }

        function deleteMessage(messageId) {
            var tmpDeleted = root.locallyDeletedIds.slice();
            tmpDeleted.push(String(messageId));
            root.locallyDeletedIds = tmpDeleted;

            var shellPrefix = "export HIMALAYA_GMAIL_ADDRESS=\"$(cat " + gmailAddrFile + ")\"; ";
            deleteMessageProcess.command = [
                "${pkgs.bash}/bin/sh", "-c",
                shellPrefix + "${pkgs.himalaya}/bin/himalaya --config ${homeDir}/.config/himalaya/config.toml message delete " + messageId
            ]
            deleteMessageProcess.running = false
            deleteMessageProcess.running = true
        }

        Component.onCompleted: {
            readSopsSecret.running = true
        }

        Process {
            id: readSopsSecret
            command: [ "${pkgs.coreutils}/bin/cat", "'' + gmailAddrFile + ''" ]
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
            command: [ "${pkgs.bash}/bin/sh", "-c", "export HIMALAYA_GMAIL_ADDRESS=\"$(cat '' + gmailAddrFile + '')\"; export HIMALAYA_GMAIL_PASSWORD=\"$(cat '' + gmailPassFile + '')\"; ${pkgs.isync}/bin/mbsync -c ${homeDir}/.config/mbsync/mbsyncrc gmail" ]
            onRunningChanged: {
                if (!forceCacheSyncDownstream.running) {
                    mailList.running = false
                    root.updateMailListCommand()
                    mailList.running = true
                }
            }
        }

        Process {
            id: mailList
            command: [
                "${pkgs.bash}/bin/sh", "-c",
                "export HIMALAYA_GMAIL_ADDRESS=\"$(cat " + gmailAddrFile + ")\"; ${pkgs.himalaya}/bin/himalaya --config ${homeDir}/.config/himalaya/config.toml --output json envelope list --page 1 --page-size 500 | ${pkgs.coreutils}/bin/tee /tmp/qs-raw-emails.json"
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    var raw = text.trim()
                    if (!raw.length) {
                        controller.emails = []
                        controller.statusMessage = "0 message(s)"
                        root.mailListUpdated()
                        return
                    }

                    try {
                        var parsedData = JSON.parse(raw)
                        var targetArray = []
                        var rawItems = Array.isArray(parsedData) ? parsedData : (parsedData.envelopes || parsedData.items || []);

                        var extractId = function(obj) {
                            if (!obj) return "";
                            if (typeof obj !== "object") return String(obj);
                            return obj.id ? (typeof obj.id === "object" ? String(obj.id.id) : String(obj.id)) : "";
                        };

                        for (var i = 0; i < rawItems.length; i++) {
                            var item = rawItems[i];
                            var itemId = extractId(item) || extractId(item.envelope);
                            if (root.locallyDeletedIds.indexOf(itemId) === -1) {
                                targetArray.push(item);
                            }
                        }

                        controller.emails = targetArray;
                        controller.statusMessage = targetArray.length + " message(s)";
                        if (controller.currentListIndex >= targetArray.length) {
                            controller.currentListIndex = Math.max(0, targetArray.length - 1);
                        }
                    } catch (e) {
                        controller.emails = []
                        controller.statusMessage = "Parse Error: " + String(e.message).substring(0, 30)
                    }
                    root.mailListUpdated()
                }
            }
        }

        Process {
            id: readMessage
            stdout: StdioCollector {
                onStreamFinished: {
                    controller.messageBody = text
                    root.messageLoaded()
                }
            }
        }

        Process {
            id: sendEmailProcess
            onRunningChanged: {
                if (!sendEmailProcess.running) {
                    controller.isReplying = false
                    controller.isComposing = false
                    controller.messageBody = "Message transmitted successfully upstream!"
                    root.refreshMail()
                    root.sendSucceeded()
                }
            }
        }

        Process {
            id: deleteMessageProcess
            onRunningChanged: {
                if (!deleteMessageProcess.running) {
                    mailList.running = false
                    root.updateMailListCommand()
                    mailList.running = true
                }
            }
        }

        Process {
            id: readErrorLog
            command: [ "${pkgs.coreutils}/bin/cat", "/tmp/himalaya-error.log" ]
            stdout: StdioCollector {
                onStreamFinished: {
                    controller.messageBody = "Himalaya Debug Error:\n\n" + text.trim()
                    root.sendFailed()
                }
            }
        }
    }
  '';
  # =========================================================================
  # Himalaya Live Configuration (Pointed directly to your 472 email labels)
  # =========================================================================

  xdg.configFile."himalaya/config.toml".text = ''
    [accounts.gmail]
    default = true
    display-name = "Moonburst"
    email = "$HIMALAYA_GMAIL_ADDRESS"

    [accounts.gmail.backend]
    type = "maildir"
    # FIXED: Re-targeted Himalaya's root Maildir path to look flat inside your populated Important folder context tree
    root-dir = "${homeDir}/.local/share/mail/gmail/[Gmail]/Important"
    maildirpp = false

    [accounts.gmail.folder.aliases]
    inbox = "."
    drafts = "../Drafts"
    sent = "../Sent Mail"
    trash = "../Trash"
    spam = "../Spam"

    [accounts.gmail.message.send.backend]
    type = "smtp"
    host = "smtp.gmail.com"
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
    Host imap.gmail.com
    TLSType IMAPS
    CertificateFile /etc/ssl/certs/ca-certificates.crt
    User "$HIMALAYA_GMAIL_ADDRESS"
    Pass "$HIMALAYA_GMAIL_PASSWORD"

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
    host = "imap.gmail.com";
    port = 993;
    tls = true;
    usernameCmd = "${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r '";
    passwordCmd = "${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r '";
    boxes = [ "INBOX" ];
    onNewMail = "${pkgs.bash}/bin/sh -c 'export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d \"\\\\n\\\\r \")\"; export HIMALAYA_GMAIL_PASSWORD=\"$(${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d \"\\\\n\\\\r \")\"; ${pkgs.isync}/bin/mbsync -c ${homeDir}/.config/mbsync/mbsyncrc gmail'";
  };

  # =========================================================================
  # Maildir Creation
  # =========================================================================

  home.activation.ensureMailDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p ${homeDir}/.local/share/mail/gmail
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
      ExecStart = "${pkgs.bash}/bin/sh -c 'export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d \"\\\\n\\\\r \")\"; export HIMALAYA_GMAIL_PASSWORD=\"$(${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d \"\\\\n\\\\r \")\"; ${pkgs.goimapnotify}/bin/goimapnotify -conf %h/.config/goimapnotify/goimapnotify.json'";
      Restart = "always";
      RestartSec = "10";
    };
    Install = { WantedBy = [ "default.target" ]; };
  };
}
