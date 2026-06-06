{ pkgs, osConfig, lib, ... }:

let
  gmailPassFile = osConfig.sops.secrets.gmail_app_password.path;
  gmailAddrFile = osConfig.sops.secrets.gmail_address.path;

  # Pure helper script to cleanly strip "://gmail.com" from the sops secret output
  getSanitizedEmail = pkgs.writeShellScriptBin "get-sanitized-email" ''
    RAW_STRING=$(${pkgs.coreutils}/bin/cat ${gmailAddrFile} | ${pkgs.coreutils}/bin/tr -d '\n\r ')
    echo "$RAW_STRING" | ${pkgs.gnused}/bin/sed 's|://gmail.com||g'
  '';
in
{
  home.packages = [
    pkgs.himalaya
    pkgs.goimapnotify
    pkgs.isync
    pkgs.libnotify
    getSanitizedEmail
  ];

  # =========================================================================
  # Declarative EmailProcesses.qml Path Injection
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
            sendEmailProcess.command = [
                "sh",
                " -c",
                "cat > /tmp/qs-mail.eml <<'EOF'\n" + content + "\nEOF\n" +
                "${pkgs.himalaya}/bin/himalaya message send < /tmp/qs-mail.eml > /tmp/himalaya-send.log 2> /tmp/himalaya-error.log"
            ]

            sendEmailProcess.running = false
            sendEmailProcess.running = true
        }

        function loadMessage(messageId) {
            readMessage.command = [
                "${pkgs.himalaya}/bin/himalaya",
                "--config", "/home/moonburst/.config/himalaya/config.toml",
                "message",
                "read",
                messageId
            ]
            readMessage.running = true
        }

        function deleteMessage(messageId) {
            controller.statusMessage = "Moving message to trash..."
            deleteMessageProcess.command = [
                "/home/moonburst/.config/goimapnotify/sync-and-notify.sh",
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
            command: [ "${getSanitizedEmail}/bin/get-sanitized-email" ]
            stdout: StdioCollector {
                onStreamFinished: {
                    controller.userEmailAddress = text.trim()
                    mailList.running = true
                }
            }
        }

        Process {
            id: forceCacheSyncDownstream
            command: [ "${pkgs.isync}/bin/mbsync", "-c", "/home/moonburst/.config/mbsync/mbsyncrc", "gmail" ]
            onExited: {
                mailList.running = false
                mailList.running = true
            }
        }

        Process {
            id: mailList
            command: {
                if (controller.isImportantOnlyView) {
                    return [
                        "sh",
                        "-c",
                        "${pkgs.himalaya}/bin/himalaya --config /home/moonburst/.config/himalaya/config.toml --output json envelope list --page 1 --page-size 500 --query 'flagged'"
                    ]
                }
                return [
                    "sh",
                    "-c",
                    "${pkgs.himalaya}/bin/himalaya --config /home/moonburst/.config/himalaya/config.toml --output json envelope list --page 1 --page-size 500"
                ]
            }

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
                        controller.emails = JSON.parse(raw)
                        controller.statusMessage = controller.emails.length + " message(s)"
                        if (controller.currentListIndex >= controller.emails.length) {
                            controller.currentListIndex = 0
                        }
                    } catch (e) {
                        controller.emails = []
                        controller.statusMessage = "Failed to load current cache"
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
            onExited: {
                controller.isReplying = false
                controller.isComposing = false
                controller.messageBody = "Message transmitted successfully upstream!"
                refreshMail()
                root.sendSucceeded()
            }
        }

        Process {
            id: deleteMessageProcess
            onExited: (exitCode) => {
                if (exitCode === 0) {
                    controller.statusMessage = "Message deleted successfully."
                    mailList.running = false
                    mailList.running = true
                } else {
                    controller.statusMessage = "Failed to purge email from server."
                }
            }
        }

        Process {
            id: readErrorLog
            command: [ "cat", "/tmp/himalaya-error.log" ]
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
  # Himalaya Template Configuration
  # =========================================================================

  xdg.configFile."himalaya/config.toml.template".text = ''
    [accounts.gmail]
    default = true
    display-name = "Moonburst"
    email = "@GMAIL_USER@"

    [accounts.gmail.backend]
    type = "maildir"
    root-dir = "/home/moonburst/.local/share/mail/gmail"
    maildirpp = false

    [accounts.gmail.folder.aliases]
    inbox = "INBOX"
    drafts = ".Gmail.Drafts"
    sent = ".Gmail.Sent Mail"
    trash = ".Gmail.Trash"
    spam = ".Gmail.Spam"

    [accounts.gmail.message.send.backend]
    type = "smtp"
    host = "://gmail.com"
    port = 465
    login = "@GMAIL_USER@"
    encryption.type = "tls"
    auth.type = "password"
    auth.cmd = "echo \$HIMALAYA_GMAIL_PASSWORD"

    [accounts.gmail.message.read]
    text-mime-header = "text/plain"

    [accounts.gmail.envelope.list]
    page-size = 500
  '';

  # =========================================================================
  # mbsync Configuration Wrapper Template
  # =========================================================================

  xdg.configFile."mbsync/mbsyncrc.template".text = ''
    SyncState *

    IMAPAccount gmail
    Host ://gmail.com
    User @GMAIL_USER@
    PassCmd "${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r '"
    TLSType IMAPS
    CertificateFile /etc/ssl/certs/ca-certificates.crt

    IMAPStore gmail-remote
    Account gmail

    MaildirStore gmail-local
    SubFolders Verbatim
    Path /home/moonburst/.local/share/mail/gmail/
    Inbox /home/moonburst/.local/share/mail/gmail/INBOX

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

      usernameCmd = "${getSanitizedEmail}/bin/get-sanitized-email";
      passwordCmd = "${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d '\\n\\r '";

      boxes = [ "INBOX" ];

      onNewMail =
        "${pkgs.bash}/bin/sh $HOME/.config/goimapnotify/sync-and-notify.sh";
    };

  xdg.configFile."goimapnotify/sync-and-notify.sh".text = ''
    #!/bin/sh

    EMAIL_STRING=$(${getSanitizedEmail}/bin/get-sanitized-email)

    mkdir -p "/home/moonburst/.config/himalaya"
    mkdir -p "/home/moonburst/.config/mbsync"

    ${pkgs.gnused}/bin/sed "s/@GMAIL_USER@/$EMAIL_STRING/g" \
      "/home/moonburst/.config/himalaya/config.toml.template" > "/home/moonburst/.config/himalaya/config.toml"

    ${pkgs.gnused}/bin/sed "s/@GMAIL_USER@/$EMAIL_STRING/g" \
      "/home/moonburst/.config/mbsync/mbsyncrc.template" > "/home/moonburst/.config/mbsync/mbsyncrc"

    if [ "$$1" = "delete" ] && [ -n "$$2" ]; then
        GMAIL_PASS=$(${pkgs.coreutils}/bin/cat ${gmailPassFile} | ${pkgs.coreutils}/bin/tr -d '\n\r ')
        export HIMALAYA_GMAIL_PASSWORD="$$GMAIL_PASS"
        ${pkgs.himalaya}/bin/himalaya --config /home/moonburst/.config/himalaya/config.toml --account gmail message delete --yes "$$2"
    fi

    ${pkgs.isync}/bin/mbsync -c "/home/moonburst/.config/mbsync/mbsyncrc" gmail

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
