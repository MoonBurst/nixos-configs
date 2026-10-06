import QtQuick
import QtQuick.LocalStorage
import Quickshell
import Quickshell.Io

Item {
    id: engine

    property string cacheFilePath: "file://" + (Quickshell.env("HOME") || "") + "/.cache/himalaya/emails.json"
    property var fullMailCacheList: []
    property var filteredMails: []
    property var folderList: ["inbox", "starred", "steam", "reddit", "all", "sent", "drafts", "trash", "spam"]

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

    // Set of compound signatures (subject|timeKey|sender) that have been
    // queued for deletion locally but may not have propagated server-side yet.
    // These are filtered out during every refresh so a stale IMAP fetch cannot
    // resurrect an email the user already dismissed.
    property var pendingDeletions: ({})
    property string pendingDeletionsPath: "file://" + (Quickshell.env("HOME") || "") + "/.cache/himalaya/pending_deletions.json"

    property string mailSignature: (typeof shell !== "undefined" && shell && shell.settingsManager && shell.settingsManager.emailSignature)
        ? shell.settingsManager.emailSignature
        : "\n\n--\nSeekers of light..\nBelieve not in justice...\nBelieve not in truth...\nFor they are empty and inconsistent, as are all things..."

    onSearchStringChanged: filterEmailsByActiveFolder()
    onSearchCaseSensitiveChanged: filterEmailsByActiveFolder()

    Component.onCompleted: {
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

        mailSyncProc.command = [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="' + Quickshell.shellDir + '/modules/overlays/email/backend/HimalayaEngine.lua"; ' +
            'CMD="lua"; command -v luajit >/dev/null 2>&1 && CMD="luajit"; ' +
            '"$CMD" "$SCR" sync "$1"',
            "sh", safeLimit
        ];
        mailSyncProc.running = false;
        mailSyncProc.running = true;
    }
    // FIX: Declare the boot loader gate right above your process definition
    property bool isInitialLoad: true

    // One-shot: replay any queued delete/star/read actions from a previous
    // session *before* the watcher is allowed to kick off a fresh IMAP sync.
    // This guarantees the server sees the queued actions in a well-defined
    // order and prevents the sync from resurrecting items the user removed.
    readonly property Process queueFlushProc: Process {
        running: false
        command: [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="' + Quickshell.shellDir + '/modules/overlays/email/backend/HimalayaEngine.lua"; ' +
            'CMD="lua"; command -v luajit >/dev/null 2>&1 && CMD="luajit"; ' +
            '[ -f "$SCR" ] && "$CMD" "$SCR" flush || true'
        ]
        onExited: {
            // After the queue drains, refresh from disk then let the watcher
            // take over for live SYNC events.
            engine.readMailCache();
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
        command: [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="' + Quickshell.shellDir + '/modules/overlays/email/backend/HimalayaEngine.lua"; ' +
            'CMD="lua"; command -v luajit >/dev/null 2>&1 && CMD="luajit"; ' +
            '"$CMD" "$SCR" watch'
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var clean = data.trim();
                if (clean === "SYNC" || clean === "NEW_MAIL") {
                    // FIX: Prevent audio playback during initial boot load parsing
                    if (!isInitialLoad && typeof shell !== "undefined" && shell && shell.settingsManager && shell.settingsManager.emailSoundEnabled) {
                        var sound = shell.settingsManager.emailReceiveSound;
                        if (sound && sound.length > 0) {
                            Quickshell.execDetached(["pw-play", sound]);
                        }
                    }

                    // FIX: Suppress notification popups on desktop startup sync routines
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
            // The very first completed sync is our real "boot sync finished"
            // signal — no more arbitrary wall-clock guesswork. Any SYNC/NEW_MAIL
            // events that arrive after this point are genuine new mail and are
            // allowed to play sounds / show notifications.
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

    // =========================================================================
    // BACKGROUND BODY DOWNLOADER: CONTINUOUSLY DOWNLOADS AND SAVES ALL BODIES
    // =========================================================================
    property int prefetchIndex: 0
    property var currentPrefetchItem: null

    Process {
        id: singlePrefetchProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var body = text ? text.trim() : "";
                console.log("[EmailEngine] prefetch result len=" + body.length + " id=" + (engine.currentPrefetchItem ? engine.currentPrefetchItem.id : "?"));
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
            console.log("[EmailEngine] prefetch tick idx=" + engine.prefetchIndex + "/" + engine.fullMailCacheList.length + " id=" + (item ? item.id : "?") + " folder=" + (item ? (item.physical_folder || item.folder) : "?"));

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
                // Current himalaya uses --folder. Try it first so we do not
                // burn four failed IMAP round-trips per message.
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
                console.log("[EmailEngine] himalayaInstalled =", engine.himalayaInstalled, "raw:", JSON.stringify(data.trim()));
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
                // Current himalaya uses --folder. Try it first so we do not
                // burn four failed IMAP round-trips per message.
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

        Quickshell.execDetached([
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="' + Quickshell.shellDir + '/modules/overlays/email/backend/HimalayaEngine.lua"; ' +
            'CMD="lua"; command -v luajit >/dev/null 2>&1 && CMD="luajit"; ' +
            '"$CMD" "$SCR" "$1" "$2" "$3" "$4"',
            "sh",
            action || "",
            arg1 || "",
            arg2 || "",
            arg3 || ""
        ]);
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

    // Force any mail matching a pending deletion to display as belonging to
    // trash. Without this, a fresh IMAP sync would reset the local folder
    // field back to "inbox" and the mail would silently disappear from both
    // views (hidden from inbox by the pending filter, absent from trash).
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


    // Rolling cap: the on-disk cache is never allowed to exceed this many
    // entries. Prevents the emails.json file (and every in-memory copy that
    // gets serialized into it) from growing without bound over long uptimes.
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

        // Accurate UTF-8 byte length count (never truncates multibyte characters)
        var byteCount = unescape(encodeURIComponent(payload)).length;

        // head -c terminates immediately once exact bytes are received
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
                    if (!raw || raw.length === 0 || !raw.startsWith("[")) {
                        return;
                    }
                    try {
                        var parsedData = JSON.parse(raw);
                        if (Array.isArray(parsedData)) {
                            parsedData = engine.reconcilePendingDeletions(parsedData);

                            // Preserve bodies already fetched in this session.
                            // The disk file may lag memory by one save cycle
                            // when the watcher triggers a fresh sync; without
                            // this merge, the in-memory bodies would be lost.
                            if (engine.fullMailCacheList && engine.fullMailCacheList.length > 0) {
                                var memBodies = {};
                                for (var _i = 0; _i < engine.fullMailCacheList.length; _i++) {
                                    var _m = engine.fullMailCacheList[_i];
                                    if (_m && _m.body_content && _m.body_content.trim() !== "") {
                                        var _key = (_m.subject || "") + "|" + (_m.date || "") + "|" +
                                                   ((_m.from && _m.from.addr) ? _m.from.addr : "");
                                        memBodies[_key] = _m.body_content;
                                    }
                                }
                                for (var _j = 0; _j < parsedData.length; _j++) {
                                    var _p = parsedData[_j];
                                    if (!_p || (_p.body_content && _p.body_content.trim() !== "")) continue;
                                    var _pk = (_p.subject || "") + "|" + (_p.date || "") + "|" +
                                              ((_p.from && _p.from.addr) ? _p.from.addr : "");
                                    if (memBodies[_pk]) _p.body_content = memBodies[_pk];
                                }
                            }

                            engine.fullMailCacheList = parsedData;
                            console.log("[EmailEngine] cache loaded:", parsedData.length, "items; prefetchIndex reset");

                            // Reconcile pending deletions: any signature that is
                            // no longer present in the server response has been
                            // confirmed deleted and can be dropped from the set.
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

                            // Start background prefetch of all bodies so every email opens instantly
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
        var counts = { "inbox": 0, "starred": 0, "steam": 0, "reddit": 0, "all": 0, "sent": 0, "drafts": 0, "trash": 0, "spam": 0 };
        var seenStarredIds = {}, seenAllIds = {};

        fullMailCacheList.forEach(mail => {
            if (!mail || !mail.folder) return;
            var folder = mail.folder.toLowerCase();
            var flags = (mail.flags || []).map(f => f.toLowerCase());
            var isStarred = flags.includes("flagged");
            var sender = (mail.from ? (mail.from.addr || mail.from.name || "") : (mail.sender || "")).trim();
            var timeKey = engine.getNormalizedDateKey(mail.date);
            var sig = (mail.subject || "").trim() + "|" + timeKey + "|" + sender;

            if (isStarred && !seenStarredIds[sig]) {
                counts["starred"]++; seenStarredIds[sig] = true;
            }
            if (folder !== "trash" && folder !== "spam" && !seenAllIds[sig]) {
                counts["all"]++;
                seenAllIds[sig] = true;
            }
            if (counts[folder] !== undefined && folder !== "all" && folder !== "starred") {
                counts[folder]++;
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
                    var isStarred = (mail.flags || []).map(f => f.toLowerCase()).includes("flagged");
                    belongsToFolder = isStarred;
                } else if (targetFolder === "steam") {
                    var sText = ((mail.from ? (mail.from.name || mail.from.addr || "") : "") + " " + (mail.subject || "")).toLowerCase();
                    belongsToFolder = (mail.folder === "steam") || sText.includes("steampowered.com") || sText.includes("steam");
                } else if (targetFolder === "reddit") {
                    var rText = ((mail.from ? (mail.from.name || mail.from.addr || "") : "") + " " + (mail.subject || "")).toLowerCase();
                    belongsToFolder = (mail.folder === "reddit") || rText.includes("redditmail.com") || rText.includes("reddit");
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

    // 30-DAY TRASH WORKFLOW (WITH STARRED PROTECTION)
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

        // Record locally so a stale IMAP fetch on the next startup cannot
        // bring this item back. Cleared once the server round-trip confirms.
        markPendingDeletion(targetSub, targetDate, targetSender);

        if (currentFolder === "trash") {
            writeToQueue("DELETE", targetId, trashFolderArg, "");

            fullMailCacheList = fullMailCacheList.filter(item => {
                if (!item) return false;
                if (targetId !== "" && item.id !== undefined && item.id.toString() === targetId) return false;
                if (targetMsgId !== "" && item["message-id"] && item["message-id"] === targetMsgId) return false;
                var s = (item.from ? (item.from.addr || item.from.name || "") : (item.sender || "")).trim();
                return !((item.subject || "") === targetSub && (item.date || "") === targetDate && s === targetSender);
            });
        } else {
            writeToQueue("MOVE", targetId, sourceFolderArg, trashFolderArg);

            fullMailCacheList.forEach(item => {
                if (!item) return;
                var s = (item.from ? (item.from.addr || item.from.name || "") : (item.sender || "")).trim();
                var timeKey = engine.getNormalizedDateKey(item.date);

                var isDirectMatch = (targetId !== "" && item.id !== undefined && item.id.toString() === targetId)
                    || (targetMsgId !== "" && item["message-id"] && item["message-id"] === targetMsgId);
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
        writeToQueue("MOVE", emailId, getMaildirFolder("trash"), getMaildirFolder("inbox"));

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
        saveMailCacheDisk();
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
        saveMailCacheDisk();
    }

    function handleOutboundDelivery(toAddress, subjectLine, bodyContent) {
        if (!toAddress || toAddress.trim() === "") return;
        writeToQueue("SEND", toAddress.trim(), subjectLine.trim(), bodyContent);

        if (typeof shell !== "undefined" && shell && shell.settingsManager && shell.settingsManager.emailSoundEnabled) {
            var sound = shell.settingsManager.emailSendSound;
            if (sound && sound.length > 0) {
                Quickshell.execDetached(["pw-play", sound]);
            }
        }
        isComposing = false;
    }
}
