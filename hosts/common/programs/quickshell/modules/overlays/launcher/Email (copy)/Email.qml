import QtQuick
import QtQuick.LocalStorage

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

    width: 1500
    height: 1000
    focus: true

    property var quickshellContext: null
    property string fallbackUsername: "moonburst"
    property string activeUser: "moonburst"

    Component.onCompleted: {
        // Force active focus directly onto the email list at startup
        mailListView.forceActiveFocus();
        mailController.cacheFilePath = "file:///home/" + rootWindow.activeUser + "/.cache/himalaya/emails.json";
        mailController.readMailCache();
    }

    onVisibleChanged: {
        if (visible) {
            mailListView.forceActiveFocus();
            mailController.readMailCache();
        }
    }

    EmailController {
        id: mailController
    }

    // ============================================================================
    // CACHE VISUAL PREVIEW LINKER (AUTOMATICALLY MARKS SELECTED EMAIL AS READ)
    // ============================================================================
    Connections {
        target: mailController
        function onSelectedMailChanged() {
            var activeItem = mailController.selectedMail;
            if (!activeItem) {
                mailController.activeMailBody = "";
                return;
            }

            if (activeItem.body_content && activeItem.body_content.trim() !== "") {
                mailController.activeMailBody = activeItem.body_content;
            } else {
                mailController.activeMailBody = "(No plain text variant available for this message entry.)";
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
    // GLOBAL WINDOW SHORTCUT BINDINGS
    // ============================================================================
    Shortcut {
        sequence: "Ctrl+F"
        enabled: !mailController.isComposing && !contactModalOverlay.visible && !helpModalOverlay.visible
        onActivated: {
            mailListView.toggleSearch();
        }
    }

    Shortcut {
        sequence: "Shift+?"
        enabled: !mailController.isComposing && !contactModalOverlay.visible
        onActivated: {
            helpModalOverlay.visible = !helpModalOverlay.visible;
        }
    }

    // ============================================================================
    // STANDALONE OFFLINE SQLITE STORAGE DRIVER
    // ============================================================================
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
            console.log("[Local Queue Error]: Failed to write database row: " + err);
        }
    }

    // ============================================================================
    // NATIVE MAILDIR FOLDER ROUTER
    // ============================================================================
    function getMaildirFolder(folderLabel) {
        var label = (folderLabel || "").toLowerCase();
        if (label === "inbox") return "INBOX";
        if (label === "starred") return ".[Gmail].Starred";
        if (label === "all") return ".[Gmail].All Mail";
        if (label === "drafts") return ".[Gmail].Drafts";
        if (label === "sent") return ".[Gmail].Sent Mail";
        if (label === "trash") return ".[Gmail].Trash";
        if (label === "spam") return ".[Gmail].Spam";
        return "INBOX";
    }

    // ============================================================================
    // SYSTEM HANDLERS
    // ============================================================================
    function handleDeletion() {
        var activeItem = mailController.selectedMail;
        if (!activeItem) return;

        // 1. SAFETY DELETION GUARD: Scan metadata for active starred flags
        var isStarred = false;
        if (activeItem.flags && Array.isArray(activeItem.flags)) {
            for (var i = 0; i < activeItem.flags.length; i++) {
                var flag = activeItem.flags[i].toLowerCase();
                if (flag === "flagged" || flag === "starred") {
                    isStarred = true;
                    break;
                }
            }
        }

        if (isStarred) {
            console.log("[Safety Guard] Blocked deletion of a Starred email. Unstar it first to delete.");
            return;
        }

        var folderArg = getMaildirFolder(activeItem.folder);

        console.log("[Quickshell Deletion Engine] Queueing background deletion...");
        writeToQueue("DELETE", activeItem.id.toString(), folderArg, "");

        // Extract unique signatures to target duplicate folder file copies
        var targetMsgId = activeItem["message-id"];
        var targetSub = activeItem.subject || "";
        var targetDate = activeItem.date || "";
        var targetSender = activeItem.from ? (activeItem.from.addr || activeItem.from.name || "") : (activeItem.sender || "");

        // 2. Cascade Purge duplicate items from the master memory list (fullMailCacheList)
        var cacheList = mailController.fullMailCacheList;
        var updatedCacheList = [];
        for (var i = 0; i < cacheList.length; i++) {
            var item = cacheList[i];
            var itemSender = item.from ? (item.from.addr || item.from.name || "") : (item.sender || "");

            var isTarget = false;
            if (targetMsgId && item["message-id"] === targetMsgId) {
                isTarget = true;
            } else if ((item.subject || "") === targetSub && (item.date || "") === targetDate && itemSender === targetSender) {
                isTarget = true;
            }

            if (isTarget) {
                continue;
            }
            updatedCacheList.push(item);
        }

        // Save the updated master memory list
        mailController.fullMailCacheList = updatedCacheList;

        // 3. Instantly recalculate sidebar badge counts using clean cache
        mailController.recalculateFolderStats();

        // 4. Instantly re-filter and update active list and preview panes on screen
        mailController.filterEmailsByActiveFolder();
    }

    function handleStarToggle() {
        var activeItem = mailController.selectedMail;
        if (!activeItem) return;

        var folderArg = getMaildirFolder(activeItem.folder);

        var isCurrentlyStarred = false;
        var flags = activeItem.flags || [];
        for (var i = 0; i < flags.length; i++) {
            if (flags[i].toLowerCase() === "flagged") {
                isCurrentlyStarred = true;
                break;
            }
        }

        // 1. Generate the unique compound signature of the email we are star toggling
        var activeSender = activeItem.from ? (activeItem.from.addr || activeItem.from.name || "") : (activeItem.sender || "");
        var activeSubject = activeItem.subject || "";
        var activeDate = activeItem.date || "";

        if (isCurrentlyStarred) {
            console.log("[Quickshell Star Engine] Queueing flag removal...");
            writeToQueue("UNSTAR", activeItem.id.toString(), folderArg, "");
        } else {
            console.log("[Quickshell Star Engine] Queueing flag addition...");
            writeToQueue("STAR", activeItem.id.toString(), folderArg, "");
        }

        // 2. Cascade UI Memory Star Toggle: Search through all categories in cache and update flags array
        var cacheList = mailController.fullMailCacheList;
        for (var idx = 0; idx < cacheList.length; idx++) {
            var item = cacheList[idx];
            var itemSender = item.from ? (item.from.addr || item.from.name || "") : (item.sender || "");
            if ((item.subject || "") === activeSubject && (item.date || "") === activeDate && itemSender === activeSender) {
                var fList = item.flags || [];
                var fIdx = -1;
                for (var j = 0; j < fList.length; j++) {
                    if (fList[j].toLowerCase() === "flagged") {
                        fIdx = j;
                        break;
                    }
                }

                if (isCurrentlyStarred && fIdx !== -1) {
                    fList.splice(fIdx, 1);
                } else if (!isCurrentlyStarred && fIdx === -1) {
                    fList.push("flagged");
                }
                item.flags = fList;
            }
        }

        // 3. Force a full, instant layout refresh
        mailController.filterEmailsByActiveFolder();
    }

    function handleReadToggle(targetItem, forceRead) {
        var activeItem = targetItem ? targetItem : mailController.selectedMail;
        if (!activeItem) return;

        var folderArg = getMaildirFolder(activeItem.folder);

        var isCurrentlyRead = false;
        var flags = activeItem.flags || [];
        for (var i = 0; i < flags.length; i++) {
            if (flags[i].toLowerCase() === "seen") {
                isCurrentlyRead = true;
                break;
            }
        }

        var shouldMarkRead = forceRead !== undefined ? forceRead : !isCurrentlyRead;
        if (shouldMarkRead === isCurrentlyRead) return;

        if (shouldMarkRead) {
            console.log("[Quickshell Read Engine] Queueing read mark...");
            writeToQueue("READ", activeItem.id.toString(), folderArg, "");
        } else {
            console.log("[Quickshell Read Engine] Queueing unread mark...");
            writeToQueue("UNREAD", activeItem.id.toString(), folderArg, "");
        }

        var activeSender = activeItem.from ? (activeItem.from.addr || activeItem.from.name || "") : (activeItem.sender || "");
        var activeSubject = activeItem.subject || "";
        var activeDate = activeItem.date || "";

        // Cascade Flag update in Memory
        var cacheList = mailController.fullMailCacheList;
        for (var idx = 0; idx < cacheList.length; idx++) {
            var item = cacheList[idx];
            var itemSender = item.from ? (item.from.addr || item.from.name || "") : (item.sender || "");
            if ((item.subject || "") === activeSubject && (item.date || "") === activeDate && itemSender === activeSender) {
                var fList = item.flags || [];
                var fIdx = -1;
                for (var j = 0; j < fList.length; j++) {
                    if (fList[j].toLowerCase() === "seen") {
                        fIdx = j;
                        break;
                    }
                }

                if (shouldMarkRead && fIdx === -1) {
                    fList.push("seen");
                } else if (!shouldMarkRead && fIdx !== -1) {
                    fList.splice(fIdx, 1);
                }
                item.flags = fList;
            }
        }

        mailController.recalculateFolderStats();
        mailController.filterEmailsByActiveFolder();
    }

    function initiateEmailReply() {
        var activeItem = mailController.selectedMail;
        if (!activeItem) return;

        var replyTo = activeItem.from ? (activeItem.from.addr || activeItem.from.name) : "";
        var replySubject = activeItem.subject.startsWith("Re:") ? activeItem.subject : "Re: " + activeItem.subject;

        var conversationLog = "\n\n----------------------------------------\n" +
        "From: " + replyTo + "\n" +
        "Subject: " + activeItem.subject + "\n\n" +
        mailController.activeMailBody;

        mailController.isComposing = true;
        composeWindowOverlay.prepopulateForm(replyTo, replySubject, conversationLog);
    }

    function handleOutboundDelivery(toAddress, subjectLine, bodyContent) {
        if (!toAddress || toAddress.trim() === "") return;

        console.log("[Quickshell SMTP Engine] Queueing outbound mail transaction...");
        writeToQueue("SEND", toAddress.trim(), subjectLine.trim(), bodyContent);

        composeWindowOverlay.visible = false;
        mailController.isComposing = false;
    }

    Keys.onPressed: (event) => {
        if (mailController.isComposing || contactModalOverlay.visible || helpModalOverlay.visible) return;

        var isAltPressed = (event.modifiers === Qt.AltModifier) || (event.modifiers & Qt.AltModifier) !== 0;

        if (isAltPressed) {
            if (event.key === Qt.Key_Up) {
                mailController.cycleFolder(false);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                mailController.cycleFolder(true);
                event.accepted = true;
            }
        }
        else {
            if (event.key === Qt.Key_Up) {
                mailController.cycleEmail(false);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                mailController.cycleEmail(true);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                rootWindow.initiateEmailReply();
                event.accepted = true;
            } else if (event.key === Qt.Key_D || event.key === Qt.Key_Delete) {
                rootWindow.handleDeletion();
                event.accepted = true;
            } else if (event.key === Qt.Key_N) {
                mailController.isComposing = true;
                composeWindowOverlay.prepopulateForm("", "", "");
                event.accepted = true;
            } else if (event.key === Qt.Key_S) {
                rootWindow.handleStarToggle();
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                rootWindow.handleReadToggle();
                event.accepted = true;
            } else if (event.text === "?") {
                helpModalOverlay.visible = true;
                event.accepted = true;
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: rootWindow.windowBgColor
        border.color: rootWindow.outerBorderColor
        border.width: rootWindow.outerBorderThickness
        radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10

        Row {
            anchors.fill: parent

            SidebarView {
                width: rootWindow.sidebarColumnWidth
                height: parent.height
                folderListModel: mailController.folderList
                activeFolderIndex: mailController.currentFolderIndex
                countsDictionary: mailController.folderCountMap
            }

            EmailListView {
                id: mailListView
                width: rootWindow.listingColumnWidth
                height: parent.height
                mailItems: mailController.filteredMails
                activeMailIndex: mailController.currentMailIndex
                focus: true // Enabled active focus by default at startup

                onSearchQueryChanged: {
                    mailController.searchString = searchQuery;
                }
                onSearchCaseSensitiveChanged: {
                    mailController.searchCaseSensitive = searchCaseSensitive;
                }

                onStarToggled: (index) => {
                    mailController.currentMailIndex = index;
                    mailController.selectedMail = mailController.filteredMails[index];
                    rootWindow.handleStarToggle();
                }

                onReadToggled: (index) => {
                    mailController.currentMailIndex = index;
                    mailController.selectedMail = mailController.filteredMails[index];
                    rootWindow.handleReadToggle();
                }
            }

            EmailPreview {
                width: rootWindow.previewColumnWidth
                height: parent.height
                activeMailObject: mailController.selectedMail
                activeMailBodyText: mailController.activeMailBody
                focus: false

                onContactRequested: (email) => {
                    contactModalOverlay.openContactPrompt(email);
                }
            }
        }

        ComposeModal {
            id: composeWindowOverlay
            anchors.fill: parent
            visible: mailController.isComposing

            onEscapeDismissRequested: {
                mailController.isComposing = false;
                mailListView.forceActiveFocus(); // Restore list focus on modal dismiss
            }

            onDispatchMailRequested: (to, subject, body) => {
                rootWindow.handleOutboundDelivery(to, subject, body);
                mailListView.forceActiveFocus(); // Restore list focus on mail dispatch
            }
        }

        // ============================================================================
        // CONTACTS DIALOG OVERLAY modal box
        // ============================================================================
        Rectangle {
            id: contactModalOverlay
            anchors.fill: parent
            color: "#F40F0F0F"
            visible: false

            property string targetEmail: ""

            function openContactPrompt(email) {
                targetEmail = email;
                nicknameInput.text = "";
                visible = true;
                nicknameInput.forceActiveFocus();
            }

            MouseArea { anchors.fill: parent }

            Rectangle {
                width: 400
                height: 220
                color: rootWindow.windowBgColor
                border.color: rootWindow.innerBorderColor
                border.width: rootWindow.innerCardActiveThickness
                radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10
                anchors.centerIn: parent

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    Text {
                        text: "ADD TO CONTACTS"
                        font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"
                        font.pixelSize: (typeof theme !== 'undefined') ? theme.globalFontSize : 20
                        font.bold: true
                        color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"
                    }

                    Text {
                        text: "Email: " + contactModalOverlay.targetEmail
                        font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"
                        font.pixelSize: (typeof theme !== 'undefined') ? theme.globalFontSize - 4 : 16
                        color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Rectangle {
                        width: parent.width
                        height: 40
                        color: (typeof theme !== 'undefined') ? theme.base00 : "#121212"
                        border.color: nicknameInput.activeFocus ? rootWindow.innerBorderColor : ((typeof theme !== 'undefined') ? theme.base01 : "#0f0f0f")
                        border.width: 1
                        radius: 6

                        TextInput {
                            id: nicknameInput
                            anchors.fill: parent
                            anchors.margins: 8
                            font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"
                            font.pixelSize: (typeof theme !== 'undefined') ? theme.globalFontSize - 2 : 18
                            color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"

                            Text {
                                text: "Enter nickname..."
                                color: (typeof theme !== 'undefined') ? theme.base0B : "#545454"
                                visible: parent.text === ""
                                font.pixelSize: parent.font.pixelSize
                                font.family: parent.font.family
                            }

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    rootWindow.writeToQueue("CONTACT", nicknameInput.text, contactModalOverlay.targetEmail, "");
                                    contactModalOverlay.visible = false;
                                    mailListView.forceActiveFocus(); // Restore list focus on save
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    Text {
                        text: "Press [Enter] to Save  •  [ESC] to Cancel"
                        font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"
                        font.pixelSize: (typeof theme !== 'undefined') ? theme.globalFontSize - 6 : 14
                        color: (typeof theme !== 'undefined') ? theme.base0B : "#545454"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                enabled: contactModalOverlay.visible
                onActivated: {
                    contactModalOverlay.visible = false;
                    mailListView.forceActiveFocus(); // Restore list focus on cancel
                }
            }
        }

        // ============================================================================
        // KEYBOARD SHORTCUTS CHEATSHEET OVERLAY modal box
        // ============================================================================
        Rectangle {
            id: helpModalOverlay
            anchors.fill: parent
            color: "#F40F0F0F"
            visible: false

            MouseArea { anchors.fill: parent }

            Rectangle {
                width: 500
                height: 400
                color: rootWindow.windowBgColor
                border.color: rootWindow.innerBorderColor
                border.width: rootWindow.innerCardActiveThickness
                radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10
                anchors.centerIn: parent

                Column {
                    anchors.fill: parent
                    anchors.margins: 25
                    spacing: 15

                    Text {
                        text: "KEYBOARD SHORTCUTS CHEATSHEET"
                        font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"
                        font.pixelSize: (typeof theme !== 'undefined') ? theme.globalFontSize : 20
                        font.bold: true
                        color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: (typeof theme !== 'undefined') ? theme.base01 : "#3c3836"
                    }

                    Grid {
                        columns: 2
                        columnSpacing: 30
                        rowSpacing: 10
                        width: parent.width

                        Text { text: "Alt + ↑ / ↓"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Cycle Folders / Mailboxes"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "↑ / ↓"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Cycle Emails in List"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "Enter / Return"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Reply to Selected Email"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "N"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Compose New Email"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

                        Text { text: "D / Delete"; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }
                        Text { text: "Delete Email (Cascade)"; color: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"; font.pixelSize: 15; font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans" }

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

                    Text {
                        text: "Press [ESC] or [?] to Dismiss Cheatsheet"
                        font.family: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"
                        font.pixelSize: 14
                        color: (typeof theme !== 'undefined') ? theme.base0B : "#545454"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                enabled: helpModalOverlay.visible
                onActivated: {
                    helpModalOverlay.visible = false;
                    mailListView.forceActiveFocus(); // Restore list focus on dismiss
                }
            }

            Shortcut {
                sequence: "Shift+?"
                enabled: helpModalOverlay.visible
                onActivated: {
                    helpModalOverlay.visible = false;
                    mailListView.forceActiveFocus(); // Restore list focus on dismiss
                }
            }
        }
    }
}
