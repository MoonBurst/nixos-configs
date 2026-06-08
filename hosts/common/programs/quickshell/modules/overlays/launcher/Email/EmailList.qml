import QtQuick
import Quickshell

Rectangle {
    id: root

    required property QtObject controller
    required property QtObject processes

    property var stylixTheme
    property alias innerListView: emailList

    property color searchActiveColor: stylixTheme ? stylixTheme.base0A : "#FABD2F"
    property color searchInactiveColor: stylixTheme ? stylixTheme.base02 : "#444455"
    property color searchBgColor: stylixTheme ? stylixTheme.base00 : "#111115"
    property color textHeaderColor: stylixTheme ? stylixTheme.base07 : "#aaaaaa"
    property color buttonActiveColor: stylixTheme ? stylixTheme.base02 : "#1a1a24"
    property color mainPanelBgColor: stylixTheme ? stylixTheme.base01 : "#1a1a24"

    color: root.mainPanelBgColor
    border.color: root.searchInactiveColor
    border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth
    radius: stylixTheme ? stylixTheme.defaultCardRadius : controller.defaultCardRadius

    property var locallyDeletedIds: []

    // LOOP PREVENTION CACHE LAYER
    property var visibleEmailsList: []
    property string _lastLoadedFolder: ""
    property bool _blockExternalResets: false

    property var _cachedInbox: []
    property var _cachedAll: []
    property var _cachedDrafts: []
    property var _cachedTrash: []
    property var _cachedSent: []
    property var _cachedSpam: []
    property var _cachedStarred: []
    property var _cachedImportant: []

    function forceSearchFocus() {
        searchField.focus = true;
        searchField.forceActiveFocus();
        searchField.selectAll();
    }

    function extractMessageId(item) {
        if (!item || item === undefined) return "";

        // Extract the envelope object block wrapper safely
        var env = item.envelope ? item.envelope : item;
        if (!env || env === undefined) return "";

        // FIXED: Explicitly prioritize the exact ID properties written by your syncMailHelper script!
        if (item.id !== undefined && item.id !== null) {
            return (typeof item.id === "object") ? String(item.id.id || "").trim() : String(item.id).trim();
        }

        if (env.id !== undefined && env.id !== null) {
            return (typeof env.id === "object") ? String(env.id.id || "").trim() : String(env.id).trim();
        }

        // Standard string header fallbacks as a secondary backup tracking lane
        if (item.messageId && String(item.messageId).trim().length > 0) return String(item.messageId).trim();
        if (env.messageId && String(env.messageId).trim().length > 0) return String(env.messageId).trim();

        return "";
    }



    function sortFolderWithPriority(mailArray) {
        if (!mailArray || mailArray.length === 0) return [];

        // Isolate reference lane mutation issues via fresh allocation
        var pureCopy = mailArray.slice();

        return pureCopy.sort(function(a, b) {
            var envA = a.envelope ? a.envelope : a;
            var envB = b.envelope ? b.envelope : b;
            var aSeen = (a.seen !== undefined) ? a.seen : ((envA && envA.seen !== undefined) ? envA.seen : true);
            var bSeen = (b.seen !== undefined) ? b.seen : ((envB && envB.seen !== undefined) ? envB.seen : true);

            var aUnread = !aSeen;
            var bUnread = !bSeen;
            if (aUnread && !bUnread) return -1;
            if (!aUnread && bUnread) return 1;

            var dateStrA = a.date || (envA ? envA.date : "");
            var dateStrB = b.date || (envB ? envB.date : "");
            var timeA = dateStrA ? Date.parse(dateStrA) : 0;
            var timeB = dateStrB ? Date.parse(dateStrB) : 0;

            if (isNaN(timeA)) timeA = 0;
            if (isNaN(timeB)) timeB = 0;
            if (timeA !== timeB) return timeB - timeA;

            return extractMessageId(b).localeCompare(extractMessageId(a));
        });
    }

    function rebuildFolderCaches() {
        var list = controller.emails;
        if (!list || !Array.isArray(list)) {
            _cachedInbox = []; _cachedAll = []; _cachedDrafts = []; _cachedTrash = [];
            _cachedSent = []; _cachedSpam = []; _cachedStarred = []; _cachedImportant = [];
            return;
        }

        var ib = []; var al = []; var dr = []; var tr = [];
        var sn = []; var sp = []; var st = []; var im = [];

        // 🔍 DUPLICATION GUARD DICTIONARIES (Per-Folder Tracker Blocks)
        var seenInboxIds = {};
        var seenDraftsIds = {};
        var seenTrashIds = {};
        var seenSentIds = {};
        var seenSpamIds = {};
        var seenStarredIds = {};
        var seenImportantIds = {};
        var seenAllMailIds = {};

        var myCleanEmail = controller.userEmailAddress ? String(controller.userEmailAddress).trim().toLowerCase() : "";

        for (var i = 0; i < list.length; i++) {
            var item = list[i];
            if (!item) continue;

            var msgId = extractMessageId(item);
            var env = item.envelope ? item.envelope : item;
            var folderStr = item.folder ? String(item.folder).toLowerCase() : ((env && env.folder) ? String(env.folder).toLowerCase() : "");
            folderStr = folderStr.trim();

            // Hardware Filename flag check for starred items
            var isStarredFlag = false;
            var rawFilePath = item.filename || item.path || (env ? (env.filename || env.path) : "");
            var fileNameStr = String(rawFilePath).trim();
            if (fileNameStr !== "" && fileNameStr !== "undefined" && fileNameStr.indexOf(":2,") !== -1) {
                var flagParts = fileNameStr.split(":2,");
                if (flagParts[flagParts.length - 1].indexOf("F") !== -1) isStarredFlag = true;
            }
            if (item.flagged === true || env.flagged === true || item.starred === true || env.starred === true) {
                isStarredFlag = true;
            }

            // Important item checks
            var isImportantFlag = false;
            var itemDump = JSON.stringify(item).toLowerCase();
            if (itemDump.indexOf("important") !== -1 || item.important === true || env.important === true) {
                isImportantFlag = true;
            }

            // Self-Sent email routing logic
            var isSelfSent = false;
            if (folderStr === "sent" && myCleanEmail !== "") {
                var fromObj = item.from ? item.from : (env && env.from ? env.from : {});
                var fromAddr = String(fromObj.addr || fromObj.name || fromObj).toLowerCase();
                if (fromAddr.indexOf(myCleanEmail) !== -1) isSelfSent = true;
            }

            // =========================================================================
            // 🛡️ ENVELOPE DUPLICATION INTERCEPTION FILTERS
            // =========================================================================
            if (folderStr === "inbox" || isSelfSent) {
                if (!seenInboxIds[msgId]) {
                    seenInboxIds[msgId] = true;
                    ib.push(item);
                }
            }
            if (folderStr === "drafts") {
                if (!seenDraftsIds[msgId]) {
                    seenDraftsIds[msgId] = true;
                    dr.push(item);
                }
            }
            if (folderStr === "trash") {
                if (!seenTrashIds[msgId]) {
                    seenTrashIds[msgId] = true;
                    tr.push(item);
                }
            }
            if (folderStr === "sent") {
                if (!seenSentIds[msgId]) {
                    seenSentIds[msgId] = true;
                    sn.push(item);
                }
            }
            if (folderStr === "spam") {
                if (!seenSpamIds[msgId]) {
                    seenSpamIds[msgId] = true;
                    sp.push(item);
                }
            }
            if (folderStr === "starred" || isStarredFlag) {
                if (!seenStarredIds[msgId]) {
                    seenStarredIds[msgId] = true;
                    st.push(item);
                }
            }
            if (folderStr === "important" || isImportantFlag) {
                if (!seenImportantIds[msgId]) {
                    seenImportantIds[msgId] = true;
                    im.push(item);
                }
            }

            // Populate the All Mail global repository list cleanly without duplicates
            if (msgId !== "" && !seenAllMailIds[msgId] && folderStr !== "trash") {
                seenAllMailIds[msgId] = true;
                al.push(item);
            }
        }

        _cachedInbox = sortFolderWithPriority(ib);
        _cachedAll = sortFolderWithPriority(al);
        _cachedDrafts = sortFolderWithPriority(dr);
        _cachedTrash = sortFolderWithPriority(tr);
        _cachedSent = sortFolderWithPriority(sn);
        _cachedSpam = sortFolderWithPriority(sp);
        _cachedStarred = sortFolderWithPriority(st);
        _cachedImportant = sortFolderWithPriority(im);
    }


    function getFilteredEmails() {
        var activeTarget = controller.currentFolder ? String(controller.currentFolder).toUpperCase().trim() : "INBOX";
        var rawSource = _cachedInbox;

        if (activeTarget === "ALL MAIL" || activeTarget === "ALL") rawSource = _cachedAll;
        else if (activeTarget === "DRAFTS") rawSource = _cachedDrafts;
        else if (activeTarget === "TRASH") rawSource = _cachedTrash;
        else if (activeTarget === "SENT MAIL" || activeTarget === "SENT") rawSource = _cachedSent;
        else if (activeTarget === "SPAM") rawSource = _cachedSpam;
        else if (activeTarget === "STARRED") rawSource = _cachedStarred;
        else if (activeTarget === "IMPORTANT") rawSource = _cachedImportant;

        var targetSource = [];
        var deleteMap = {};
        for (var d = 0; d < root.locallyDeletedIds.length; d++) {
            deleteMap[String(root.locallyDeletedIds[d])] = true;
        }

        for (var m = 0; m < rawSource.length; m++) {
            var mailItem = rawSource[m];
            var mailId = extractMessageId(mailItem);
            if (!deleteMap[mailId] && mailId !== "") targetSource.push(mailItem);
        }

        var queryText = controller.searchQuery.trim();
        if (queryText === "") return targetSource;

        var tempMatches = [];
        var query = queryText.toLowerCase();
        for (var k = 0; k < targetSource.length; k++) {
            var rawMail = targetSource[k];
            var cleanEnv = rawMail.envelope ? rawMail.envelope : rawMail;
            var subText = String(rawMail.subject || cleanEnv.subject || "").toLowerCase();
            var fromObj = rawMail.from ? rawMail.from : (cleanEnv.from || {});
            var nameText = String(fromObj.name || "").toLowerCase();
            var addrText = String(fromObj.addr || "").toLowerCase();

            if (subText.indexOf(query) !== -1 || nameText.indexOf(query) !== -1 || addrText.indexOf(query) !== -1) {
                tempMatches.push(rawMail);
            }
        }
        return tempMatches;
    }

    function updateVisibleEmails() {
        if (root._blockExternalResets) return;
        root.visibleEmailsList = root.getFilteredEmails();
    }

    Connections {
        target: processes
        function onMailListUpdated() {
            root.rebuildFolderCaches();
            root.updateVisibleEmails();
        }
    }

    Connections {
        target: controller
        function onEmailsChanged() {
            root.rebuildFolderCaches();
            root.updateVisibleEmails();
        }
        function onSearchQueryChanged() {
            root.updateVisibleEmails();
            emailList.currentIndex = 0;
        }
        function onCurrentFolderChanged() {
            var targetFolder = controller.currentFolder ? String(controller.currentFolder).toUpperCase().trim() : "INBOX";
            if (root._lastLoadedFolder === targetFolder) return;

            root._lastLoadedFolder = targetFolder;
            root.updateVisibleEmails();

            emailList.currentIndex = 0;
            controller.currentListIndex = 0;
            controller.statusMessage = "Viewing " + controller.currentFolder;
            delayedSelectionTimer.restart();
        }
    }

    Timer {
        id: delayedSelectionTimer
        interval: 50
        repeat: false
        onTriggered: {
            var targetList = root.visibleEmailsList;
            if (targetList && targetList.length > 0) {
                var activeIdx = (emailList.currentIndex >= 0 && emailList.currentIndex < targetList.length) ? emailList.currentIndex : 0;
                var currentMail = targetList[activeIdx];
                if (currentMail) {
                    var targetId = root.extractMessageId(currentMail);
                    if (targetId && targetId !== "" && targetId !== "undefined") {
                        controller.selectedId = targetId;
                        controller.messageBody = "Loading message...";
                        var targetEnv = currentMail.envelope ? currentMail.envelope : currentMail;
                        var fromObj = currentMail.from ? currentMail.from : targetEnv.from;
                        controller.currentReplyTo = fromObj ? (fromObj.addr || fromObj || "") : "";
                        controller.currentSubject = currentMail.subject ? currentMail.subject : (targetEnv.subject ? targetEnv.subject : "");
                        processes.loadMessage(targetId);
                    }
                }
            } else {
                controller.messageBody = "📄 Select an email row item from the list to display its message contents here.";
            }
            emailList.forceActiveFocus();
        }
    }

    Shortcut {
        sequence: "Alt+Up"
        enabled: emailList.activeFocus || searchField.activeFocus || root.activeFocus
        onActivated: {
            var list = ["INBOX", "ALL MAIL", "DRAFTS", "SENT MAIL", "SPAM", "STARRED", "IMPORTANT", "TRASH"];
            var cur = controller.currentFolder ? String(controller.currentFolder).toUpperCase().trim() : "INBOX";
            var idx = list.indexOf(cur);

            // FIXED: If we hit the beginning of the list, wrap safely around to the last index item (TRASH)
            controller.currentFolder = (idx > 0) ? list[idx - 1] : list[list.length - 1];
        }
    }

    Shortcut {
        sequence: "Alt+Down"
        enabled: emailList.activeFocus || searchField.activeFocus || root.activeFocus
        onActivated: {
            var list = ["INBOX", "ALL MAIL", "DRAFTS", "SENT MAIL", "SPAM", "STARRED", "IMPORTANT", "TRASH"];
            var cur = controller.currentFolder ? String(controller.currentFolder).toUpperCase().trim() : "INBOX";
            var idx = list.indexOf(cur);

            // FIXED: If we hit the end of the list (TRASH), wrap safely back around to the first item (INBOX)
            controller.currentFolder = (idx < list.length - 1) ? list[idx + 1] : list[0];
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: stylixTheme ? (stylixTheme.globalPadding / 2) : (controller.globalPadding / 2)
        spacing: stylixTheme ? (stylixTheme.globalPadding / 2) : (controller.globalPadding / 2)

        Text {
            id: statusText
            text: controller.statusMessage
            color: root.textHeaderColor
            font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily
            font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize + 4) : (controller.globalFontSize + 4)
        }

        Rectangle {
            width: parent.width; height: 40; radius: 4; color: root.searchBgColor
            border.color: searchField.activeFocus ? root.searchActiveColor : root.searchInactiveColor
            border.width: 1

            TextInput {
                id: searchField
                width: parent.width - 86; height: parent.height
                anchors.left: parent.left; anchors.leftMargin: 8; color: "white"
                font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily
                font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize) : (controller.globalFontSize)
                verticalAlignment: TextInput.AlignVCenter
                activeFocusOnTab: false

                Component.onCompleted: {
                    text = controller.searchQuery;
                }

                // 🔍 FIXED: Intercept hotkey modifiers to prevent typing corruption!
                Keys.onPressed: (event) => {
                    if (event.modifiers & Qt.AltModifier || event.key === Qt.Key_Escape) {
                        event.accepted = false; // Pass hotkeys right past the input box
                        return;
                    }
                    if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                        emailList.forceActiveFocus(); // Shunt keyboard arrow control back to list items
                        event.accepted = false;
                        return;
                    }
                }

                Connections {
                    target: controller
                    function onSearchQueryChanged() {
                        if (searchField.text !== controller.searchQuery) {
                            searchField.text = controller.searchQuery;
                        }
                    }
                }

                onTextChanged: {
                    if (controller.searchQuery !== text) {
                        controller.searchQuery = text;
                    }
                }

                Text {
                    text: "🔍 Search subject or sender..."
                    color: "#555565"
                    visible: searchField.text === ""
                    anchors.fill: parent
                    font.family: searchField.font.family
                    font.pixelSize: searchField.font.pixelSize
                    verticalAlignment: Text.AlignVCenter
                }
            }

        }

        Rectangle {
            width: parent.width
            height: parent.height - statusText.height - 66
            color: root.mainPanelBgColor
            clip: true

            ListView {
                id: emailList
                anchors.fill: parent
                model: root.visibleEmailsList
                spacing: 8
                activeFocusOnTab: false
                clip: true
                reuseItems: false
                cacheBuffer: 0
                highlightFollowsCurrentItem: true
                currentIndex: controller.currentListIndex

                onCurrentIndexChanged: {
                    if (model !== undefined && model !== null && currentIndex >= 0 && currentIndex < model.length) {
                        var targetMail = model[currentIndex];
                        if (targetMail) {
                            var targetId = root.extractMessageId(targetMail);

                            console.log("👉 [DEBUG UI] Clicked row visual index: " + currentIndex);
                            console.log("👉 [DEBUG UI] Extracted raw mail id: " + targetId);
                            console.log("👉 [DEBUG UI] Mail Subject Text: " + targetMail.subject);

                            if (targetId && targetId !== "" && targetId !== "undefined") {
                                root._blockExternalResets = true;

                                controller.currentListIndex = currentIndex;
                                controller.selectedId = targetId;
                                controller.messageBody = "Loading message...";

                                var targetEnv = targetMail.envelope ? targetMail.envelope : targetMail;
                                var fromObj = targetMail.from ? targetMail.from : targetEnv.from;
                                controller.currentReplyTo = fromObj ? (fromObj.addr || fromObj || "") : "";
                                controller.currentSubject = targetMail.subject ? targetMail.subject : (targetEnv.subject ? targetEnv.subject : "");

                                processes.loadMessage(targetId);

                                Qt.callLater(function() {
                                    root._blockExternalResets = false;
                                });
                            }
                        }
                    }
                }

                onModelChanged: {}

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Up) {
                        if (emailList.currentIndex > 0) {
                            emailList.currentIndex--;
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        if (emailList.currentIndex < emailList.count - 1) {
                            emailList.currentIndex++;
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                        if (emailList.currentItem) emailList.currentItem.triggerDelete();
                        event.accepted = true;
                    } else {
                        event.accepted = false;
                    }
                }

                delegate: Rectangle {
                    id: delegateRow
                    width: emailList.width
                    height: stylixTheme ? (stylixTheme.defaultCardHeight * 0.75) : (controller.defaultCardHeight * 0.75)
                    radius: stylixTheme ? (stylixTheme.defaultCardRadius - 2) : (controller.defaultCardRadius - 2)
                    color: emailList.currentIndex === index ? (stylixTheme ? stylixTheme.base02 : "#1a1a1a") : "transparent"
                    border.width: (emailList.currentIndex === index) ? (stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth) : 0
                    border.color: stylixTheme ? stylixTheme.base05 : "#FABD2F"

                    property var env: modelData.envelope ? modelData.envelope : modelData
                    property bool isUnread: !((modelData.seen !== undefined) ? modelData.seen : ((env && env.seen !== undefined) ? env.seen : true))
                    property string msgId: root.extractMessageId(modelData)

                    function triggerClick() {
                        var cleanId = msgId.trim();
                        if (cleanId) {
                            controller.selectedId = cleanId;
                            controller.messageBody = "Loading message...";
                            var fromObj = modelData.from ? modelData.from : env.from;
                            controller.currentReplyTo = fromObj ? (fromObj.addr || fromObj || "") : "";
                            controller.currentSubject = modelData.subject ? modelData.subject : (env.subject ? env.subject : "");
                            processes.loadMessage(cleanId);
                        }
                    }

                    function triggerDelete() {
                        var cleanId = msgId.trim();
                        if (cleanId) processes.deleteMessage(cleanId);
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // FIXED: Lock our indices visually
                            emailList.currentIndex = index;
                            controller.currentListIndex = index;

                            // FIXED: Use the delegate row's cached local string property directly!
                            var cleanId = delegateRow.msgId.trim();
                            if (cleanId && cleanId !== "" && cleanId !== "undefined") {
                                console.log("👉 [DEBUG CLICK] Clicked row visual index: " + index);
                                console.log("👉 [DEBUG CLICK] Bound row delegate string ID: " + cleanId);

                                controller.selectedId = cleanId;
                                controller.messageBody = "Loading message...";

                                var fromObj = modelData.from ? modelData.from : delegateRow.env.from;
                                controller.currentReplyTo = fromObj ? (fromObj.addr || fromObj || "") : "";
                                controller.currentSubject = modelData.subject ? modelData.subject : (delegateRow.env.subject || "");

                                // Call process loading with our safe ID string directly
                                processes.loadMessage(cleanId);
                            }
                            emailList.forceActiveFocus();
                        }
                    }


                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 4
                        Text {
                            width: parent.width - 24
                            text: modelData.from ? (modelData.from.name || modelData.from.addr || modelData.from) : (env && env.from ? (env.from.name || env.from.addr) : "")
                            color: isUnread ? (stylixTheme ? stylixTheme.base0B : "#a6e22e") : (stylixTheme ? stylixTheme.base08 : "#ff6666")
                            font.bold: isUnread
                            font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily
                            font.pixelSize: stylixTheme ? (stylixTheme.globalPadding + 2) : (controller.globalPadding + 2)
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width - 24
                            text: modelData.subject !== undefined ? modelData.subject : (env && env.subject !== undefined ? env.subject : "(No Subject)")
                            color: stylixTheme ? stylixTheme.base05 : "white"
                            font.bold: isUnread
                            font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily
                            font.pixelSize: stylixTheme ? (stylixTheme.globalPadding) : (controller.globalPadding)
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
