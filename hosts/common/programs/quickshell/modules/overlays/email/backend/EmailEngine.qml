import QtQuick
import QtQuick.LocalStorage
import Quickshell
import Quickshell.Io

QtObject {
    id: engine

    property string cacheFilePath: "file://" + (Quickshell.env("HOME") || "") + "/.cache/himalaya/emails.json"
    property var fullMailCacheList: []
    property var filteredMails: []
    property var folderList: ["inbox", "starred", "steam", "all", "sent", "drafts", "trash", "spam"]

    property int currentFolderIndex: 0
    property int currentMailIndex: 0
    property var selectedMail: null

    property var folderCountMap: ({})
    property string activeMailBody: ""
    property bool isComposing: false

    property string searchString: ""
    property bool searchCaseSensitive: false
    property int lastFolderIndex: -1
    property double lastDeleteTime: 0
    property bool himalayaInstalled: true

    property string mailSignature: (typeof shell !== "undefined" && shell && shell.settingsManager && shell.settingsManager.emailSignature)
        ? shell.settingsManager.emailSignature
        : "\n\n--\nSeekers of light..\nBelieve not in justice...\nBelieve not in truth...\nFor they are empty and inconsistent, as are all things..."

    onSearchStringChanged: filterEmailsByActiveFolder()
    onSearchCaseSensitiveChanged: filterEmailsByActiveFolder()

    Component.onCompleted: {
        readMailCache();
        checkHimalaya();
    }

    function checkHimalaya() {
        himalayaCheckProc.running = false;
        himalayaCheckProc.running = true;
    }

    readonly property Process himalayaCheckProc: Process {
        running: true
        command: [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'command -v himalaya >/dev/null 2>&1 && echo "1" || echo "0"'
        ]
        stdout: SplitParser {
            onRead: data => { engine.himalayaInstalled = (data.trim() === "1"); }
        }
    }

    readonly property Timer bodyFetchPoller: Timer {
        interval: 100
        running: false
        repeat: true
        property string lastTargetId: ""
        property int attempts: 0
        onTriggered: {
            attempts++;
            if (attempts > 30) {
                running = false;
                return;
            }
            var xhr = new XMLHttpRequest();
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                    var lines = xhr.responseText.split("\n");
                    if (lines.length >= 2) {
                        var bodyId = lines[0].trim();
                        if (bodyId === bodyFetchPoller.lastTargetId) {
                            var bodyText = lines.slice(1).join("\n");
                            engine.activeMailBody = bodyText;
                            if (engine.selectedMail && engine.selectedMail.id.toString() === bodyId) {
                                engine.selectedMail.body_content = bodyText;
                                engine.readMailCache();
                            }
                            running = false;
                        }
                    }
                }
            }
            var bodyFilePath = "file://" + (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qmail_active_body.txt";
            xhr.open("GET", bodyFilePath, true);
            xhr.send();
        }
    }

    onSelectedMailChanged: {
        var activeItem = selectedMail;
        if (!activeItem) { activeMailBody = ""; return; }

        if (activeItem.body_content && activeItem.body_content.trim() !== "") {
            activeMailBody = activeItem.body_content;
        } else {
            activeMailBody = "Fetching message body from server...";
            bodyFetchPoller.lastTargetId = activeItem.id.toString();
            bodyFetchPoller.attempts = 0;
            bodyFetchPoller.start();

            var folderArg = getMaildirFolder(activeItem.folder);
            writeToQueue("FETCH_BODY", activeItem.id.toString(), folderArg, "");
        }

        var flags = activeItem.flags || [];
        var isUnread = true;
        for (var i = 0; i < flags.length; i++) {
            if (flags[i].toLowerCase() === "seen") {
                isUnread = false;
                break;
            }
        }
        if (isUnread) {
            handleReadToggle(activeItem, true);
        }
    }

    function getDatabase() {
        return LocalStorage.openDatabaseSync("QMailQueue", "1.0", "Queue for outbound mail operations", 100000);
    }

    function writeToQueue(action, arg1, arg2, arg3) {
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS queue (id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT, arg1 TEXT, arg2 TEXT, arg3 TEXT)");
                tx.executeSql("INSERT INTO queue (action, arg1, arg2, arg3) VALUES (?, ?, ?, ?)", [action, arg1, arg2, arg3]);
            });
        } catch (err) {
            console.log("[Local Queue Error]: " + err);
        }
    }

    function getMaildirFolder(folderLabel) {
        var label = (folderLabel || "").toLowerCase();
        var map = {
            "inbox": "INBOX",
            "starred": ".[Gmail].Starred",
            "all": ".[Gmail].All Mail",
            "steam": ".Steam",
            "drafts": ".[Gmail].Drafts",
            "sent": ".[Gmail].Sent Mail",
            "trash": ".[Gmail].Trash",
            "spam": ".[Gmail].Spam"
        };
        return map[label] || "INBOX";
    }

    function readMailCache() {
        if (cacheFilePath === "") return;
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && (xhr.status === 200 || xhr.status === 0)) {
                try {
                    var parsedData = JSON.parse(xhr.responseText);
                    if (Array.isArray(parsedData)) {
                        engine.fullMailCacheList = parsedData;
                        engine.recalculateFolderStats();
                        engine.filterEmailsByActiveFolder();
                    }
                } catch (e) {
                    console.log("[Controller Error] JSON Index Extraction Fault: " + e.message);
                }
            }
        }
        var cacheBuster = cacheFilePath + "?t=" + Date.now();
        xhr.open("GET", cacheBuster, true);
        xhr.send();
    }

    function recalculateFolderStats() {
        var counts = { "inbox": 0, "starred": 0, "steam": 0, "all": 0, "sent": 0, "drafts": 0, "trash": 0, "spam": 0 };
        var seenStarredIds = {}, seenAllIds = {};

        fullMailCacheList.forEach(mail => {
            if (!mail || !mail.folder) return;
            var folder = mail.folder.toLowerCase();
            var flags = (mail.flags || []).map(f => f.toLowerCase());
            var isStarred = flags.includes("flagged");
            var sender = (mail.from ? (mail.from.addr || mail.from.name || "") : (mail.sender || "")).trim();
            var sig = (mail.subject || "").trim() + "|" + (mail.date || "").trim() + "|" + sender;

            if (isStarred && !seenStarredIds[sig]) {
                counts["starred"]++; seenStarredIds[sig] = true;
            }
            if (folder !== "trash" && folder !== "spam" && !seenAllIds[sig]) {
                if (folder === "all" && !isStarred) {
                    counts["all"]++;
                }
                seenAllIds[sig] = true;
            }
            if (folder !== "starred" && folder !== "all" && counts[folder] !== undefined) {
                counts[folder]++;
            }
        });
        engine.folderCountMap = counts;
    }

    function filterEmailsByActiveFolder() {
        var targetFolder = folderList[currentFolderIndex];
        var isFolderSwitch = (currentFolderIndex !== lastFolderIndex);

        var oldFilteredMails = engine.filteredMails || [];
        var oldMailIds = {};
        oldFilteredMails.forEach(oldMail => {
            if (!oldMail) return;
            var oldSender = oldMail.from ? (oldMail.from.addr || oldMail.from.name || "") : (oldMail.sender || "");
            var oldKey = (oldMail.subject || "").trim() + "|" + (oldMail.date || "").trim() + "|" + oldSender.trim();
            oldMailIds[oldKey] = true;
        });

        var matchingMails = [];
        var seenIds = {};
        var query = searchString.trim();
        if (query !== "" && !searchCaseSensitive) { query = query.toLowerCase(); }

        for (var i = 0; i < fullMailCacheList.length; i++) {
            var mail = fullMailCacheList[i];
            if (mail) {
                var belongsToFolder = (mail.folder === targetFolder);

                if (targetFolder === "inbox") {
                    belongsToFolder = (mail.folder === "inbox");
                } else if (targetFolder === "all") {
                    var isStarred = (mail.flags || []).map(f => f.toLowerCase()).includes("flagged");
                    belongsToFolder = (mail.folder === "all" && !isStarred);
                } else if (targetFolder === "starred") {
                    var isStarred = (mail.flags || []).map(f => f.toLowerCase()).includes("flagged");
                    var senderPart = (mail.from ? (mail.from.addr || mail.from.name || "") : (mail.sender || "")).trim();
                    var compoundKey = (mail.subject || "").trim() + "|" + (mail.date || "").trim() + "|" + senderPart;

                    belongsToFolder = isFolderSwitch ? (isStarred || mail.folder === "starred")
                    : (isStarred || mail.folder === "starred" || oldMailIds[compoundKey] === true);
                }

                if (belongsToFolder) {
                    var senderPart = (mail.from ? (mail.from.addr || mail.from.name || "") : (mail.sender || "")).trim();
                    var compoundKey = (mail.subject || "").trim() + "|" + (mail.date || "").trim() + "|" + senderPart;

                    if (seenIds[compoundKey]) continue;

                    if (query !== "") {
                        var subject = (mail.subject || "").toLowerCase();
                        var fromName = (mail.from && mail.from.name ? mail.from.name : "").toLowerCase();
                        var fromAddr = (mail.from && mail.from.addr ? mail.from.addr : "").toLowerCase();
                        var body = (mail.body_content || "").toLowerCase();

                        if (searchCaseSensitive) {
                            subject = mail.subject || "";
                            fromName = mail.from && mail.from.name ? mail.from.name : "";
                            fromAddr = mail.from && mail.from.addr ? mail.from.addr : "";
                            body = mail.body_content || "";
                        }

                        if (subject.indexOf(query) === -1 && fromName.indexOf(query) === -1 && fromAddr.indexOf(query) === -1 && body.indexOf(query) === -1) {
                            continue;
                        }
                    }

                    seenIds[compoundKey] = true;
                    matchingMails.push(mail);
                }
            }
        }

        lastFolderIndex = currentFolderIndex;
        engine.filteredMails = matchingMails.slice();

        if (engine.currentMailIndex >= matchingMails.length) {
            engine.currentMailIndex = Math.max(0, matchingMails.length - 1);
        }
        engine.selectedMail = matchingMails.length > 0 ? matchingMails[engine.currentMailIndex] : null;
    }

    function cycleFolder(advanceForward) {
        var totalFolders = folderList.length;
        currentFolderIndex = advanceForward ? (currentFolderIndex + 1) % totalFolders : (currentFolderIndex - 1 + totalFolders) % totalFolders;
        currentMailIndex = 0;
        filterEmailsByActiveFolder();
    }

    function cycleEmail(advanceForward) {
        var totalEmails = filteredMails.length;
        if (totalEmails === 0) return;
        currentMailIndex = advanceForward ? (currentMailIndex + 1) % totalEmails : (currentMailIndex - 1 + totalEmails) % totalEmails;
        engine.selectedMail = filteredMails[currentMailIndex];
    }

    function handleDeletion() {
        var activeItem = selectedMail;
        if (!activeItem) return;

        var currentTime = Date.now();
        if (currentTime - lastDeleteTime < 200) return;
        lastDeleteTime = currentTime;

        var isStarred = (activeItem.flags || []).map(f => f.toLowerCase()).some(f => f === "flagged" || f === "starred");
        if (isStarred) return;

        var folderArg = getMaildirFolder(activeItem.folder);
        writeToQueue("DELETE", activeItem.id.toString(), folderArg, "");

        var targetId = activeItem.id !== undefined ? activeItem.id.toString() : "";
        var targetMsgId = activeItem["message-id"] || "";
        var targetSub = activeItem.subject || "";
        var targetDate = activeItem.date || "";
        var targetSender = (activeItem.from ? (activeItem.from.addr || activeItem.from.name || "") : (activeItem.sender || "")).trim();

        fullMailCacheList = fullMailCacheList.filter(item => {
            if (!item) return false;
            if (targetId !== "" && item.id !== undefined && item.id.toString() === targetId) {
                return false;
            }
            if (targetMsgId !== "" && item["message-id"] && item["message-id"] === targetMsgId) {
                return false;
            }
            var s = (item.from ? (item.from.addr || item.from.name || "") : (item.sender || "")).trim();
            if ((item.subject || "") === targetSub && (item.date || "") === targetDate && s === targetSender) {
                return false;
            }
            return true;
        });

        recalculateFolderStats();
        filterEmailsByActiveFolder();
    }

    function handleRestoreFromTrash() {
        var activeItem = selectedMail;
        if (!activeItem || activeItem.folder.toLowerCase() !== "trash") return;

        var emailId = activeItem.id.toString();
        writeToQueue("MOVE", emailId, "trash", "inbox");

        fullMailCacheList = fullMailCacheList.filter(item => {
            return !(item.id.toString() === emailId && item.folder.toLowerCase() === "trash");
        });

        recalculateFolderStats();
        filterEmailsByActiveFolder();
    }

    function handleStarToggle() {
        var activeItem = selectedMail;
        if (!activeItem) return;

        var folderArg = getMaildirFolder(activeItem.folder);
        var isStarred = (activeItem.flags || []).map(f => f.toLowerCase()).includes("flagged");
        writeToQueue(isStarred ? "UNSTAR" : "STAR", activeItem.id.toString(), folderArg, "");

        var activeSender = (activeItem.from ? (activeItem.from.addr || activeItem.from.name || "") : (activeItem.sender || "")).trim();
        var activeSubject = activeItem.subject || "";
        var activeDate = activeItem.date || "";

        fullMailCacheList.forEach(item => {
            var s = (item.from ? (item.from.addr || item.from.name || "") : (item.sender || "")).trim();
            if ((item.subject || "") === activeSubject && (item.date || "") === activeDate && s === activeSender) {
                var fList = item.flags || [];
                var fIdx = fList.findIndex(f => f.toLowerCase() === "flagged");
                if (isStarred && fIdx !== -1) fList.splice(fIdx, 1);
                else if (!isStarred && fIdx === -1) fList.push("flagged");
                item.flags = fList;
            }
        });
        filterEmailsByActiveFolder();
    }

    function handleReadToggle(targetItem, forceRead) {
        var activeItem = targetItem ? targetItem : selectedMail;
        if (!activeItem) return;

        var folderArg = getMaildirFolder(activeItem.folder);
        var isRead = (activeItem.flags || []).map(f => f.toLowerCase()).includes("seen");
        var shouldMarkRead = forceRead !== undefined ? forceRead : !isRead;
        if (shouldMarkRead === isRead) return;

        writeToQueue(shouldMarkRead ? "READ" : "UNREAD", activeItem.id.toString(), folderArg, "");

        var activeSender = (activeItem.from ? (activeItem.from.addr || activeItem.from.name || "") : (activeItem.sender || "")).trim();
        var activeSubject = activeItem.subject || "";
        var activeDate = activeItem.date || "";

        fullMailCacheList.forEach(item => {
            var s = (item.from ? (item.from.addr || item.from.name || "") : (item.sender || "")).trim();
            if ((item.subject || "") === activeSubject && (item.date || "") === activeDate && s === activeSender) {
                var fList = item.flags || [];
                var fIdx = fList.findIndex(f => f.toLowerCase() === "seen");
                if (shouldMarkRead && fIdx === -1) fList.push("seen");
                else if (!shouldMarkRead && fIdx !== -1) fList.splice(fIdx, 1);
                item.flags = fList;
            }
        });
        recalculateFolderStats();
        filterEmailsByActiveFolder();
    }

    function handleOutboundDelivery(toAddress, subjectLine, bodyContent) {
        if (!toAddress || toAddress.trim() === "") return;
        writeToQueue("SEND", toAddress.trim(), subjectLine.trim(), bodyContent);
        isComposing = false;
    }
}
