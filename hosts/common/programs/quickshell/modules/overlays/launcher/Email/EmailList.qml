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

    function forceSearchFocus() {
        searchField.forceActiveFocus();
    }
    function getFilteredEmails() {
        var list = controller.emails;
        if (!list) return [];
        if (controller.searchQuery.trim() === "") return list;

        var tempMatches = [];
        if (controller.isRegexSearch) {
            try {
                var regex = new RegExp(controller.searchQuery, "i");
                for (var i = 0; i < list.length; i++) {
                    var mail = list[i];
                    var env = mail.envelope ? mail.envelope : mail;

                    var subject = mail.subject ? String(mail.subject) : (env.subject ? String(env.subject) : "");
                    var fromName = mail.from ? (mail.from.name || "") : (env.from && env.from.name ? String(env.from.name) : "");
                    var fromAddr = mail.from ? (mail.from.addr || "") : (env.from && env.from.addr ? String(env.from.addr) : "");

                    if (regex.test(subject) || regex.test(fromName) || regex.test(fromAddr)) {
                        tempMatches.push(mail);
                    }
                }
            } catch (e) {
                return list;
            }
        } else {
            var query = controller.searchQuery.toLowerCase();
            for (var i = 0; i < list.length; i++) {
                var mail = list[i];
                var env = mail.envelope ? mail.envelope : mail;

                var subject = mail.subject ? String(mail.subject).toLowerCase() : (env.subject ? String(env.subject).toLowerCase() : "");
                var fromName = mail.from ? String(mail.from.name || "").toLowerCase() : (env.from && env.from.name ? String(env.from.name).toLowerCase() : "");
                var fromAddr = mail.from ? String(mail.from.addr || "").toLowerCase() : (env.from && env.from.addr ? String(env.from.addr).toLowerCase() : "");

                if (subject.indexOf(query) !== -1 || fromName.indexOf(query) !== -1 || fromAddr.indexOf(query) !== -1) {
                    tempMatches.push(mail);
                }
            }
        }
        return tempMatches;
    }
    Component.onCompleted: {
        emailList.forceActiveFocus()
    }

    function openCurrentMessage() {
        var filtered = getFilteredEmails();
        var email = filtered[emailList.currentIndex];
        if (!email) return;

        // FIXED: Checks both root level keys and envelope sub-properties for the unique ID string token
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

        // Adaptive routing for From and Subject details
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

                        // FIXED: Adaptive text properties map parameters out of root keys and fallback objects simultaneously
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
                            font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : controller.globalFontSize
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
