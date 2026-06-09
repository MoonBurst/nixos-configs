import QtQuick

QtObject {
    id: controller

    property string cacheFilePath: ""
    property var fullMailCacheList: []
    property var filteredMails: []
    property var folderList: ["inbox", "starred", "all", "sent", "drafts", "trash", "spam"]

    property int currentFolderIndex: 0
    property int currentMailIndex: 0
    property var selectedMail: null

    property var folderCountMap: ({})
    property string activeMailBody: ""
    property bool isComposing: false

    // Real-Time Search Query States
    property string searchString: ""
    property bool searchCaseSensitive: false

    // Visual Star UX States
    property int lastFolderIndex: -1

    onSearchStringChanged: filterEmailsByActiveFolder()
    onSearchCaseSensitiveChanged: filterEmailsByActiveFolder()

    function readMailCache() {
        if (cacheFilePath === "") return;

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        var parsedData = JSON.parse(xhr.responseText);
                        if (Array.isArray(parsedData)) {
                            controller.fullMailCacheList = parsedData;
                            controller.recalculateFolderStats();
                            controller.filterEmailsByActiveFolder();
                        }
                    } catch (e) {
                        console.log("[Controller Error] JSON Index Extraction Fault: " + e.message);
                    }
                }
            }
        }
        xhr.open("GET", cacheFilePath, true);
        xhr.send();
    }

    function recalculateFolderStats() {
        var counts = {
            "inbox": 0, "starred": 0, "all": 0,
            "sent": 0, "drafts": 0, "trash": 0, "spam": 0
        };

        var seenStarredIds = {}; // Prevent double-counting duplicate starred items
        var seenAllIds = {};     // Prevent double-counting duplicate all-mail items

        for (var i = 0; i < fullMailCacheList.length; i++) {
            var mail = fullMailCacheList[i];
            if (mail && mail.folder) {
                var folder = mail.folder.toLowerCase();

                // 1. Scan metadata for active flagged/starred and seen/unread statuses
                var isStarred = false;
                var isUnread = true;
                var flags = mail.flags || [];
                for (var f = 0; f < flags.length; f++) {
                    var flag = flags[f].toLowerCase();
                    if (flag === "flagged") {
                        isStarred = true;
                    }
                    if (flag === "seen") {
                        isUnread = false;
                    }
                }

                // 2. Generate unique compound key signature
                var senderPart = mail.from ? (mail.from.addr || mail.from.name || "") : (mail.sender || "");
                var compoundKey = (mail.subject || "").trim() + "|" + (mail.date || "").trim() + "|" + senderPart.trim();

                // 3. Dynamic Starred Badge Counter
                if (isStarred) {
                    if (!seenStarredIds[compoundKey]) {
                        counts["starred"]++;
                        seenStarredIds[compoundKey] = true;
                    }
                }

                // 4. Dynamic All-Mail Badge Counter (Counts ALL unique active emails, both read and unread)
                if (folder !== "trash" && folder !== "spam") {
                    if (!seenAllIds[compoundKey]) {
                        counts["all"]++;
                        seenAllIds[compoundKey] = true;
                    }
                }

                // 5. Regular folder counters (Except for "starred" and "all" folders calculated dynamically above)
                if (folder !== "starred" && folder !== "all" && counts[folder] !== undefined) {
                    // For INBOX, strictly count unread messages. For other folders, count all total.
                    if (folder === "inbox") {
                        if (isUnread) {
                            counts[folder]++;
                        }
                    } else {
                        counts[folder]++;
                    }
                }
            }
        }
        controller.folderCountMap = counts;
    }

    function filterEmailsByActiveFolder() {
        var targetFolder = folderList[currentFolderIndex];
        var isFolderSwitch = (currentFolderIndex !== lastFolderIndex);

        // FIXED: Corrected loop variable from k to j to resolve reference errors
        var oldFilteredMails = controller.filteredMails || [];
        var oldMailIds = {};
        for (var j = 0; j < oldFilteredMails.length; j++) {
            var oldMail = oldFilteredMails[j];
            if (oldMail) {
                var oldSender = oldMail.from ? (oldMail.from.addr || oldMail.from.name || "") : (oldMail.sender || "");
                var oldKey = (oldMail.subject || "").trim() + "|" + (oldMail.date || "").trim() + "|" + oldSender.trim();
                oldMailIds[oldKey] = true;
            }
        }

        var matchingMails = [];
        var seenIds = {}; // Tracker to eliminate folder cross-references and duplicates

        // Prepare matching terms
        var query = searchString.trim();
        if (query !== "" && !searchCaseSensitive) {
            query = query.toLowerCase();
        }

        for (var i = 0; i < fullMailCacheList.length; i++) {
            var mail = fullMailCacheList[i];
            if (mail) {
                // Folder mapper:
                // - ALL folder view accepts every email except Trash and Spam.
                // - STARRED folder view accepts flagged emails or physical starred items.
                var belongsToFolder = (mail.folder === targetFolder);

                if (targetFolder === "all") {
                    belongsToFolder = (mail.folder !== "trash" && mail.folder !== "spam");
                } else if (targetFolder === "starred") {
                    var isStarred = false;
                    var flags = mail.flags || [];
                    for (var f = 0; f < flags.length; f++) {
                        if (flags[f].toLowerCase() === "flagged") {
                            isStarred = true;
                            break;
                        }
                    }

                    var senderPart = mail.from ? (mail.from.addr || mail.from.name || "") : (mail.sender || "");
                    var compoundKey = (mail.subject || "").trim() + "|" + (mail.date || "").trim() + "|" + senderPart.trim();

                    if (isFolderSwitch) {
                        belongsToFolder = isStarred || (mail.folder === "starred");
                    } else {
                        belongsToFolder = isStarred || (mail.folder === "starred") || (oldMailIds[compoundKey] === true);
                    }
                }

                if (belongsToFolder) {
                    var senderPart = mail.from ? (mail.from.addr || mail.from.name || "") : (mail.sender || "");
                    var compoundKey = (mail.subject || "").trim() + "|" + (mail.date || "").trim() + "|" + senderPart.trim();

                    if (seenIds[compoundKey]) {
                        continue; // Skip duplicate copy of the same email
                    }

                    if (query !== "") {
                        var subject = mail.subject || "";
                        var fromName = (mail.from && mail.from.name) || "";
                        var fromAddr = (mail.from && mail.from.addr) || "";
                        var body = mail.body_content || "";

                        if (!searchCaseSensitive) {
                            subject = subject.toLowerCase();
                            fromName = fromName.toLowerCase();
                            fromAddr = fromAddr.toLowerCase();
                            body = body.toLowerCase();
                        }

                        if (subject.indexOf(query) === -1 &&
                            fromName.indexOf(query) === -1 &&
                            fromAddr.indexOf(query) === -1 &&
                            body.indexOf(query) === -1) {
                            continue; // No matches found, skip
                            }
                    }

                    seenIds[compoundKey] = true; // Mark as displayed
                    matchingMails.push(mail);
                }
            }
        }

        // Update last folder index reference
        lastFolderIndex = currentFolderIndex;

        controller.filteredMails = matchingMails;

        if (controller.currentMailIndex >= matchingMails.length) {
            controller.currentMailIndex = Math.max(0, matchingMails.length - 1);
        }

        if (matchingMails.length > 0) {
            controller.selectedMail = matchingMails[controller.currentMailIndex];
        } else {
            controller.selectedMail = null;
            controller.activeMailBody = "";
        }
    }

    function cycleFolder(advanceForward) {
        var totalFolders = folderList.length;
        if (advanceForward) {
            currentFolderIndex = (currentFolderIndex + 1) % totalFolders;
        } else {
            currentFolderIndex = (currentFolderIndex - 1 + totalFolders) % totalFolders;
        }
        currentMailIndex = 0;
        filterEmailsByActiveFolder();
    }

    function cycleEmail(advanceForward) {
        var totalEmails = filteredMails.length;
        if (totalEmails === 0) return;

        if (advanceForward) {
            currentMailIndex = (currentMailIndex + 1) % totalEmails;
        } else {
            currentMailIndex = (currentMailIndex - 1 + totalEmails) % totalEmails;
        }
        controller.selectedMail = filteredMails[currentMailIndex];
    }
}
