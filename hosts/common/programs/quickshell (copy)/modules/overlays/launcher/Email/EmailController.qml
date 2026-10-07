import QtQuick

QtObject {
    id: controller

    property string cacheFilePath: ""
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

    onSearchStringChanged: filterEmailsByActiveFolder()
    onSearchCaseSensitiveChanged: filterEmailsByActiveFolder()

    function readMailCache() {
        if (cacheFilePath === "") return;

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && (xhr.status === 200 || xhr.status === 0)) {
                try {
                    var parsedData = JSON.parse(xhr.responseText);
                    if (Array.isArray(parsedData)) {
                        controller.fullMailCacheList = parsedData;
                        controller.recalculateFolderStats();
                        controller.filterEmailsByActiveFolder();
                    }
                } catch (e) { console.log("[Controller Error] JSON Index Extraction Fault: " + e.message); }
            }
        }
        xhr.open("GET", cacheFilePath, true);
        xhr.send();
    }

    function recalculateFolderStats() {
        var counts = { "inbox": 0, "starred": 0, "steam": 0, "all": 0, "sent": 0, "drafts": 0, "trash": 0, "spam": 0 };
        var seenStarredIds = {}, seenAllIds = {};

        // Modernized ES6 map/forEach replaces procedural variable definitions
        fullMailCacheList.forEach(mail => {
            if (!mail || !mail.folder) return;
            var folder = mail.folder.toLowerCase();
            var flags = (mail.flags || []).map(f => f.toLowerCase());
            var isStarred = flags.includes("flagged");
            var isUnread = !flags.includes("seen");

            var sender = (mail.from ? (mail.from.addr || mail.from.name || "") : (mail.sender || "")).trim();
            var sig = (mail.subject || "").trim() + "|" + (mail.date || "").trim() + "|" + sender;

            if (isStarred && !seenStarredIds[sig]) {
                counts["starred"]++; seenStarredIds[sig] = true;
            }
            if (folder !== "trash" && folder !== "spam" && !seenAllIds[sig]) {
                // Only count in All Mail totals if it does not belong to a primary folder
                if (folder === "all" && !isStarred) {
                    counts["all"]++;
                }
                seenAllIds[sig] = true;
            }
            if (folder !== "starred" && folder !== "all" && counts[folder] !== undefined) {
                counts[folder]++;
            }
        });
        controller.folderCountMap = counts;
    }

    function filterEmailsByActiveFolder() {
        var targetFolder = folderList[currentFolderIndex];
        var isFolderSwitch = (currentFolderIndex !== lastFolderIndex);

        // Condensed ES6 dictionary maps
        var oldFilteredMails = controller.filteredMails || [];
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
                    // Inbox now displays both read and unread messages inside the Inbox folder
                    belongsToFolder = (mail.folder === "inbox");
                } else if (targetFolder === "all") {
                    var isStarred = (mail.flags || []).map(f => f.toLowerCase()).includes("flagged");
                    // Exclude any Inbox, Steam, or Starred emails from showing up in the Archive tab
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
        controller.filteredMails = matchingMails;

        if (controller.currentMailIndex >= matchingMails.length) {
            controller.currentMailIndex = Math.max(0, matchingMails.length - 1);
        }
        controller.selectedMail = matchingMails.length > 0 ? matchingMails[controller.currentMailIndex] : null;
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
        controller.selectedMail = filteredMails[currentMailIndex];
    }
}
