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
        mailList.command = [
            "/bin/sh", "-c",
            "export HIMALAYA_GMAIL_ADDRESS=\"$(cat /run/secrets/gmail_address)\"; himalaya --config /home/moonburst/.config/himalaya/config.toml --output json envelope list --page 1 --page-size 500"
        ];
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

    // FIXED: Dropped the broken sync-and-notify.sh reference completely.
    // Natively invokes the verified working CLI command with all sops environment variable decryption parameters attached!
    function deleteMessage(messageId) {
        var tmpDeleted = root.locallyDeletedIds.slice();
        tmpDeleted.push(String(messageId));
        root.locallyDeletedIds = tmpDeleted;

        deleteMessageProcess.command = [
            "/bin/sh", "-c",
            "export HIMALAYA_GMAIL_ADDRESS=\"$(cat /run/secrets/gmail_address | tr -d '\\n\\r ')\"; " +
            "export HIMALAYA_GMAIL_PASSWORD=\"$(cat /run/secrets/gmail_app_password | tr -d '\\n\\r ')\"; " +
            "himalaya --config /home/moonburst/.config/himalaya/config.toml message delete --account gmail " + messageId + " 2>/tmp/himalaya-error.log"
        ];
        deleteMessageProcess.running = false;
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
                root.updateMailListCommand()
                mailList.running = true
            }
        }
    }
    Process {
        id: forceCacheSyncDownstream
        command: [ "/bin/sh", "-c", "export HIMALAYA_GMAIL_ADDRESS=\"$(cat /run/secrets/gmail_address)\"; export HIMALAYA_GMAIL_PASSWORD=\"$(cat /run/secrets/gmail_app_password)\"; mbsync -c /home/moonburst/.config/mbsync/mbsyncrc gmail" ]
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
