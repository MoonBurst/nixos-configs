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
        command: [ "/bin/sh", "-c", "cat " + Quickshell.env("HOME") + "/.cache/himalaya/emails.json" ]
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
                            itemId = (typeof item.id === "object") ? String(item.id.id || "") : String(item.id);
                        } else if (env && env.id !== undefined && env.id !== null) {
                            itemId = (typeof env.id === "object") ? String(env.id.id || "") : String(env.id);
                        }
                        itemId = itemId.trim();

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

    function sendEmail(from, to, subject, body) {
        controller.statusMessage = "Sending message...";
        var cleanUser = controller.userEmailAddress ? String(controller.userEmailAddress).trim() : from;
        var tmpFilename = "/tmp/qs_mail_draft_" + Math.floor(Math.random() * 100000) + ".tmp";

        sendEmailProcess.command = [
            "/bin/sh", "-c",
            // Pull Nix SOPS parameters straight into the active subshell context
            "export HIMALAYA_GMAIL_ADDRESS=$(cat /run/secrets/gmail_address | tr -d '[[:space:]]'); " +
            "export HIMALAYA_GMAIL_PASSWORD=$(cat /run/secrets/gmail_app_password | tr -d '[[:space:]]'); " +
            "eval $(systemctl --user show-environment | grep HIMALAYA_GMAIL_ || true); " +

            // Generate standard electronic message headers inside the temporary layout draft
            "printf 'From: %s\\nTo: %s\\nSubject: %s\\n\\n%s\\n' \"$HIMALAYA_GMAIL_ADDRESS\" \"" + to + "\" \"" + subject + "\" \"" + body + "\" > " + tmpFilename + "; " +

            // Inject the completed draft file straight into the himalaya sender engine pipeline
            "if himalaya --config " + Quickshell.env("HOME") + "/.config/himalaya/config.toml message send < " + tmpFilename + " 2>/tmp/himalaya-send-error.log; then " +
            "  rm -f " + tmpFilename + "; " +
            "  notify-send 'Mail System' 'Email sent successfully!' -i mail-message-new; " +
            "else " +
            "  notify-send 'Mail System' 'Failed to send email. Check /tmp/himalaya-send-error.log' -u critical -i mail-message-alert; " +
            "fi"
        ];
        sendEmailProcess.running = true;
    }


    function loadMessage(messageId) {
        var cleanUser = controller.userEmailAddress ? String(controller.userEmailAddress).trim() : "";
        var safeMessageId = String(messageId).replace(/[^a-zA-Z0-9_\-\.\@]/g, "");

        if (!safeMessageId || safeMessageId === "" || safeMessageId === "undefined") {
            return;
        }

        var activeFolderContext = controller.currentFolder ? String(controller.currentFolder).trim() : "INBOX";

        // Construct our clean script location pointer path string
        var scriptPath = Quickshell.env("HOME") + "/nix/hosts/common/programs/quickshell/modules/overlays/launcher/Email/get_msg.py";

        // FIXED: Flatten everything cleanly into a single shell payload entry string to block argument shifting bugs!
        readMessage.command = [
            "/bin/sh",
            "-c",
            "export HIMALAYA_GMAIL_ADDRESS='" + cleanUser + "'; " +
            "eval $(systemctl --user show-environment | grep HIMALAYA_GMAIL_ || true); " +
            "exec '" + scriptPath + "' '" + safeMessageId + "' '" + activeFolderContext + "'"
        ];
        readMessage.running = true;
    }



    function deleteMessage(messageId) {
        var safeMessageId = String(messageId).replace(/[^a-zA-Z0-9_\-\.\@]/g, "");
        if (!safeMessageId) return;

        var tmpDeleted = root.locallyDeletedIds ? root.locallyDeletedIds.slice() : [];
        tmpDeleted.push(safeMessageId);
        root.locallyDeletedIds = tmpDeleted;

        deleteMessageProcess.command = [
            "/bin/sh", "-c",
            "mkdir -p " + Quickshell.env("HOME") + "/.local/share/mail/gmail/'.[Gmail].Trash'/cur; " +
            "find " + Quickshell.env("HOME") + "/.local/share/mail/gmail/ -type f -name \"*" + safeMessageId + "*\" | while read -r file; do " +
            "  mv \"$file\" " + Quickshell.env("HOME") + "/.local/share/mail/gmail/'.[Gmail].Trash'/cur/ 2>/dev/null; " +
            "done; " +
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
