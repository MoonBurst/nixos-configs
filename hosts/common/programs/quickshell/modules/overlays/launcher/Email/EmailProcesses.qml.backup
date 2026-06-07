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
        if (controller.isImportantOnlyView) {
            mailList.command = [
                "/etc/profiles/per-user/moonburst/bin/himalaya",
                "--config", "/home/moonburst/.config/himalaya/config.toml",
                "--output", "json",
                "envelope", "list",
                "--page", "1",
                "--page-size", "500",
                "--query", "flagged"
            ];
        } else {
            mailList.command = [
                "/etc/profiles/per-user/moonburst/bin/himalaya",
                "--config", "/home/moonburst/.config/himalaya/config.toml",
                "--output", "json",
                "envelope", "list",
                "--page", "1",
                "--page-size", "500"
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
        sendEmailProcess.command = [
            "sh",
            "-c",
            "cat > /tmp/qs-mail.eml <<'EOF'\n" +
            content +
            "\nEOF\n" +
            "/etc/profiles/per-user/moonburst/bin/himalaya message send < /tmp/qs-mail.eml > /tmp/himalaya-send.log 2> /tmp/himalaya-error.log"
        ]

        sendEmailProcess.running = false
        sendEmailProcess.running = true
    }

    function loadMessage(messageId) {
        readMessage.command = [
            "/etc/profiles/per-user/moonburst/bin/himalaya",
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

        command: [
            "cat",
            "/run/secrets/gmail_address"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                controller.userEmailAddress = text.trim()
                root.updateMailListCommand();
                mailList.running = true
            }
        }
    }

    Process {
        id: forceCacheSyncDownstream

        command: [
            "mbsync",
            "-c",
            "/home/moonburst/.config/mbsync/mbsyncrc",
            "gmail"
        ]

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

        command: [
            "/etc/profiles/per-user/moonburst/bin/himalaya",
            "--config", "/home/moonburst/.config/himalaya/config.toml",
            "--output", "json",
            "envelope", "list",
            "--page", "1",
            "--page-size", "500"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim()

                if (!raw.length) {
                    controller.emails = []
                    controller.statusMessage = "0 message(s)"
                    root.mailListUpdated()
                    return;
                }

                try {
                    // FIXED: Dynamic structural fallback verification safely injects objects into the list model array
                    var parsed = JSON.parse(raw);
                    if (Array.isArray(parsed)) {
                        controller.emails = parsed;
                        controller.statusMessage = parsed.length + " message(s)";
                    } else {
                        controller.emails = [];
                        controller.statusMessage = "0 message(s)";
                    }

                    controller.currentListIndex = 0;
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

        onRunningChanged: {
            if (!sendEmailProcess.running) {
                controller.isReplying = false;
                controller.isComposing = false;
                controller.messageBody = "Message transmitted successfully upstream!";
                root.refreshMail();
                root.sendSucceeded();
            }
        }
    }

    Process {
        id: deleteMessageProcess

        command: []

        onRunningChanged: {
            if (!deleteMessageProcess.running) {
                if (deleteMessageProcess.exitCode === 0) {
                    controller.statusMessage = "Message deleted successfully.";
                    mailList.running = false;
                    root.updateMailListCommand();
                    mailList.running = true;
                } else {
                    controller.statusMessage = "Failed to purge email from server.";
                }
            }
        }
    }

    Process {
        id: readErrorLog

        command: [
            "cat",
            "/tmp/himalaya-error.log"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                controller.messageBody = "Himalaya Debug Error:\n\n" + text.trim()
                root.sendFailed()
            }
        }
    }
}
