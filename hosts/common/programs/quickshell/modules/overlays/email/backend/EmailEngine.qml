import QtQuick
import QtQuick.LocalStorage
import Quickshell
import Quickshell.Io
import "../../../common" as Common

Item {
    id: engine

    property string cacheFilePath: "file://" + (Quickshell.env("HOME") || "") + "/.cache/himalaya/emails.json"
    property var fullMailCacheList: []
    property var filteredMails: []

    // System mailboxes that cannot be deleted
    readonly property var systemFolders: ["inbox", "starred", "all", "sent", "drafts", "trash", "spam"]

    // Dynamic custom keyword/sender smart mailboxes persisted across sessions
    property var customFolders: ["steam", "reddit"]
    property string customFoldersPath: (Quickshell.env("HOME") || "") + "/.cache/himalaya/custom_folders.json"

    // Unified list exposed to the UI
    property var folderList: systemFolders.concat(customFolders)
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
    property bool himalayaInstalled: false
    property bool isInitialLoad: true
    property var pendingDeletions: ({})
    property string pendingDeletionsPath: "file://" + (Quickshell.env("HOME") || "") + "/.cache/himalaya/pending_deletions.json"
    property string mailSignature: (typeof shell !== "undefined" && shell && shell.settingsManager && shell.settingsManager.emailSignature)
    ? shell.settingsManager.emailSignature
    : "\n\n--\nSeekers of light..\nBelieve not in justice...\nBelieve not in truth...\nFor they are empty and inconsistent, as are all things..."

    onSearchStringChanged: filterEmailsByActiveFolder()
    onSearchCaseSensitiveChanged: filterEmailsByActiveFolder()

    Component.onCompleted: {
        loadCustomFolders();
        loadPendingDeletions();
        checkHimalaya();
        readMailCache();
    }

    function checkHimalaya() {
        himalayaCheckProc.running = false;
        himalayaCheckProc.running = true;
    }

    function syncMail() {
        if (!engine.himalayaInstalled || mailSyncProc.running) return;
        var rawLimit = (typeof shell !== "undefined" && shell && shell.settingsManager) ? shell.settingsManager.emailFetchLimit : "50";
        var safeLimit = (rawLimit === "all" || rawLimit === "All") ? "10000" : rawLimit;

        mailSyncProc.command = Common.LuaRunner.cmd("modules/overlays/email/backend/HimalayaEngine.lua", "sync", safeLimit);
        mailSyncProc.running = false;
        mailSyncProc.running = true;
    }

    // Checks for new mail every 3 minutes in the background
    Timer {
        id: periodicSyncTimer
        interval: 3 * 60 * 1000 // 3 minutes
        running: engine.himalayaInstalled
        repeat: true
        onTriggered: {
            engine.syncMail();
        }
    }

    readonly property Process queueFlushProc: Process {
        running: false
        command: Common.LuaRunner.cmd("modules/overlays/email/backend/HimalayaEngine.lua", "flush")
        onExited: {
            engine.readMailCache();
            engine.syncMail();
        }
    }

    onHimalayaInstalledChanged: {
        if (himalayaInstalled) {
            queueFlushProc.running = false;
            queueFlushProc.running = true;
        }
    }

    readonly property Process mailWatcherProcess: Process {
        running: engine.himalayaInstalled
        command: Common.LuaRunner.cmd("modules/overlays/email/backend/HimalayaEngine.lua", "watch")
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var clean = data.trim();
                if (clean === "SYNC" || clean === "NEW_MAIL") {
                    if (!isInitialLoad && typeof shell !== "undefined" && shell && shell.settingsManager && shell.settingsManager.emailSoundEnabled) {
                        var sound = shell.settingsManager.emailReceiveSound;
                        if (sound && sound.length > 0) {
                            Quickshell.execDetached(["pw-play", sound]);
                        }
                    }

                    if (!isInitialLoad) {
                        Quickshell.execDetached(["notify-send", "-a", "Email", "-i", "mail-unread", "📧 New Email Received", "Syncing new message..."]);
                    }

                    engine.syncMail();
                }
            }
        }
    }

    readonly property Process mailSyncProc: Process {
        running: false
        onExited: {
            engine.readMailCache();
            if (engine.isInitialLoad) {
                engine.isInitialLoad = false;
            }
        }
    }

    readonly property Process bodyFetchProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var body = text ? text.trim() : "";
                if (body.length > 0 && body !== "(Empty body)" && body !== "(No content)") {
                    engine.activeMailBody = body;
                    if (engine.selectedMail) {
                        engine.selectedMail.body_content = body;
                        engine.saveMailCacheDisk();
                    }
                } else {
                    engine.activeMailBody = "(No message body content)";
                }
            }
        }
    }

    property int prefetchIndex: 0
    property var currentPrefetchItem: null

    Process {
        id: singlePrefetchProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var body = text ? text.trim() : "";
                if (engine.currentPrefetchItem) {
                    if (body.length > 0 && body !== "(Empty body)" && body !== "(No content)") {
                        engine.currentPrefetchItem.body_content = body;
                        if (engine.selectedMail && engine.selectedMail.id === engine.currentPrefetchItem.id) {
                            engine.activeMailBody = body;
                        }
                        if (engine.prefetchIndex % 5 === 0) {
                            engine.saveMailCacheDisk();
                        }
                    }
                }
                engine.currentPrefetchItem = null;
            }
        }
        onExited: {
            engine.currentPrefetchItem = null;
        }
    }

    Timer {
        id: prefetchTimer
        interval: 150
        repeat: true
        running: engine.himalayaInstalled && engine.prefetchIndex < engine.fullMailCacheList.length
        onTriggered: {
            if (singlePrefetchProc.running || engine.prefetchIndex >= engine.fullMailCacheList.length) return;

            var item = engine.fullMailCacheList[engine.prefetchIndex];
            engine.prefetchIndex++;

            if (!item) return;
            if (item.body_content && item.body_content.trim() !== "" && item.body_content !== "(Empty body)" && item.body_content !== "(No content)" && item.body_content !== "(No message body content)") {
                return;
            }

            var folderArg = item.physical_folder || engine.getMaildirFolder(item.folder);
            engine.currentPrefetchItem = item;

            singlePrefetchProc.command = [
                "sh", "-c",
                'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
                'ID="$2"; FOLDER="$3"; ' +
                'BODY=$(himalaya message read --folder "$FOLDER" "$ID" 2>/dev/null); ' +
                'if [ -z "$BODY" ] || [ "$BODY" = "(Empty body)" ]; then ' +
                '  BODY=$(himalaya message read -f "$FOLDER" "$ID" 2>/dev/null); ' +
                'fi; ' +
                'printf "%s" "$BODY" | python3 "$1/modules/overlays/email/backend/StripMailHeaders.py"',
                "sh", Quickshell.shellDir, item.id.toString(), folderArg
            ];
            singlePrefetchProc.running = true;
        }
    }

    readonly property Process himalayaCheckProc: Process {
        running: true
        command: [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'if command -v himalaya >/dev/null 2>&1 && [ -f "$HOME/.config/himalaya/config.toml" ]; then echo "1"; else echo "0"; fi'
        ]
        stdout: SplitParser {
            onRead: data => {
                engine.himalayaInstalled = (data.trim() === "1");
                if (engine.himalayaInstalled) {
                    engine.readMailCache();
                }
            }
        }
    }

    onSelectedMailChanged: {
        var activeItem = selectedMail;
        if (!activeItem) { activeMailBody = ""; return; }

        if (activeItem.body_content && activeItem.body_content.trim() !== "" && activeItem.body_content !== "(Empty body)" && activeItem.body_content !== "(No content)" && activeItem.body_content !== "(No message body content)") {
            activeMailBody = activeItem.body_content;
        } else {
            activeMailBody = "⏳ Loading message body from server...";
            var folderArg = activeItem.physical_folder || getMaildirFolder(activeItem.folder);

            bodyFetchProc.running = false;
            bodyFetchProc.command = [
                "sh", "-c",
                'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
                'ID="$2"; FOLDER="$3"; ' +
                'BODY=$(himalaya message read --folder "$FOLDER" "$ID" 2>/dev/null); ' +
                'if [ -z "$BODY" ] || [ "$BODY" = "(Empty body)" ]; then ' +
                '  BODY=$(himalaya message read -f "$FOLDER" "$ID" 2>/dev/null); ' +
                'fi; ' +
                'printf "%s" "$BODY" | python3 "$1/modules/overlays/email/backend/StripMailHeaders.py"',
                "sh", Quickshell.shellDir, activeItem.id.toString(), folderArg
            ];
            bodyFetchProc.running = true;
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
    function writeToQueue(action, arg1, arg2, arg3, arg4) {
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS queue (id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT, arg1 TEXT, arg2 TEXT, arg3 TEXT)");
                var checkSchema = tx.executeSql("PRAGMA table_info(queue)");
                var hasArg4 = false;
                for (var i = 0; i < checkSchema.rows.length; i++) {
                    if (checkSchema.rows.item(i).name === "arg4") { hasArg4 = true; break; }
                }
                if (!hasArg4) {
                    tx.executeSql("ALTER TABLE queue ADD COLUMN arg4 TEXT");
                }
                tx.executeSql("INSERT INTO queue (action, arg1, arg2, arg3, arg4) VALUES (?, ?, ?, ?, ?)", [action, arg1, arg2, arg3, arg4 || ""]);
            });
        } catch (err) {
            console.log("[Local Queue Error]: " + err);
        }
        Quickshell.execDetached(Common.LuaRunner.cmd(
            "modules/overlays/email/backend/HimalayaEngine.lua",
            action || "",
            arg1 || "",
            arg2 || "",
            arg3 || "",
            arg4 || ""
        ));
    }
    function loadCustomFolders() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        var parsed = JSON.parse(xhr.responseText.trim());
                        if (Array.isArray(parsed) && parsed.length > 0) {
                            engine.customFolders = parsed;
                            engine.folderList = engine.systemFolders.concat(engine.customFolders);
                            engine.recalculateFolderStats();
                            engine.filterEmailsByActiveFolder();
                        }
                    } catch (e) {}
                }
            }
        };
        xhr.open("GET", "file://" + engine.customFoldersPath + "?t=" + Date.now(), true);
        xhr.send();
    }
    function saveCustomFolders() {
        Quickshell.execDetached([
            "sh", "-c",
            'mkdir -p "$HOME/.cache/himalaya"; printf "%s" "$1" > "$HOME/.cache/himalaya/custom_folders.json"',
            "sh", JSON.stringify(engine.customFolders)
        ]);
    }
    function addCustomFolder(folderName) {
        var clean = (folderName || "").trim().toLowerCase();
        if (clean === "" || engine.folderList.includes(clean)) return;
        var next = engine.customFolders.slice();
        next.push(clean);
        engine.customFolders = next;
        engine.folderList = engine.systemFolders.concat(engine.customFolders);
        engine.saveCustomFolders();
        engine.recalculateFolderStats();
        engine.filterEmailsByActiveFolder();
    }
    function removeCustomFolder(folderName) {
        var clean = (folderName || "").trim().toLowerCase();
        if (engine.systemFolders.includes(clean)) return;
        engine.customFolders = engine.customFolders.filter(f => f !== clean);
        engine.folderList = engine.systemFolders.concat(engine.customFolders);
        if (engine.currentFolderIndex >= engine.folderList.length) {
            engine.currentFolderIndex = 0;
        }
        engine.saveCustomFolders();
        engine.recalculateFolderStats();
        engine.filterEmailsByActiveFolder();
    }
    function makeSignature(subject, date, sender) {
        var timeKey = engine.getNormalizedDateKey(date);
        return String(subject || "") + "|" + timeKey + "|" + String(sender || "");
    }
    function loadPendingDeletions() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var raw = xhr.responseText ? xhr.responseText.trim() : "";
                if (!raw) return;
                try {
                    var parsed = JSON.parse(raw);
                    if (parsed && typeof parsed === "object") {
                        engine.pendingDeletions = parsed;
                        engine.filterEmailsByActiveFolder();
                    }
                } catch (e) {}
            }
        };
        xhr.open("GET", engine.pendingDeletionsPath + "?t=" + Date.now(), true);
        xhr.send();
    }
    readonly property Process pendingDeletionsWriter: Process {}
    function savePendingDeletions() {
        pendingDeletionsWriter.command = [
            "sh", "-c",
            'mkdir -p "$HOME/.cache/himalaya"; printf "%s" "$1" > "$HOME/.cache/himalaya/pending_deletions.json"',
            "sh", JSON.stringify(engine.pendingDeletions)
        ];
        pendingDeletionsWriter.running = false;
        pendingDeletionsWriter.running = true;
    }
    function markPendingDeletion(subject, date, sender) {
        var sig = engine.makeSignature(subject, date, sender);
        var copy = Object.assign({}, engine.pendingDeletions);
        copy[sig] = Date.now();
        engine.pendingDeletions = copy;
        engine.savePendingDeletions();
    }
    function clearPendingDeletion(subject, date, sender) {
        var sig = engine.makeSignature(subject, date, sender);
        if (engine.pendingDeletions[sig] === undefined) return;
        var copy = Object.assign({}, engine.pendingDeletions);
        delete copy[sig];
        engine.pendingDeletions = copy;
        engine.savePendingDeletions();
    }
    function reconcilePendingDeletions(list) {
        if (!list || !Array.isArray(list)) return list;
        var keys = Object.keys(engine.pendingDeletions);
        if (keys.length === 0) return list;
        for (var i = 0; i < list.length; i++) {
            var m = list[i];
            if (!m) continue;
            var s = (m.from ? (m.from.addr || m.from.name || "") : (m.sender || "")).trim();
            var sig = engine.makeSignature(m.subject, m.date, s);
            if (engine.pendingDeletions[sig] !== undefined) {
                m.folder = "trash";
            }
        }
        return list;
    }
    function getMaildirFolder(folderLabel) {
        var label = (folderLabel || "").toLowerCase();
        var map = {
            "inbox": "INBOX",
            "starred": "[Gmail]/Starred",
            "important": "[Gmail]/Important",
            "steam": "Steam",
            "reddit": "INBOX",
            "all": "[Gmail]/All Mail",
            "archive": "[Gmail]/All Mail",
            "drafts": "[Gmail]/Drafts",
            "sent": "[Gmail]/Sent Mail",
            "trash": "[Gmail]/Trash",
            "spam": "[Gmail]/Spam"
        };
        return map[label] || "INBOX";
    }
    property int maxCacheItems: 500
    function pruneCache() {
        if (!engine.fullMailCacheList || engine.fullMailCacheList.length <= engine.maxCacheItems) return;
        var sorted = engine.fullMailCacheList.slice().sort(function(a, b) {
            var ta = Date.parse(a && a.date) || 0;
            var tb = Date.parse(b && b.date) || 0;
            return tb - ta;
        });
        engine.fullMailCacheList = sorted.slice(0, engine.maxCacheItems);
    }
    function saveMailCacheDisk() {
        engine.pruneCache();
        var payload = JSON.stringify(engine.fullMailCacheList);
        var byteCount = unescape(encodeURIComponent(payload)).length;
        cacheWriterProc.command = [
            "sh", "-c",
            'mkdir -p "$HOME/.cache/himalaya"; ' +
            'TMP="$HOME/.cache/himalaya/emails.json.tmp.$$"; ' +
            'head -c "$1" > "$TMP"; ' +
            'if [ -s "$TMP" ]; then mv -f "$TMP" "$HOME/.cache/himalaya/emails.json"; else rm -f "$TMP"; fi',
            "sh",
            String(byteCount)
        ];
        cacheWriterProc.pendingPayload = payload;
        cacheWriterProc.running = false;
        cacheWriterProc.running = true;
    }
    Process {
        id: cacheWriterProc
        property string pendingPayload: ""
        onStarted: {
            if (cacheWriterProc.pendingPayload.length > 0) {
                cacheWriterProc.write(cacheWriterProc.pendingPayload);
                cacheWriterProc.pendingPayload = "";
            }
        }
    }
    function readMailCache() {
        if (cacheFilePath === "") return;
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    var raw = xhr.responseText ? xhr.responseText.trim() : "";
                    if (!raw || raw.length === 0 || !raw.startsWith("[")) return;
                    try {
                        var parsedData = JSON.parse(raw);
                        if (Array.isArray(parsedData)) {
                            parsedData = engine.reconcilePendingDeletions(parsedData);
                            if (engine.fullMailCacheList && engine.fullMailCacheList.length > 0) {
                                var memBodies = {};
                                for (var _i = 0; _i < engine.fullMailCacheList.length; _i++) {
                                    var _m = engine.fullMailCacheList[_i];
                                    if (_m && _m.body_content && _m.body_content.trim() !== "") {
                                        var _key = (_m.subject || "") + "|" + (_m.date || "") + "|" + ((_m.from && _m.from.addr) ? _m.from.addr : "");
                                        memBodies[_key] = _m.body_content;
                                    }
                                }
                                for (var _j = 0; _j < parsedData.length; _j++) {
                                    var _p = parsedData[_j];
                                    if (!_p || (_p.body_content && _p.body_content.trim() !== "")) continue;
                                    var _pk = (_p.subject || "") + "|" + (_p.date || "") + "|" + ((_p.from && _p.from.addr) ? _p.from.addr : "");
                                    if (memBodies[_pk]) _p.body_content = memBodies[_pk];
                                }
                            }
                            engine.fullMailCacheList = parsedData;
                            if (Object.keys(engine.pendingDeletions).length > 0) {
                                var presentSigs = {};
                                for (var pi = 0; pi < parsedData.length; pi++) {
                                    var pm = parsedData[pi];
                                    if (!pm) continue;
                                    var ps = (pm.from ? (pm.from.addr || pm.from.name || "") : (pm.sender || "")).trim();
                                    presentSigs[engine.makeSignature(pm.subject, pm.date, ps)] = true;
                                }
                                var next = {};
                                var changed = false;
                                for (var key in engine.pendingDeletions) {
                                    if (presentSigs[key]) next[key] = engine.pendingDeletions[key];
                                    else changed = true;
                                }
                                if (changed) {
                                    engine.pendingDeletions = next;
                                    engine.savePendingDeletions();
                                }
                            }
                            engine.recalculateFolderStats();
                            engine.filterEmailsByActiveFolder();
                            engine.prefetchIndex = 0;
                            prefetchTimer.restart();
                        }
                    } catch (e) {
                        console.log("[EmailEngine] Index extraction fault: " + e.message);
                    }
                }
            }
        }
        var cacheBuster = cacheFilePath + "?t=" + Date.now();
        xhr.open("GET", cacheBuster, true);
        xhr.send();
    }
    function getNormalizedDateKey(dateStr) {
        if (!dateStr || dateStr.trim() === "") return "";
        var parsed = Date.parse(dateStr);
        if (!isNaN(parsed) && parsed > 0) {
            return String(Math.floor(parsed / 60000));
        }
        return dateStr.trim();
    }
    function recalculateFolderStats() {
        var counts = {};
        for (var f = 0; f < engine.folderList.length; f++) {
            counts[engine.folderList[f]] = 0;
        }
        var seenStarredIds = {}, seenAllIds = {};
        fullMailCacheList.forEach(mail => {
            if (!mail || !mail.folder) return;
            var folder = mail.folder.toLowerCase();
            var flags = (mail.flags || []).map(fl => fl.toLowerCase());
            var isStarred = flags.includes("flagged");
            var sender = (mail.from ? (mail.from.addr || mail.from.name || "") : (mail.sender || "")).trim();
            var timeKey = engine.getNormalizedDateKey(mail.date);
            var sig = (mail.subject || "").trim() + "|" + timeKey + "|" + sender;
            if (isStarred && !seenStarredIds[sig]) {
                counts["starred"] = (counts["starred"] || 0) + 1;
                seenStarredIds[sig] = true;
            }
            if (folder !== "trash" && folder !== "spam" && !seenAllIds[sig]) {
                counts["all"] = (counts["all"] || 0) + 1;
                seenAllIds[sig] = true;
            }
            if (counts[folder] !== undefined && folder !== "all" && folder !== "starred") {
                counts[folder]++;
            }
            var sText = ((mail.from ? (mail.from.name || mail.from.addr || "") : "") + " " + (mail.subject || "")).toLowerCase();
            for (var cf = 0; cf < engine.customFolders.length; cf++) {
                var cKey = engine.customFolders[cf];
                if (cKey !== "starred" && cKey !== "all" && (folder === cKey || sText.includes(cKey))) {
                    counts[cKey] = (counts[cKey] || 0) + 1;
                }
            }
        });
        engine.folderCountMap = counts;
    }
    function filterEmailsByActiveFolder() {
        var targetFolder = folderList[currentFolderIndex];
        var matchingMails = [];
        var seenIds = {};
        var query = searchString.trim();
        if (query !== "" && !searchCaseSensitive) { query = query.toLowerCase(); }
        for (var i = 0; i < fullMailCacheList.length; i++) {
            var mail = fullMailCacheList[i];
            if (mail) {
                var belongsToFolder = (mail.folder === targetFolder);
                if (targetFolder === "all") {
                    belongsToFolder = (mail.folder !== "trash" && mail.folder !== "spam");
                } else if (targetFolder === "starred") {
                    var isStarred = (mail.flags || []).map(fl => fl.toLowerCase()).includes("flagged");
                    belongsToFolder = isStarred;
                } else if (engine.customFolders.includes(targetFolder)) {
                    var customText = ((mail.from ? (mail.from.name || mail.from.addr || "") : "") + " " + (mail.subject || "")).toLowerCase();
                    belongsToFolder = (mail.folder === targetFolder) || customText.includes(targetFolder);
                }
                if (belongsToFolder) {
                    var senderPart = (mail.from ? (mail.from.addr || mail.from.name || "") : (mail.sender || "")).trim();
                    var timeKey = engine.getNormalizedDateKey(mail.date);
                    var compoundKey = (mail.subject || "").trim() + "|" + timeKey + "|" + senderPart;
                    if (targetFolder !== "trash" && engine.pendingDeletions[compoundKey] !== undefined) continue;
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
        var isStarredFolder = (folderList[currentFolderIndex] === "starred");
        if (isStarred || isStarredFolder) {
            Quickshell.execDetached([
                "notify-send", "-a", "Himalaya", "-i", "starred",
                "⭐ Starred Email Protected",
                "Starred emails cannot be deleted. Press 'S' to unstar first."
            ]);
            return;
        }
        var currentFolder = (activeItem.folder || "").toLowerCase();
        var targetId = activeItem.id !== undefined ? activeItem.id.toString() : "";
        var targetMsgId = activeItem["message-id"] || "";
        var targetSub = activeItem.subject || "";
        var targetDate = activeItem.date || "";
        var targetSender = (activeItem.from ? (activeItem.from.addr || activeItem.from.name || "") : (activeItem.sender || "")).trim();
        var targetTimeKey = engine.getNormalizedDateKey(targetDate);
        var trashFolderArg = getMaildirFolder("trash");
        var sourceFolderArg = getMaildirFolder(currentFolder);
        markPendingDeletion(targetSub, targetDate, targetSender);
        if (currentFolder === "trash") {
            writeToQueue("DELETE", targetId, trashFolderArg, "", "");
            fullMailCacheList = fullMailCacheList.filter(item => {
                if (!item) return false;
                if (targetId !== "" && item.id !== undefined && item.id.toString() === targetId) return false;
                if (targetMsgId !== "" && item["message-id"] && item["message-id"] === targetMsgId) return false;
                var s = (item.from ? (item.from.addr || item.from.name || "") : (item.sender || "")).trim();
                return !((item.subject || "") === targetSub && (item.date || "") === targetDate && s === targetSender);
            });
        } else {
            writeToQueue("MOVE", targetId, sourceFolderArg, trashFolderArg, "");
            fullMailCacheList.forEach(item => {
                if (!item) return;
                var s = (item.from ? (item.from.addr || item.from.name || "") : (item.sender || "")).trim();
                var timeKey = engine.getNormalizedDateKey(item.date);
                var isDirectMatch = (targetId !== "" && item.id !== undefined && item.id.toString() === targetId) || (targetMsgId !== "" && item["message-id"] && item["message-id"] === targetMsgId);
                var isDuplicateMatch = (targetSub !== "" && item.subject === targetSub && s === targetSender && (targetTimeKey === "" || timeKey === targetTimeKey));
                if (isDirectMatch || isDuplicateMatch) {
                    item.folder = "trash";
                }
            });
        }
        recalculateFolderStats();
        filterEmailsByActiveFolder();
        saveMailCacheDisk();
    }
    function handleRestoreFromTrash() {
        var activeItem = selectedMail;
        if (!activeItem || activeItem.folder.toLowerCase() !== "trash") return;
        var emailId = activeItem.id.toString();
        writeToQueue("MOVE", emailId, getMaildirFolder("trash"), getMaildirFolder("inbox"), "");
        activeItem.folder = "inbox";
        recalculateFolderStats();
        filterEmailsByActiveFolder();
        saveMailCacheDisk();
    }
    function handleStarToggle() {
        var activeItem = selectedMail;
        if (!activeItem) return;
        var folderArg = getMaildirFolder(activeItem.folder);
        var isStarred = (activeItem.flags || []).map(f => f.toLowerCase()).includes("flagged");
        writeToQueue(isStarred ? "UNSTAR" : "STAR", activeItem.id.toString(), folderArg, "", "");
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
        saveMailCacheDisk();
    }
    function handleReadToggle(targetItem, forceRead) {
        var activeItem = targetItem ? targetItem : selectedMail;
        if (!activeItem) return;
        var folderArg = getMaildirFolder(activeItem.folder);
        var isRead = (activeItem.flags || []).map(f => f.toLowerCase()).includes("seen");
        var shouldMarkRead = forceRead !== undefined ? forceRead : !isRead;
        if (shouldMarkRead === isRead) return;
        writeToQueue(shouldMarkRead ? "READ" : "UNREAD", activeItem.id.toString(), folderArg, "", "");
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
        saveMailCacheDisk();
    }
    function saveDraft(toAddress, subjectLine, bodyContent) {
        var to = (toAddress || "").trim();
        var sub = (subjectLine || "").trim();
        var body = bodyContent || "";
        if (to === "" && sub === "" && body === "") return;
        writeToQueue("DRAFT", to, sub, body, "");
        var draftEntry = {
            "id": "draft_" + Date.now(),
            "folder": "drafts",
            "subject": sub !== "" ? sub : "(Draft: No Subject)",
            "date": new Date().toISOString(),
            "from": { "name": "Me", "addr": "" },
            "to": [{ "addr": to }],
            "flags": ["draft"],
            "body_content": body
        };
        var updated = engine.fullMailCacheList.slice();
        updated.unshift(draftEntry);
        engine.fullMailCacheList = updated;
        engine.recalculateFolderStats();
        engine.filterEmailsByActiveFolder();
        engine.saveMailCacheDisk();
        Quickshell.execDetached(["notify-send", "-a", "Email", "-i", "mail-message-new", "📝 Draft Saved", "Saved to Drafts mailbox."]);
    }

    function handleOutboundDelivery(toAddress, subjectLine, bodyContent, attachments) {
        if (!toAddress || toAddress.trim() === "") return;
        var to = toAddress.trim();
        var sub = subjectLine.trim();

        var cleanAttachments = [];
        if (Array.isArray(attachments)) {
            for (var i = 0; i < attachments.length; i++) {
                var path = String(attachments[i] || "");
                if (path.startsWith("file://")) {
                    path = path.replace(/^file:\/\//, "");
                }
                if (path.trim() !== "") {
                    cleanAttachments.push(path.trim());
                }
            }
        }
        var attachmentArg = cleanAttachments.join(",");

        writeToQueue("SEND", to, sub, bodyContent, attachmentArg);

        var sentEntry = {
            "id": "sent_" + Date.now(),
            "folder": "sent",
            "subject": sub !== "" ? sub : "(No Subject)",
            "date": new Date().toISOString(),
            "from": { "name": "Me", "addr": "" },
            "to": [{ "addr": to }],
            "flags": ["seen"],
            "body_content": bodyContent
        };

        var updated = engine.fullMailCacheList.filter(function(m) {
            if (!m) return false;
            if (m.folder === "drafts" && m.subject === sub && (m.to && m.to.length > 0 && m.to[0].addr === to)) {
                return false;
            }
            return true;
        });

        updated.unshift(sentEntry);
        engine.fullMailCacheList = updated;
        engine.recalculateFolderStats();
        engine.filterEmailsByActiveFolder();
        engine.saveMailCacheDisk();

        if (typeof shell !== "undefined" && shell && shell.settingsManager && shell.settingsManager.emailSoundEnabled) {
            var sound = shell.settingsManager.emailSendSound;
            if (sound && sound.length > 0) {
                Quickshell.execDetached(["pw-play", sound]);
            }
        }
        isComposing = false;
    }

}
