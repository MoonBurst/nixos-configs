import QtQuick
import QtQuick.LocalStorage
import QtQuick.Dialogs

Item {
    id: rootWindow

    // ============================================================================
    // CONFIG PROFILE VARIABLES (SAFE VARIABLE CHECKS AGAINST THE THEME OBJECT)
    // ============================================================================
    property color windowBgColor: (typeof theme !== 'undefined') ? theme.base00 : "#121212"
    property color outerBorderColor: (typeof theme !== 'undefined') ? theme.outerBorderColor : "#003399"
    property color innerBorderColor: (typeof theme !== 'undefined') ? theme.innerBorderColor : "#FABD2F"

    property int outerBorderThickness: 5
    property int innerCardActiveThickness: 5

    property int sidebarColumnWidth: 250
    property int listingColumnWidth: 500
    property int previewColumnWidth: 750

    width: 1500; height: 1000; focus: true

    property var quickshellContext: null
    property string fallbackUsername: "moonburst"
    property string activeUser: "moonburst"
    property double lastDeleteTime: 0

    // Property alias to expose the timer to child scopes
    property alias cacheRefreshTimer: cacheRefreshTimer

    Component.onCompleted: {
        mailListView.forceActiveFocus();
        mailController.cacheFilePath = "file:///home/" + rootWindow.activeUser + "/.cache/himalaya/emails.json";
        mailController.readMailCache();
    }

    onVisibleChanged: { if (visible) { mailListView.forceActiveFocus(); mailController.readMailCache(); } }

    EmailController { id: mailController }

    // ============================================================================
    // CACHE VISUAL PREVIEW LINKER (LAZY-LOADING INTERCEPTOR)
    // ============================================================================
    Connections {
        target: mailController
        function onSelectedMailChanged() {
            var activeItem = mailController.selectedMail;
            if (!activeItem) { mailController.activeMailBody = ""; return; }

            // If email body is already cached, render instantly.
            // If body is empty, display placeholder, trigger background fetch queue, and start poller
            if (activeItem.body_content && activeItem.body_content.trim() !== "") {
                mailController.activeMailBody = activeItem.body_content;
            } else {
                mailController.activeMailBody = "Fetching message body from server...";
                bodyFetchPoller.lastTargetId = activeItem.id.toString();
                bodyFetchPoller.attempts = 0;
                bodyFetchPoller.start();

                var folderArg = getMaildirFolder(activeItem.folder);
                writeToQueue("FETCH_BODY", activeItem.id.toString(), folderArg, "");
            }

            // Automatically mark email as READ when selected
            var flags = activeItem.flags || [];
            var isUnread = true;
            for (var i = 0; i < flags.length; i++) {
                if (flags[i].toLowerCase() === "seen") {
                    isUnread = false;
                    break;
                }
            }
            if (isUnread) {
                rootWindow.handleReadToggle(activeItem, true);
            }
        }
    }

    // ============================================================================
    // DYNAMIC 100ms LAZY BODY POLLING TIMER (WITH MODEL REFRESH FIX)
    // ============================================================================
    Timer {
        id: bodyFetchPoller
        interval: 100
        running: false
        repeat: true

        property string lastTargetId: ""
        property int attempts: 0

        onTriggered: {
            attempts++;
            if (attempts > 30) { // Timeout after 3 seconds of silent failures
                bodyFetchPoller.stop();
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
                            mailController.activeMailBody = bodyText;

                            // Save permanently in cache memory context and reload model to render previews
                            var activeItem = mailController.selectedMail;
                            if (activeItem && activeItem.id.toString() === bodyId) {
                                activeItem.body_content = bodyText;
                                mailController.readMailCache(); // Forces QML to reload index cache and render loaded previews instantly
                            }
                            bodyFetchPoller.stop();
                        }
                    }
                }
            }
            xhr.open("GET", "file:///tmp/qmail_active_body.txt", true);
            xhr.send();
        }
    }

    // ============================================================================
    // CACHE REFRESH TIMER (BRIDGES THE ASYNC DAEMON WORKFLOW WITH THE UI)
    // ============================================================================
    Timer {
        id: cacheRefreshTimer
        interval: 1200 // 1.2 second delay allows the Python daemon to process the DB row & rebuild cache
        repeat: false
        onTriggered: {
            console.log("[Email] Sync interval elapsed. Refreshing mail cache...");
            mailController.readMailCache();
        }
    }

    Shortcut { sequence: "Ctrl+F"; enabled: !mailController.isComposing && !contactModalOverlay.visible && !helpModalOverlay.visible; onActivated: mailListView.toggleSearch() }
    Shortcut { sequence: "Shift+?"; enabled: !mailController.isComposing && !contactModalOverlay.visible; onActivated: helpModalOverlay.visible = !helpModalOverlay.visible }

    function getDatabase() { return LocalStorage.openDatabaseSync("QMailQueue", "1.0", "Queue for outbound mail operations", 100000); }

    function writeToQueue(action, arg1, arg2, arg3) {
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS queue (id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT, arg1 TEXT, arg2 TEXT, arg3 TEXT)");
                tx.executeSql("INSERT INTO queue (action, arg1, arg2, arg3) VALUES (?, ?, ?, ?)", [action, arg1, arg2, arg3]);
            });
        } catch (err) { console.log("[Local Queue Error]: " + err); }
    }

    // ============================================================================
    // NATIVE MAILDIR ROUTERS
    // ============================================================================
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

    // ============================================================================
    // SYSTEM HANDLERS
    // ============================================================================
    function handleDeletion() {
        var activeItem = mailController.selectedMail;
        if (!activeItem) return;

        var currentTime = Date.now();
        if (currentTime - lastDeleteTime < 250) return; // Cooldown gate
        lastDeleteTime = currentTime;

        var isStarred = (activeItem.flags || []).map(f => f.toLowerCase()).some(f => f === "flagged" || f === "starred");
        if (isStarred) { console.log("[Safety Guard] Blocked deletion of a Starred email."); return; }

        var folderArg = getMaildirFolder(activeItem.folder);
        writeToQueue("DELETE", activeItem.id.toString(), folderArg, "");

        var targetMsgId = activeItem["message-id"];
        var targetSub = activeItem.subject || "";
        var targetDate = activeItem.date || "";
        var targetSender = (activeItem.from ? (activeItem.from.addr || activeItem.from.name || "") : (activeItem.sender || "")).trim();

        // One-liner array filter
        mailController.fullMailCacheList = mailController.fullMailCacheList.filter(item => {
            var s = (item.from ? (item.from.addr || item.from.name || "") : (item.sender || "")).trim();
            return !(targetMsgId ? item["message-id"] === targetMsgId : ((item.subject || "") === targetSub && (item.date || "") === targetDate && s === targetSender));
        });

        mailController.recalculateFolderStats();
        mailController.filterEmailsByActiveFolder();
    }

    function handleRestoreFromTrash() {
        var activeItem = mailController.selectedMail;
        if (!activeItem || activeItem.folder.toLowerCase() !== "trash") return;

        var emailId = activeItem.id.toString();

        // Write the MOVE recovery action to the SQLite database queue
        writeToQueue("MOVE", emailId, "trash", "inbox");
        console.log("[Queue] Restoring message " + emailId + " back to inbox.");

        // Remove the email from the local trash array immediately to provide snappy UI feedback
        mailController.fullMailCacheList = mailController.fullMailCacheList.filter(item => {
            return !(item.id.toString() === emailId && item.folder.toLowerCase() === "trash");
        });

        mailController.recalculateFolderStats();
        mailController.filterEmailsByActiveFolder();
    }

    function handleStarToggle() {
        var activeItem = mailController.selectedMail;
        if (!activeItem) return;

        var folderArg = getMaildirFolder(activeItem.folder);
        var isStarred = (activeItem.flags || []).map(f => f.toLowerCase()).includes("flagged");

        writeToQueue(isStarred ? "UNSTAR" : "STAR", activeItem.id.toString(), folderArg, "");

        var activeSender = (activeItem.from ? (activeItem.from.addr || activeItem.from.name || "") : (activeItem.sender || "")).trim();
        var activeSubject = activeItem.subject || "";
        var activeDate = activeItem.date || "";

        // Condensed array iterator
        mailController.fullMailCacheList.forEach(item => {
            var s = (item.from ? (item.from.addr || item.from.name || "") : (item.sender || "")).trim();
            if ((item.subject || "") === activeSubject && (item.date || "") === activeDate && s === activeSender) {
                var fList = item.flags || [];
                var fIdx = fList.findIndex(f => f.toLowerCase() === "flagged");
                if (isStarred && fIdx !== -1) fList.splice(fIdx, 1);
                else if (!isStarred && fIdx === -1) fList.push("flagged");
                item.flags = fList;
            }
        });
        mailController.filterEmailsByActiveFolder();
    }

    function handleReadToggle(targetItem, forceRead) {
        var activeItem = targetItem ? targetItem : mailController.selectedMail;
        if (!activeItem) return;

        var folderArg = getMaildirFolder(activeItem.folder);
        var isRead = (activeItem.flags || []).map(f => f.toLowerCase()).includes("seen");
        var shouldMarkRead = forceRead !== undefined ? forceRead : !isRead;
        if (shouldMarkRead === isRead) return;

        writeToQueue(shouldMarkRead ? "READ" : "UNREAD", activeItem.id.toString(), folderArg, "");

        var activeSender = (activeItem.from ? (activeItem.from.addr || activeItem.from.name || "") : (activeItem.sender || "")).trim();
        var activeSubject = activeItem.subject || "";
        var activeDate = activeItem.date || "";

        mailController.fullMailCacheList.forEach(item => {
            var s = (item.from ? (item.from.addr || item.from.name || "") : (item.sender || "")).trim();
            if ((item.subject || "") === activeSubject && (item.date || "") === activeDate && s === activeSender) {
                var fList = item.flags || [];
                var fIdx = fList.findIndex(f => f.toLowerCase() === "seen");
                if (shouldMarkRead && fIdx === -1) fList.push("seen");
                else if (!shouldMarkRead && fIdx !== -1) fList.splice(fIdx, 1);
                item.flags = fList;
            }
        });
        mailController.recalculateFolderStats();
        mailController.filterEmailsByActiveFolder();
    }

    function initiateEmailReply() {
        var activeItem = mailController.selectedMail;
        if (!activeItem) return;
        var replyTo = activeItem.from ? (activeItem.from.addr || activeItem.from.name) : "";
        var conversationLog = "\n\n----------------------------------------\nFrom: " + replyTo + "\nSubject: " + activeItem.subject + "\n\n" + mailController.activeMailBody;
        mailController.isComposing = true;
        composeWindowOverlay.prepopulateForm(replyTo, activeItem.subject.startsWith("Re:") ? activeItem.subject : "Re: " + activeItem.subject, conversationLog);
    }

    // Opens and restores a draft without adding standard reply metadata or doubling signatures
    function initiateDraftEdit() {
        var activeItem = mailController.selectedMail;
        if (!activeItem) return;
        var draftTo = activeItem.from ? (activeItem.from.addr || activeItem.from.name) : "";
        var draftSubject = activeItem.subject || "";
        var draftBody = mailController.activeMailBody || "";
        mailController.isComposing = true;
        composeWindowOverlay.restoreDraftForm(draftTo, draftSubject, draftBody);
    }

    function handleOutboundDelivery(toAddress, subjectLine, bodyContent) {
        if (!toAddress || toAddress.trim() === "") return;
        writeToQueue("SEND", toAddress.trim(), subjectLine.trim(), bodyContent);
        composeWindowOverlay.visible = false;
        mailController.isComposing = false;
    }

    Keys.onPressed: (event) => {
        if (mailController.isComposing || contactModalOverlay.visible || helpModalOverlay.visible) return;
        var isAltPressed = (event.modifiers === Qt.AltModifier) || (event.modifiers & Qt.AltModifier) !== 0;

        if (isAltPressed) {
            if (event.key === Qt.Key_Up) { mailController.cycleFolder(false); event.accepted = true; }
            else if (event.key === Qt.Key_Down) { mailController.cycleFolder(true); event.accepted = true; }
        } else {
            if (event.key === Qt.Key_Up) { mailController.cycleEmail(false); event.accepted = true; }
            else if (event.key === Qt.Key_Down) { mailController.cycleEmail(true); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var activeItem = mailController.selectedMail;
                if (activeItem && activeItem.folder.toLowerCase() === "drafts") {
                    rootWindow.initiateDraftEdit();
                } else {
                    rootWindow.initiateEmailReply();
                }
                event.accepted = true;
            }
            else if (event.key === Qt.Key_Delete) { rootWindow.handleDeletion(); event.accepted = true; }
            else if (event.key === Qt.Key_U) { rootWindow.handleRestoreFromTrash(); event.accepted = true; } // 'U' Key restores from Trash
            else if (event.key === Qt.Key_N) { mailController.isComposing = true; composeWindowOverlay.prepopulateForm("", "", ""); event.accepted = true; }
            else if (event.key === Qt.Key_S) { rootWindow.handleStarToggle(); event.accepted = true; }
            else if (event.key === Qt.Key_R) { rootWindow.handleReadToggle(); event.accepted = true; }
            else if (event.text === "?") { helpModalOverlay.visible = true; event.accepted = true; }
        }
    }

    Rectangle {
        anchors.fill: parent; color: rootWindow.windowBgColor
        border.color: rootWindow.outerBorderColor; border.width: rootWindow.outerBorderThickness; radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10

        Row {
            anchors.fill: parent

            SidebarView {
                width: rootWindow.sidebarColumnWidth; height: parent.height
                folderListModel: mailController.folderList; activeFolderIndex: mailController.currentFolderIndex; countsDictionary: mailController.folderCountMap
                onHelpRequested: helpModalOverlay.visible = true
            }

            EmailListView {
                id: mailListView; width: rootWindow.listingColumnWidth; height: parent.height
                mailItems: mailController.filteredMails; activeMailIndex: mailController.currentMailIndex; focus: true

                onSearchQueryChanged: mailController.searchString = searchQuery
                onSearchCaseSensitiveChanged: mailController.searchCaseSensitive = searchCaseSensitive
                onStarToggled: (index) => { mailController.currentMailIndex = index; mailController.selectedMail = mailController.filteredMails[index]; rootWindow.handleStarToggle(); }
                onReadToggled: (index) => { mailController.currentMailIndex = index; mailController.selectedMail = mailController.filteredMails[index]; rootWindow.handleReadToggle(); }
            }

            EmailPreview {
                width: rootWindow.previewColumnWidth; height: parent.height; activeMailObject: mailController.selectedMail; activeMailBodyText: mailController.activeMailBody; focus: false
                onContactRequested: (email) => contactModalOverlay.openContactPrompt(email)

                // Direct attachments download request hook
                onDownloadAttachmentsRequested: (msgId, folderLabel) => {
                    rootWindow.writeToQueue("DOWNLOAD_ATTACHMENTS", msgId, getMaildirFolder(folderLabel), "");
                }
            }
        }

        ComposeModal {
            id: composeWindowOverlay; anchors.fill: parent; visible: mailController.isComposing
            onEscapeDismissRequested: {
                mailController.isComposing = false;
                mailListView.forceActiveFocus();
                cacheRefreshTimer.start(); // Trigger draft sync polling helper
            }
            onDispatchMailRequested: (to, subject, body) => {
                rootWindow.handleOutboundDelivery(to, subject, body);
                mailListView.forceActiveFocus();
                cacheRefreshTimer.start(); // Trigger delivery sync polling helper
            }

            // Trigger root-level native file selection dialog when attachment is requested inside modal
            onAttachmentRequested: {
                fileDialog.open();
            }
        }

        // ============================================================================
        // CONTACTS DIALOG OVERLAY modal box
        // ============================================================================
        Rectangle {
            id: contactModalOverlay; anchors.fill: parent; color: "#F40F0F0F"; visible: false
            property string targetEmail: ""

            function openContactPrompt(email) { targetEmail = email; nicknameInput.text = ""; visible = true; nicknameInput.forceActiveFocus(); }
            MouseArea { anchors.fill: parent }

            Rectangle {
                width: 400; height: 220; color: rootWindow.windowBgColor; border.color: rootWindow.innerBorderColor; border.width: rootWindow.innerCardActiveThickness
                radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10; anchors.centerIn: parent

                Column {
                    anchors.fill: parent; anchors.margins: 20; spacing: 15

                    Text { text: "ADD TO CONTACTS"; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"; font.pixelSize: (typeof theme !== 'undefined') ? theme.globalFontSize : 20; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700" }
                    Text { text: "Email: " + contactModalOverlay.targetEmail; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" ; font.pixelSize: (typeof theme !== 'undefined') ? theme.globalFontSize - 4 : 16; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; elide: Text.ElideRight; width: parent.width }

                    Rectangle {
                        width: parent.width; height: 40; color: (typeof theme !== 'undefined') ? theme.base00 : "#121212"; border.color: nicknameInput.activeFocus ? rootWindow.innerBorderColor : ((typeof theme !== 'undefined') ? theme.base01 : "#0f0f0f"); border.width: 1; radius: 6

                        TextInput {
                            id: nicknameInput; anchors.fill: parent; anchors.margins: 8; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"; font.pixelSize: (typeof theme !== 'undefined') ? theme.globalFontSize - 2 : 18; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"
                            Text { text: "Enter nickname..."; color: (typeof theme !== 'undefined') ? theme.base0B : "#545454"; visible: parent.text === ""; font.pixelSize: parent.font.pixelSize; font.family: parent.font.family }
                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    rootWindow.writeToQueue("CONTACT", nicknameInput.text, contactModalOverlay.targetEmail, "");
                                    contactModalOverlay.visible = false; mailListView.forceActiveFocus(); event.accepted = true;
                                }
                            }
                        }
                    }

                    Text { text: "Press [Enter] to Save  •  [ESC] to Cancel"; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"; font.pixelSize: (typeof theme !== 'undefined') ? theme.globalFontSize - 6 : 14; color: (typeof theme !== 'undefined') ? theme.base0B : "#545454"; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }

            Shortcut { sequence: "Escape"; enabled: contactModalOverlay.visible; onActivated: { contactModalOverlay.visible = false; mailListView.forceActiveFocus(); } }
        }

        // ============================================================================
        // KEYBOARD SHORTCUTS CHEATSHEET OVERLAY modal box
        // ============================================================================
        Rectangle {
            id: helpModalOverlay; anchors.fill: parent; color: "#F40F0F0F"; visible: false
            MouseArea { anchors.fill: parent }

            Rectangle {
                width: 500; height: 400; color: rootWindow.windowBgColor; border.color: rootWindow.innerBorderColor; border.width: rootWindow.innerCardActiveThickness
                radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10; anchors.centerIn: parent

                Column {
                    anchors.fill: parent; anchors.margins: 25; spacing: 15
                    Text { text: "KEYBOARD SHORTCUTS CHEATSHEET"; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"; font.pixelSize: (typeof theme !== 'undefined') ? theme.globalFontSize : 20; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; anchors.horizontalCenter: parent.horizontalCenter }
                    Rectangle { width: parent.width; height: 1; color: (typeof theme !== 'undefined') ? theme.base01 : "#3c3836" }

                    Grid {
                        columns: 2; columnSpacing: 30; rowSpacing: 10; width: parent.width

                        Text { text: "Alt + ↑ / ↓"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Cycle Folders / Mailboxes"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "↑ / ↓"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Cycle Emails in List"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "Enter / Return"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Reply to Selected Email"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "N"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Compose New Email"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "Delete"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Delete Email (Cascade)"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "U"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Restore Email from Trash"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "S"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Toggle Star / Unstar"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "R"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Toggle Read / Unread"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "Ctrl + F"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Toggle Search Bar"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "? (Shift + /)"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Toggle This Help Menu"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                    }

                    Item { width: 1; height: 10 }
                    Text { text: "Press [ESC] or [?] to Dismiss Cheatsheet"; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"; font.pixelSize: 14; color: (typeof theme !== 'undefined') ? theme.base0B : "#545454"; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }

            Shortcut { sequence: "Escape"; enabled: helpModalOverlay.visible; onActivated: { helpModalOverlay.visible = false; mailListView.forceActiveFocus(); } }
            Shortcut { sequence: "Shift+?"; enabled: helpModalOverlay.visible; onActivated: { helpModalOverlay.visible = false; mailListView.forceActiveFocus(); } }
        }
    }

    // ============================================================================
    // ALWAYS-ON ROOT WINDOW DRAG & DROP AREA
    // ============================================================================
    DropArea {
        id: rootDropArea
        anchors.fill: parent
        // Active ONLY when compose window and modals are closed
        enabled: !mailController.isComposing && !contactModalOverlay.visible && !helpModalOverlay.visible

        onEntered: (drag) => {
            if (drag.hasUrls) {
                drag.acceptProposedAction();
                rootDropOverlay.visible = true; // Show nice visual root drag-over feedback
            }
        }

        onExited: {
            rootDropOverlay.visible = false;
        }

        onDropped: (drop) => {
            if (drop.hasUrls) {
                // 1. Instantly open compose modal and initialize blank draft
                mailController.isComposing = true;
                composeWindowOverlay.prepopulateForm("", "", "");

                // 2. Loop through dropped files and append standard MML tags directly to the text box
                for (var i = 0; i < drop.urls.length; i++) {
                    var path = drop.urls[i].toString();
                    if (path.startsWith("file://")) {
                        path = path.substring(7);
                    }
                    path = decodeURIComponent(path);
                    composeWindowOverlay.bodyInput.text += "\n<#part filename=\"" + path + "\">\n<#/part>\n";
                }
                drop.acceptProposedAction();
            }
            rootDropOverlay.visible = false;
        }
    }

    // Visual drag-and-drop feedback overlay
    Rectangle {
        id: rootDropOverlay
        anchors.fill: parent
        color: "#E00f0f0f" // transparent dark
        visible: false
        z: 110 // Top layer

        Rectangle {
            width: parent.width - 80
            height: parent.height - 80
            color: "transparent"
            border.color: rootWindow.innerBorderColor
            border.width: 4
            radius: 10
            anchors.centerIn: parent

            Column {
                anchors.centerIn: parent
                spacing: 15

                Text { text: "📥"; font.pixelSize: 64; anchors.horizontalCenter: parent.horizontalCenter }
                Text {
                    text: "DROP TO COMPOSE NEW EMAIL WITH ATTACHMENTS"
                    font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"
                    font.pixelSize: (typeof theme !== 'undefined') ? theme.globalFontSize + 4 : 24
                    font.bold: true
                    color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // Root-level file selection dialog (Allows selecting multiple files cleanly using system portals)
    FileDialog {
        id: fileDialog
        title: "Select File(s) to Attach"
        fileMode: FileDialog.OpenFiles // Multi-file selection mode enabled
        onAccepted: {
            for (var i = 0; i < selectedFiles.length; i++) {
                var path = selectedFiles[i].toString();
                if (path.startsWith("file://")) {
                    path = path.substring(7); // Strip schema prefix
                }
                path = decodeURIComponent(path); // Decode URL-encoded spaces and characters
                // Appends the compiled MML tag directly to the body input text field
                composeWindowOverlay.bodyInput.text += "\n<#part filename=\"" + path + "\">\n<#/part>\n";
            }
        }
    }
}
