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

    function sortFolderWithPriority(mailArray) {
        if (!mailArray || mailArray.length === 0) return [];

        return mailArray.sort(function(a, b) {
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

            if (timeA !== timeB) {
                return timeB - timeA;
            }

            var idA = parseInt(a.id || (envA ? envA.id : 0)) || 0;
            var idB = parseInt(b.id || (envB ? envB.id : 0)) || 0;
            return idB - idA;
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
        var seenIds = {};

        for (var i = 0; i < list.length; i++) {
            var item = list[i];
            if (!item) continue;

            var env = item.envelope ? item.envelope : item;
            var msgId = (item.id !== undefined && item.id !== null) ? String(item.id) : ((env && env.id !== undefined) ? String(env.id) : "");
            var folderStr = item.folder ? String(item.folder).toLowerCase() : ((env && env.folder) ? String(env.folder).toLowerCase() : "");
            folderStr = folderStr.trim();

            if (folderStr === "inbox") ib.push(item);
            else if (folderStr === "drafts") dr.push(item);
            else if (folderStr === "trash") tr.push(item);
            else if (folderStr === "sent") sn.push(item);
            else if (folderStr === "spam") sp.push(item);
            else if (folderStr === "starred") st.push(item);
            else if (folderStr === "important") im.push(item);

            if (msgId !== "" && !seenIds[msgId]) {
                seenIds[msgId] = true;
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
    // FIXED: Broadened name checking constraints accept multiple text string variants cleanly during rapid folder switches
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
            var mailEnv = mailItem.envelope ? mailItem.envelope : mailItem;
            var mailId = mailItem.id ? String(mailItem.id) : (mailEnv.id ? String(mailEnv.id) : "");

            if (!deleteMap[mailId] && mailId !== "") {
                targetSource.push(mailItem);
            }
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

    Connections {
        target: processes
        function onMailListUpdated() { root.rebuildFolderCaches(); }
    }

    Connections {
        target: controller
        function onEmailsChanged() { root.rebuildFolderCaches(); }
        function onCurrentFolderChanged() {
            emailList.currentIndex = 0;
            controller.currentListIndex = 0;
            controller.statusMessage = "Viewing " + controller.currentFolder;
            emailList.forceActiveFocus();
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
                text: controller.searchQuery
                activeFocusOnTab: false

                onTextChanged: {
                    controller.searchQuery = text;
                    emailList.currentIndex = 0;
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
                model: root.getFilteredEmails()
                spacing: 8
                activeFocusOnTab: false
                clip: true
                reuseItems: false
                cacheBuffer: 0
                highlightFollowsCurrentItem: true
                currentIndex: controller.currentListIndex

                Keys.onUpPressed: (event) => { event.accepted = false; }
                Keys.onDownPressed: (event) => { event.accepted = false; }
                Keys.onPressed: (event) => { if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) { deleteCurrentMessage(); event.accepted = true; } }

                delegate: Rectangle {
                    width: emailList.width
                    height: stylixTheme ? (stylixTheme.defaultCardHeight * 0.75) : (controller.defaultCardHeight * 0.75)
                    radius: stylixTheme ? (stylixTheme.defaultCardRadius - 2) : (controller.defaultCardRadius - 2)
                    color: controller.currentListIndex === index ? (stylixTheme ? stylixTheme.base02 : "#1a1a1a") : "transparent"
                    border.width: (controller.currentListIndex === index) ? (stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth) : 0
                    border.color: stylixTheme ? stylixTheme.base05 : "#FABD2F"

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 4
                        Text {
                            width: parent.width - 24
                            text: modelData.from ? (modelData.from.name || modelData.from.addr || modelData.from) : (modelData.envelope && modelData.envelope.from ? (modelData.envelope.from.name || modelData.envelope.from.addr) : "")
                            color: {
                                var e = modelData.envelope ? modelData.envelope : modelData;
                                var isSeen = (modelData.seen !== undefined) ? modelData.seen : ((e && e.seen !== undefined) ? e.seen : true);
                                return (!isSeen) ? (stylixTheme ? stylixTheme.base0B : "#a6e22e") : (stylixTheme ? stylixTheme.base08 : "#ff6666");
                            }
                            font.bold: {
                                var e = modelData.envelope ? modelData.envelope : modelData;
                                var isSeen = (modelData.seen !== undefined) ? modelData.seen : ((e && e.seen !== undefined) ? e.seen : true);
                                return !isSeen;
                            }
                            font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily
                            font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize + 2) : (controller.globalFontSize + 2)
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width - 24
                            text: modelData.subject !== undefined ? modelData.subject : (modelData.envelope && modelData.envelope.subject !== undefined ? modelData.envelope.subject : "(No Subject)")
                            color: stylixTheme ? stylixTheme.base05 : "white"
                            font.bold: {
                                var e = modelData.envelope ? modelData.envelope : modelData;
                                var isSeen = (modelData.seen !== undefined) ? modelData.seen : ((e && e.seen !== undefined) ? e.seen : true);
                                return !isSeen;
                            }
                            font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily
                            font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize) : (controller.globalFontSize)
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
