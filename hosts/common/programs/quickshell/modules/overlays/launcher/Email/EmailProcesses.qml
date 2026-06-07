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
                if (!raw.length || raw === "[]") {
                    controller.emails = [];
                    root.mailListUpdated();
                    return;
                }
                try {
                    var parsedData = JSON.parse(raw);
                    var targetArray = [];
                    var rawItems = [];

                    if (Array.isArray(parsedData)) {
                        rawItems = parsedData;
                    } else if (parsedData && Array.isArray(parsedData.envelopes)) {
                        rawItems = parsedData.envelopes;
                    } else if (parsedData && Array.isArray(parsedData.items)) {
                        rawItems = parsedData.items;
                    } else if (parsedData) {
                        rawItems = [parsedData];
                    }

                    var deleteMap = {};
                    if (root.locallyDeletedIds) {
                        for (var d = 0; d < root.locallyDeletedIds.length; d++) {
                            if (root.locallyDeletedIds[d] !== undefined && root.locallyDeletedIds[d] !== null) {
                                deleteMap[String(root.locallyDeletedIds[d])] = true;
                            }
                        }
                    }

                    for (var i = 0; i < rawItems.length; i++) {
                        var item = rawItems[i];
                        if (!item) continue;

                        var env = item.envelope ? item.envelope : item;
                        var itemId = "";

                        if (item.id !== undefined && item.id !== null) {
                            itemId = String(item.id);
                        } else if (env && env.id !== undefined && env.id !== null) {
                            itemId = String(env.id);
                        }

                        if (!deleteMap[itemId] && itemId !== "") {
                            targetArray.push(item);
                        }
                    }

                    controller.emails = targetArray;
                    controller.statusMessage = targetArray.length + " message(s)";
                } catch (e) {
                    controller.statusMessage = "Sync Failure: " + e.message;
                    controller.emails = [];
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
    // FIXED: Uses an atomic file move to completely guarantee that systemd never reads a half-written draft file
    function sendEmail(from, to, subject, body) {
        controller.statusMessage = "Queueing message...";
        var cleanUser = controller.userEmailAddress ? String(controller.userEmailAddress).trim() : from;

        // Target paths
        var tmpFilename = "/tmp/qs_mail_draft_" + Math.floor(Math.random() * 100000) + ".tmp";
        var finalQueuePath = "/home/moonburst/.cache/himalaya/queue/mail_" + Math.floor(Math.random() * 100000) + ".eml";

        // FIXED: Writes to /tmp first, then flips it into the watched folder instantly using mv
        sendEmailProcess.command = [
            "/bin/sh", "-c",
            "cat > " + tmpFilename + " <<'EOF'\nFrom: " + cleanUser + "\nTo: " + to + "\nSubject: " + subject + "\n\n" + body + "\nEOF\n" +
            "mv " + tmpFilename + " " + finalQueuePath
        ];
        sendEmailProcess.running = true;
    }

    function loadMessage(messageId) {
        var activeFolder = controller.currentFolder ? String(controller.currentFolder).toLowerCase().trim() : "inbox";
        if (activeFolder === "sent mail") activeFolder = "sent";
        var cleanUser = controller.userEmailAddress ? String(controller.userEmailAddress).trim() : "";

        readMessage.command = [
            "/bin/sh", "-c",
            "export HIMALAYA_GMAIL_ADDRESS=\"" + cleanUser + "\"; himalaya --config /home/moonburst/.config/himalaya/config.toml message read --folder " + activeFolder + " " + messageId
        ];
        readMessage.running = true;
    }

    function deleteMessage(messageId) {
        var tmpDeleted = root.locallyDeletedIds ? root.locallyDeletedIds.slice() : [];
        tmpDeleted.push(String(messageId));
        root.locallyDeletedIds = tmpDeleted;

        var activeFolder = controller.currentFolder ? String(controller.currentFolder).toLowerCase().trim() : "inbox";
        if (activeFolder === "sent mail") activeFolder = "sent";

        deleteMessageProcess.command = [
            "/bin/sh", "-c",
            "export HIMALAYA_GMAIL_ADDRESS=\"$(cat /run/secrets/gmail_address | tr -d '\\n\\r ')\"; " +
            "export HIMALAYA_GMAIL_PASSWORD=\"$(cat /run/secrets/gmail_app_password | tr -d '\\n\\r ')\"; " +
            "himalaya --config /home/moonburst/.config/himalaya/config.toml message delete --folder " + activeFolder + " --account gmail " + messageId + "; " +
            "sync-mail-cache"
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
