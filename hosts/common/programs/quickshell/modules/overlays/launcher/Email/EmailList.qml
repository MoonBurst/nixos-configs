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

    // PERFORMANCE FIXED: Background storage pointers prevent layout recalculation thrashing
    property var _cachedInbox: []
    property var _cachedAll: []
    property var _cachedDrafts: []
    property var _cachedTrash: []

    function forceSearchFocus() {
        searchField.forceActiveFocus();
    }

    // FAST TRACK: Rebuilds data maps ONLY when the raw database array explicitly drops changes
    function rebuildFolderCaches() {
        var list = controller.emails;
        if (!list) {
            _cachedInbox = []; _cachedAll = []; _cachedDrafts = []; _cachedTrash = [];
            return;
        }

        var ib = []; var al = []; var dr = []; var tr = [];

        for (var i = 0; i < list.length; i++) {
            var item = list[i];
            var env = item.envelope ? item.envelope : item;

            var subjectStr = item.subject ? String(item.subject).toUpperCase() : (env.subject ? String(env.subject).toUpperCase() : "");
            var flagsStr = env.flags ? String(env.flags).toUpperCase() : "";
            var folderStr = item.folder ? String(item.folder).toUpperCase() : "";

            var isSystemNoise = (flagsStr.indexOf("DRAFT") !== -1 || subjectStr.indexOf("DRAFT") !== -1 ||
            flagsStr.indexOf("TRASH") !== -1 || flagsStr.indexOf("DELETED") !== -1);
            var isInboxMail = (folderStr.indexOf("INBOX") !== -1 || flagsStr.indexOf("INBOX") !== -1);

            // Sort directly into the background buckets
            al.push(item);
            if (!isSystemNoise && (isInboxMail || flagsStr.indexOf("SEEN") === -1)) {
                ib.push(item);
            }
            if (flagsStr.indexOf("DRAFT") !== -1 || subjectStr.indexOf("DRAFT") !== -1) {
                dr.push(item);
            }
            if (flagsStr.indexOf("TRASH") !== -1 || flagsStr.indexOf("DELETED") !== -1) {
                tr.push(item);
            }
        }

        _cachedInbox = ib; _cachedAll = al; _cachedDrafts = dr; _cachedTrash = tr;
    }

    function getFilteredEmails() {
        var activeTarget = controller.currentFolder ? controller.currentFolder.toUpperCase() : "INBOX";
        var targetSource = _cachedInbox;

        if (activeTarget === "ALL MAIL") targetSource = _cachedAll;
        else if (activeTarget === "DRAFTS") targetSource = _cachedDrafts;
        else if (activeTarget === "TRASH") targetSource = _cachedTrash;

        if (controller.searchQuery.trim() === "") return targetSource;

        var tempMatches = [];
        if (controller.isRegexSearch) {
            try {
                var regex = new RegExp(controller.searchQuery, "i");
                for (var j = 0; j < targetSource.length; j++) {
                    var mail = targetSource[j];
                    var subEnv = mail.envelope ? mail.envelope : mail;
                    var subject = mail.subject ? String(mail.subject) : (subEnv.subject ? String(subEnv.subject) : "");
                    var fromName = mail.from ? (mail.from.name || "") : (subEnv.from && subEnv.from.name ? String(subEnv.from.name) : "");
                    var fromAddr = mail.from ? (mail.from.addr || "") : (subEnv.from && subEnv.from.addr ? String(subEnv.from.addr) : "");

                    if (regex.test(subject) || regex.test(fromName) || regex.test(fromAddr)) {
                        tempMatches.push(mail);
                    }
                }
            } catch (e) {
                return targetSource;
            }
        } else {
            var query = controller.searchQuery.toLowerCase();
            for (var k = 0; k < targetSource.length; k++) {
                var rawMail = targetSource[k];
                var cleanEnv = rawMail.envelope ? rawMail.envelope : rawMail;
                var subText = rawMail.subject ? String(rawMail.subject).toLowerCase() : (cleanEnv.subject ? String(cleanEnv.subject).toLowerCase() : "");
                var nameText = rawMail.from ? String(rawMail.from.name || "").toLowerCase() : (cleanEnv.from && cleanEnv.from.name ? String(cleanEnv.from.name).toLowerCase() : "");
                var addrText = rawMail.from ? String(rawMail.from.addr || "").toLowerCase() : (cleanEnv.from && cleanEnv.from.addr ? String(cleanEnv.from.addr).toLowerCase() : "");

                if (subText.indexOf(query) !== -1 || nameText.indexOf(query) !== -1 || addrText.indexOf(query) !== -1) {
                    tempMatches.push(rawMail);
                }
            }
        }
        return tempMatches;
    }

    Component.onCompleted: {
        rebuildFolderCaches();
        emailList.forceActiveFocus();
    }

    Connections {
        target: controller
        function onEmailsChanged() { rebuildFolderCaches(); }
        function onCurrentFolderChanged() {
            emailList.currentIndex = 0;
            controller.currentListIndex = 0;
            controller.statusMessage = "Loading " + controller.currentFolder + "...";
            processes.refreshMail();
        }
    }
    function openCurrentMessage() {
        var filtered = getFilteredEmails();
        var email = filtered[emailList.currentIndex];
        if (!email) return;

        var msgId = "";
        var env = email.envelope ? email.envelope : email;

        if (email.id !== undefined && email.id !== null) {
            msgId = (typeof email.id === "object") ? String(email.id.id || "") : String(email.id);
        } else if (env.id !== undefined && env.id !== null) {
            msgId = (typeof env.id === "object") ? String(env.id.id || "") : String(env.id);
        }

        msgId = msgId.trim();
        if (!msgId || msgId === "" || msgId === "undefined") return;

        controller.selectedId = msgId;
        controller.messageBody = "Loading message from local cache...";

        var fromObj = email.from ? email.from : env.from;
        controller.currentReplyTo = fromObj ? (fromObj.addr || fromObj || "") : "";
        controller.currentSubject = email.subject ? email.subject : (env.subject ? env.subject : "");

        if (controller.currentSubject.toLowerCase().indexOf("re:") !== 0) {
            controller.currentSubject = "Re: " + controller.currentSubject;
        }

        processes.loadMessage(msgId);
    }

    function deleteCurrentMessage() {
        var filtered = getFilteredEmails();
        var mail = filtered[emailList.currentIndex];
        if (!mail) return;

        var env = mail.envelope ? mail.envelope : mail;
        var msgId = mail.id ? String(mail.id) : (env.id ? String(env.id) : "");
        if (!msgId || msgId === "") return;

        var tmp = [];
        for (var j = 0; j < controller.emails.length; j++) {
            var checkMail = controller.emails[j];
            var checkEnv = checkMail.envelope ? checkMail.envelope : checkMail;
            var checkId = checkMail.id ? String(checkMail.id) : (checkEnv.id ? String(checkEnv.id) : "");
            if (checkId !== msgId) tmp.push(checkMail);
        }

        controller.emails = tmp;
        controller.selectedId = "";
        controller.statusMessage = "Message deleted successfully.";
        processes.deleteMessage(msgId);
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
                font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : controller.globalFontSize
                verticalAlignment: TextInput.AlignVCenter
                text: controller.searchQuery

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

            Rectangle {
                id: importantToggleButton
                width: 32; height: 24; radius: 3
                anchors.right: regexToggleButton.left; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                color: controller.isImportantOnlyView ? root.buttonActiveColor : "transparent"
                border.color: controller.isImportantOnlyView ? root.searchActiveColor : "#333345"
                border.width: 1

                Text { anchors.centerIn: parent; text: "⭐"; font.pixelSize: 14; color: controller.isImportantOnlyView ? "white" : "#777785" }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        controller.isImportantOnlyView = !controller.isImportantOnlyView;
                        processes.refreshMail();
                    }
                }
            }

            Rectangle {
                id: regexToggleButton
                width: 32; height: 24; radius: 3
                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                color: controller.isRegexSearch ? root.buttonActiveColor : "transparent"
                border.color: controller.isRegexSearch ? root.searchActiveColor : "#333345"
                border.width: 1

                Text { anchors.centerIn: parent; text: ".*"; font.bold: true; font.pixelSize: 14; color: controller.isRegexSearch ? "white" : "#777785" }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { controller.isRegexSearch = !controller.isRegexSearch; }
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
                focus: !controller.isReplying && !controller.isComposing
                activeFocusOnTab: true

                Keys.onUpPressed: (event) => { if (currentIndex > 0) { currentIndex--; controller.currentListIndex = currentIndex; } }
                Keys.onDownPressed: (event) => { if (currentIndex < count - 1) { currentIndex++; controller.currentListIndex = currentIndex; } }
                Keys.onPressed: (event) => { if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) { deleteCurrentMessage(); event.accepted = true; } }

                delegate: Rectangle {
                    width: emailList.width
                    height: stylixTheme ? (stylixTheme.defaultCardHeight * 0.75) : (controller.defaultCardHeight * 0.75)
                    radius: stylixTheme ? (stylixTheme.defaultCardRadius - 2) : (controller.defaultCardRadius - 2)
                    color: controller.currentListIndex === index ? (stylixTheme ? stylixTheme.base02 : "#1a1a1a") : "transparent"

                    border.width: (controller.currentListIndex === index) ? (stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth) : 0
                    border.color: stylixTheme ? stylixTheme.base05 : "#FABD2F"

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            emailList.currentIndex = index;
                            controller.currentListIndex = index;
                            openCurrentMessage();
                            emailList.forceActiveFocus();
                        }
                    }

                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 4

                        Text {
                            width: parent.width - 24
                            text: modelData.from ? (modelData.from.name || modelData.from.addr || modelData.from) : (modelData.envelope && modelData.envelope.from ? (modelData.envelope.from.name || modelData.envelope.from.addr) : "")
                            color: stylixTheme ? stylixTheme.base08 : "#ff6666"
                            font.bold: true; font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily
                            font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize + 2) : (controller.globalFontSize + 2)
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width - 24
                            text: modelData.subject !== undefined ? modelData.subject : (modelData.envelope && modelData.envelope.subject !== undefined ? modelData.envelope.subject : "(No Subject)")
                            color: stylixTheme ? stylixTheme.base05 : "white"
                            font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily
                            font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize) : (controller.globalFontSize)
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.date ? modelData.date : (modelData.envelope && modelData.envelope.date ? modelData.envelope.date : "")
                            color: stylixTheme ? stylixTheme.base04 : "#999999"
                            font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily
                            font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize - 4) : (controller.globalFontSize - 4)
                        }
                    }
                }
            }
        }
    }
}
