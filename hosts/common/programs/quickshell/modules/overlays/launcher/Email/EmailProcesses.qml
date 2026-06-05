import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    ```
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

    function loadMessage(id) {
        readMessage.command = [
            "himalaya",
            "message",
            "read",
            id
        ]

        readMessage.running = true
    }

    Component.onCompleted: {
        readSopsSecret.running = true
    }

    Timer {
        id: contactsLoaderTimer

        interval: 10
        running: true
        repeat: false

        onTriggered: {
            var xhr = new XMLHttpRequest()

            var docUrl = StandardPaths.writableLocation(
                StandardPaths.DocumentsLocation
            ).toString()

            if (!docUrl.startsWith("file://"))
                docUrl = "file://" + docUrl

                xhr.open(
                    "GET",
                    docUrl + "/Contacts",
                    true
                )

                xhr.onreadystatechange = function() {
                    if (xhr.readyState !== XMLHttpRequest.DONE)
                        return

                        if (xhr.status === 200 || xhr.status === 0) {
                            try {
                                controller.contactDirectoryList =
                                JSON.parse(xhr.responseText)
                            } catch (e) {
                                console.log(
                                    "Failed to parse contacts:",
                                    e
                                )
                            }
                        }
                }

                xhr.send()
        }
    }

    Process {
        id: readSopsSecret

        command: [
            "cat",
            "/run/secrets/gmail_address"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                controller.userEmailAddress =
                text.trim()

                mailList.running = true
            }
        }
    }

    Process {
        id: forceCacheSyncDownstream

        command: [
            "mbsync",
            "gmail"
        ]

        onExited: {
            mailList.running = false
            mailList.running = true
        }
    }

    Process {
        id: mailList

        command: [
            "himalaya",
            "--output",
            "json",
            "envelope",
            "list"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim()

                if (!raw.length) {
                    controller.emails = []
                    controller.statusMessage =
                    "0 message(s)"

                    root.mailListUpdated()
                    return
                }

                try {
                    controller.emails =
                    JSON.parse(raw)

                    controller.statusMessage =
                    controller.emails.length +
                    " message(s)"
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

        onExited: (exitCode) => {
            if (exitCode === 0) {
                controller.isReplying = false
                controller.isComposing = false

                controller.messageBody =
                "Message transmitted successfully upstream!"

                refreshMail()

                root.sendSucceeded()
            } else {
                readErrorLog.running = false
                readErrorLog.running = true
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
    ```

}
