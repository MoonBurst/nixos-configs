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
            "-c",
            "cat > /tmp/qs-mail.eml <<'EOF'\n" +
            content +
            "\nEOF\n" +
            "himalaya message send < /tmp/qs-mail.eml > /tmp/himalaya-send.log 2> /tmp/himalaya-error.log"
        ]

        sendEmailProcess.running = false
        sendEmailProcess.running = true
    }

    function loadMessage(messageId) {
        readMessage.command = [
            "himalaya",
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
            "sh",
            "-c",
            "himalaya --config /home/moonburst/.config/himalaya/config.toml --account gmail message delete --yes " + messageId + " && sh $HOME/.config/goimapnotify/sync-and-notify.sh"
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
                    "himalaya",
                    "--config", "/home/moonburst/.config/himalaya/config.toml",
                    "--output", "json",
                    "envelope", "list",
                    "--page", "1",
                    "--page-size", "500",
                    "--query", "flagged"
                ]
            }
            return [
                "himalaya",
                "--config", "/home/moonburst/.config/himalaya/config.toml",
                "--output", "json",
                "envelope", "list",
                "--page", "1",
                "--page-size", "500"
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
                    controller.statusMessage =
                    controller.emails.length + " message(s)"

                    if (controller.currentListIndex >= controller.emails.length) {
                        controller.currentListIndex = 0
                    }
                } catch (e) {
                    controller.emails = []
                    controller.statusMessage =
                    "Failed to load current cache"
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

            controller.messageBody =
            "Message transmitted successfully upstream!"

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

        command: [
            "cat",
            "/tmp/himalaya-error.log"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                controller.messageBody =
                "Himalaya Debug Error:\n\n" +
                text.trim()

                root.sendFailed()
            }
        }
    }
}
