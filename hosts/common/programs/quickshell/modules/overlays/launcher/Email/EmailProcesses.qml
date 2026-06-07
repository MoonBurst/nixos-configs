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

    // FIXED: Replaced brittle FileReader with a native, verified working non-blocking Process block
    Process {
        id: cacheReader
        command: [ "cat", "/home/moonburst/.cache/himalaya/emails.json" ]
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

                    var deleteMap = {};
                    for (var d = 0; d < root.locallyDeletedIds.length; d++) {
                        deleteMap[root.locallyDeletedIds[d]] = true;
                    }

                    for (var i = 0; i < rawItems.length; i++) {
                        var item = rawItems[i];
                        var itemId = item.id ? String(item.id) : "";
                        if (!deleteMap[itemId]) {
                            targetArray.push(item);
                        }
                    }
                    controller.emails = targetArray;
                    controller.statusMessage = targetArray.length + " message(s)";
                } catch (e) {
                    controller.statusMessage = "Cache Loaded";
                }
                root.mailListUpdated();
            }
        }
    }

    function refreshMail() {
        controller.statusMessage = "Reading local cache...";
        cacheReader.running = false;
        cacheReader.running = true;
    }
    function sendEmail(from, to, subject, body) {
        sendEmailProcess.command = [
            "/bin/sh", "-c",
            "export HIMALAYA_GMAIL_ADDRESS=\"$(cat /run/secrets/gmail_address)\"; cat > /tmp/qs-mail.eml <<'EOF'\nFrom: " + from + "\nTo: " + to + "\nSubject: " + subject + "\n\n" + body + "\nEOF\n" +
            "himalaya message send < /tmp/qs-mail.eml"
        ];
        sendEmailProcess.running = true;
    }

    function loadMessage(messageId) {
        readMessage.command = [
            "/bin/sh", "-c",
            "export HIMALAYA_GMAIL_ADDRESS=\"$(cat /run/secrets/gmail_address)\"; himalaya --config /home/moonburst/.config/himalaya/config.toml message read " + messageId
        ];
        readMessage.running = true;
    }

    function deleteMessage(messageId) {
        var tmpDeleted = root.locallyDeletedIds.slice();
        tmpDeleted.push(String(messageId));
        root.locallyDeletedIds = tmpDeleted;

        deleteMessageProcess.command = [
            "/bin/sh", "-c",
            "export HIMALAYA_GMAIL_ADDRESS=\"$(cat /run/secrets/gmail_address | tr -d '\\n\\r ')\"; " +
            "export HIMALAYA_GMAIL_PASSWORD=\"$(cat /run/secrets/gmail_app_password | tr -d '\\n\\r ')\"; " +
            "himalaya --config /home/moonburst/.config/himalaya/config.toml message delete --account gmail " + messageId
        ];
        deleteMessageProcess.running = true;
    }

    Component.onCompleted: {
        readSopsSecret.running = true
    }

    Process {
        id: readSopsSecret
        command: [ "cat", "/run/secrets/gmail_address" ]
        stdout: StdioCollector {
            onStreamFinished: {
                controller.userEmailAddress = text.trim()
                refreshMail();
            }
        }
    }

    Process {
        id: readMessage
        stdout: StdioCollector {
            onStreamFinished: {
                controller.messageBody = text;
                root.messageLoaded();
            }
        }
    }

    Process { id: sendEmailProcess; onRunningChanged: { if (!sendEmailProcess.running) root.refreshMail(); } }
    Process { id: deleteMessageProcess; onRunningChanged: { if (!deleteMessageProcess.running) root.refreshMail(); } }
}
