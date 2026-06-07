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

                    // FIXED: Pre-hashes local deletions to instantly intercept and block items from rendering across ALL tabs
                    var deleteMap = {};
                    if (root.locallyDeletedIds) {
                        for (var d = 0; d < root.locallyDeletedIds.length; d++) {
                            deleteMap[String(root.locallyDeletedIds[d])] = true;
                        }
                    }

                    for (var i = 0; i < rawItems.length; i++) {
                        var item = rawItems[i];
                        var env = item.envelope ? item.envelope : item;
                        var itemId = item.id ? String(item.id) : (env.id ? String(env.id) : "");

                        if (!deleteMap[itemId] && itemId !== "") {
                            targetArray.push(item);
                        }
                    }
                    controller.emails = targetArray;
                    controller.statusMessage = targetArray.length + " message(s)";
                } catch (e) {
                    controller.statusMessage = "Cache Synchronized";
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

        // FIXED: Deletion immediately forces a local UI view parsing refresh layer to mask the item out instantly
        deleteMessageProcess.command = [
            "/bin/sh", "-c",
            "export HIMALAYA_GMAIL_ADDRESS=\"$(cat /run/secrets/gmail_address | tr -d '\\n\\r ')\"; " +
            "export HIMALAYA_GMAIL_PASSWORD=\"$(cat /run/secrets/gmail_app_password | tr -d '\\n\\r ')\"; " +
            "himalaya --config /home/moonburst/.config/himalaya/config.toml message delete --account gmail " + messageId
        ];
        deleteMessageProcess.running = true;
        root.refreshMail();
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
