{ pkgs, osConfig, lib, ... }:

let
  gmailPassFile = osConfig.sops.secrets.gmail_app_password.path;
  gmailAddrFile = osConfig.sops.secrets.gmail_address.path;
in
{
  home.packages = [
    pkgs.himalaya
    pkgs.goimapnotify
    pkgs.isync
    pkgs.libnotify
  ];

  # =========================================================================
  # Declarative EmailProcesses.qml Configuration
  # =========================================================================

  xdg.configFile."quickshell/modules/overlays/launcher/Email/EmailProcesses.qml".text = ''
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

        function refreshMail() {
            controller.statusMessage = "Syncing mail cache..."
            forceCacheSyncDownstream.running = true
        }

        function updateMailListCommand() {
            var shellPrefix = "export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r ')\"; ";

            if (controller.isImportantOnlyView) {
                mailList.command = [
                    "${pkgs.bash}/bin/sh", "-c",
                    shellPrefix + "${pkgs.himalaya}/bin/himalaya --config ~/.config/himalaya/config.toml --output json envelope list --page 1 --page-size 500 --query flagged"
                ];
            } else {
                mailList.command = [
                    "${pkgs.bash}/bin/sh", "-c",
                    shellPrefix + "${pkgs.himalaya}/bin/himalaya --config ~/.config/himalaya/config.toml --output json envelope list --page 1 --page-size 500"
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
            var shellPrefix = "export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r ')\"; ";

            sendEmailProcess.command = [
                "${pkgs.bash}/bin/sh",
                "-c",
                shellPrefix + "${pkgs.coreutils}/bin/cat > /tmp/qs-mail.eml <<'EOF'\n" + content + "\nEOF\n" +
                "${pkgs.himalaya}/bin/himalaya message send < /tmp/qs-mail.eml > /tmp/himalaya-send.log 2> /tmp/himalaya-error.log"
            ]

            sendEmailProcess.running = false
            sendEmailProcess.running = true
        }

        function loadMessage(messageId) {
            var shellPrefix = "export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r ')\"; ";

            readMessage.command = [
                "${pkgs.bash}/bin/sh", "-c",
                shellPrefix + "${pkgs.himalaya}/bin/himalaya --config ~/.config/himalaya/config.toml message read " + messageId
            ]
            readMessage.running = true
        }

        function deleteMessage(messageId) {
            controller.statusMessage = "Moving message to trash..."
            deleteMessageProcess.command = [
                "~/.config/goimapnotify/sync-and-notify.sh",
                "delete",
                messageId
            ]
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
            command: [ "${pkgs.isync}/bin/mbsync", "-c", "~/.config/mbsync/mbsyncrc", "gmail" ]
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
                "export HIMALAYA_GMAIL_ADDRESS=\"$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r ')\"; ${pkgs.himalaya}/bin/himalaya --config ~/.config/himalaya/config.toml --output json envelope list --page 1 --page-size 500"
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

                        if (Array.isArray(parsedData)) {
                            targetArray = parsedData
                        } else if (parsedData && Array.isArray(parsedData.envelopes)) {
                            targetArray = parsedData.envelopes
                        } else if (parsedData && Array.isArray(parsedData.items)) {
                            targetArray = parsedData.items
                        }

                        controller.emails = targetArray
                        controller.statusMessage = targetArray.length + " message(s)"
                        controller.currentListIndex = 0
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
                    if (deleteMessageProcess.exitCode === 0) {
                        controller.statusMessage = "Message deleted successfully."
                        mailList.running = false
                        root.updateMailListCommand()
                        mailList.running = true
                    } else {
                        controller.statusMessage = "Failed to purge email from server."
                    }
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
  # Himalaya Live Configuration
  # =========================================================================

  xdg.configFile."himalaya/config.toml".text = ''
    [accounts.gmail]
    default = true
    display-name = "Moonburst"
    email = "$HIMALAYA_GMAIL_ADDRESS"

    [accounts.gmail.backend]
    type = "maildir"
    root-dir = "~/.local/share/mail/gmail"
    maildirpp = false

    [accounts.gmail.folder.aliases]
    inbox = "[Gmail]/All Mail"
    drafts = "[Gmail]/Drafts"
    set = "[Gmail]/Sent Mail"
    trash = "[Gmail]/Trash"
    spam = "[Gmail]/Spam"



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
    UserCmd "${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r '"
    PassCmd "${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r '"
    TLSType IMAPS
    CertificateFile /etc/ssl/certs/ca-certificates.crt

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
    Expunge Far
  '';

  # =========================================================================
  # goimapnotify Configuration
  # =========================================================================

  xdg.configFile."goimapnotify/goimapnotify.json".text =
    builtins.toJSON {
      host = "://gmail.com";
      port = 993;
      tls = true;

      usernameCmd = "${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\\\\n\\\\r '";
      passwordCmd = "${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d '\\\\n\\\\r '";

      boxes = [ "INBOX" ];

      onNewMail =
        "${pkgs.bash}/bin/sh ~/.config/goimapnotify/sync-and-notify.sh";
    };

  xdg.configFile."goimapnotify/sync-and-notify.sh".text = ''
    #!/bin/sh

    if [ "$1" = "delete" ] && [ -n "$2" ]; then
        GMAIL_PASS=$(${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d '\n\r ')
        export HIMALAYA_GMAIL_PASSWORD="$GMAIL_PASS"

        GMAIL_ADDR=$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\n\r ')
        export HIMALAYA_GMAIL_ADDRESS="$GMAIL_ADDR"

        ${pkgs.himalaya}/bin/himalaya --config ~/.config/himalaya/config.toml --account gmail message delete --yes "$2"
    fi

    ${pkgs.isync}/bin/mbsync -c "~/.config/mbsync/mbsyncrc" gmail

    if [ $? -eq 0 ]; then
      ${pkgs.libnotify}/bin/notify-send \
        -i mail-unread \
        "Himalaya Mail" \
        "Mail synchronization complete!"
    else
      ${pkgs.libnotify}/bin/notify-send \
        -i dialog-error \
        "Himalaya Mail" \
        "Mail synchronization failed."
    fi
  '';

  # =========================================================================
  # Maildir Creation
  # =========================================================================

  home.activation.ensureMailDir =
    let
      mkdir = "${pkgs.coreutils}/bin/mkdir";
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${mkdir} -p ~/.local/share/mail/gmail
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
