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
    property color buttonActiveColor: stylixTheme ? stylixTheme.base03 : "#444455"
    property color mainPanelBgColor: stylixTheme ? stylixTheme.base01 : "#1a1a24"

    color: root.mainPanelBgColor
    border.color: root.searchInactiveColor
    border.width: stylixTheme ? stylixTheme.globalBorderWidth : 1
    radius: stylixTheme ? stylixTheme.defaultCardRadius : 0

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

                    var subject = env.subject ? String(env.subject) : "";
                    var fromName = (env.from && env.from.name) ? String(env.from.name) : "";
                    var fromAddr = (env.from && env.from.addr) ? String(env.from.addr) : "";

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

                var subject = env.subject ? String(env.subject).toLowerCase() : "";
                var fromName = (env.from && env.from.name) ? String(env.from.name).toLowerCase() : "";
                var fromAddr = (env.from && env.from.addr) ? String(env.from.addr).toLowerCase() : "";

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

        var env = email.envelope ? email.envelope : email;

        var msgId = "";
        if (email.id && typeof email.id === "object" && email.id.id) {
            msgId = String(email.id.id);
        } else if (env.id && typeof env.id === "object" && env.id.id) {
            msgId = String(env.id.id);
        } else {
            msgId = email.id ? String(email.id) : (env.id ? String(env.id) : "");
        }

        if (!msgId) return;

        controller.selectedId = msgId;
        controller.messageBody = "Loading message from local cache...";
        controller.currentReplyTo = env.from ? env.from.addr : "";
        controller.currentSubject = env.subject ? env.subject : "";

        if (controller.currentSubject.toLowerCase().indexOf("re:") !== 0) {
            controller.currentSubject = "Re: " + controller.currentSubject;
        }
        processes.loadMessage(msgId);
    }


    function deleteCurrentMessage() {
        console.log("--> deleteCurrentMessage() function was called successfully!");

        var filtered = getFilteredEmails();
        var mail = filtered[emailList.currentIndex];
        if (!mail) {
            console.log("--> Deletion error: Active email item is undefined.");
            return;
        }


        var msgId = mail.id ? String(mail.id) : "";

        console.log("--> Front-end extracted unique msgId text: [" + msgId + "]");
        if (!msgId || msgId === "") return;

        // Optimistically remove the item from the local array list view so it vanishes instantly
        var tmp = [];
        for (var j = 0; j < controller.emails.length; j++) {
            var checkMail = controller.emails[j];
            if (checkMail.id && String(checkMail.id) !== msgId) {
                tmp.push(checkMail);
            }
        }

        controller.emails = tmp;
        controller.selectedId = "";
        controller.statusMessage = "Message deleted successfully.";

        // Pass the actual file prefix to your backend delete process script
        processes.deleteMessage(msgId);
    }


    Column {
        anchors.fill: parent
        anchors.margins: stylixTheme ? stylixTheme.globalPadding / 2 : 6
        spacing: stylixTheme ? stylixTheme.globalPadding / 2 : 6

        Text {
            id: statusText
            text: controller.statusMessage
            color: root.textHeaderColor
            font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"
            font.pixelSize: stylixTheme ? stylixTheme.globalFontSize + 4 : 24
        }

        Rectangle {
            width: parent.width
            height: 40
            radius: 4
            color: root.searchBgColor
            border.color: searchField.activeFocus ? root.searchActiveColor : root.searchInactiveColor
            border.width: 1

            TextInput {
                id: searchField
                width: parent.width - 86
                height: parent.height
                anchors.left: parent.left
                anchors.leftMargin: 8
                color: "white"
                font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"
                font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : 20
                verticalAlignment: TextInput.AlignVCenter
                text: controller.searchQuery

                onTextChanged: {
                    controller.searchQuery = text;
                    emailList.currentIndex = 0;
                }

                Text {
                    text: controller.isRegexSearch ? "🔍 Regex search pattern..." : "🔍 Search subject or sender..."
                    color: "#555565"
                    visible: searchField.text === ""
                    anchors.fill: parent
                    font.family: searchField.font.family
                    font.pixelSize: searchField.font.pixelSize
                    verticalAlignment: Text.AlignVCenter
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        searchField.text = "";
                        emailList.forceActiveFocus();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Down) {
                        emailList.forceActiveFocus();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_R && (event.modifiers & Qt.AltModifier)) {
                        controller.isRegexSearch = !controller.isRegexSearch;
                        event.accepted = true;
                        return;
                    }
                }
            }

            Rectangle {
                id: importantToggleButton
                width: 32; height: 24; radius: 3
                anchors.right: regexToggleButton.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                color: controller.isImportantOnlyView ? (stylixTheme ? stylixTheme.base03 : "#aa8800") : "transparent"
                border.color: controller.isImportantOnlyView ? root.searchActiveColor : "#333345"
                border.width: 1

                Text { anchors.centerIn: parent; text: "⭐"; font.pixelSize: 14; color: controller.isImportantOnlyView ? "white" : "#777785" }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        controller.isImportantOnlyView = !controller.isImportantOnlyView;
                        processes.refreshMail();
                        searchField.forceActiveFocus();
                    }
                }
            }

            Rectangle {
                id: regexToggleButton
                width: 32; height: 24; radius: 3
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                color: controller.isRegexSearch ? root.buttonActiveColor : "transparent"
                border.color: controller.isRegexSearch ? root.searchActiveColor : "#333345"
                border.width: 1

                Text { anchors.centerIn: parent; text: ".*"; font.bold: true; font.pixelSize: 14; color: controller.isRegexSearch ? "white" : "#777785" }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        controller.isRegexSearch = !controller.isRegexSearch;
                        searchField.forceActiveFocus();
                    }
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

                Keys.onUpPressed: (event) => {
                    if (currentIndex > 0) {
                        currentIndex--;
                        controller.currentListIndex = currentIndex;
                        event.accepted = true;
                    }
                }
                Keys.onDownPressed: (event) => {
                    var filteredCount = root.getFilteredEmails().length;
                    if (currentIndex < filteredCount - 1) {
                        currentIndex++;
                        controller.currentListIndex = currentIndex;
                        event.accepted = true;
                    }
                }
                Keys.onReturnPressed: (event) => {
                    if (controller.isReplying || controller.isComposing) return;
                    var filtered = root.getFilteredEmails();
                    var email = filtered[currentIndex];
                    if (!email) return;

                    var env = email.envelope ? email.envelope : email;

                    var msgId = "";
                    if (email.id && typeof email.id === "object" && email.id.id) {
                        msgId = String(email.id.id);
                    } else if (env.id && typeof env.id === "object" && env.id.id) {
                        msgId = String(env.id.id);
                    } else {
                        msgId = email.id ? String(email.id) : (env.id ? String(env.id) : "");
                    }

                    if (controller.selectedId === msgId && controller.messageBody !== "" && controller.messageBody.indexOf("Loading") !== 0) {
                        controller.isReplying = true;
                    } else {
                        openCurrentMessage();
                    }
                    event.accepted = true;
                }

                Keys.onPressed: (event) => {
                    console.log("--> Keys.onPressed intercepted key ID: " + event.key);

                    if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                        console.log("--> Match found! Hitting core deletion function now.");
                        deleteCurrentMessage();
                        event.accepted = true;
                    }
                }


                delegate: Rectangle {
                    width: emailList.width
                    height: 105
                    radius: stylixTheme ? stylixTheme.defaultCardRadius - 2 : 8
                    color: controller.currentListIndex === index ? (stylixTheme ? stylixTheme.base03 : "#003399") : "transparent"
                    border.width: (controller.selectedId === modelData.id || (modelData.envelope && controller.selectedId === modelData.envelope.id)) ? 2 : 0
                    border.color: stylixTheme ? stylixTheme.base0A : "#FABD2F"

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
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        Text {
                            width: parent.width - 24
                            property var env: modelData.envelope ? modelData.envelope : modelData
                            text: env.from ? (env.from.name || env.from.addr) : ""
                            color: stylixTheme ? stylixTheme.base08 : "#ff6666"
                            font.bold: true
                            font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"
                            font.pixelSize: stylixTheme ? stylixTheme.globalFontSize + 2 : 22
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width - 24
                            property var env: modelData.envelope ? modelData.envelope : modelData
                            text: env.subject || "(No Subject)"
                            color: stylixTheme ? stylixTheme.base05 : "white"
                            font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"
                            font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : 20
                            elide: Text.ElideRight
                        }
                        Text {
                            property var env: modelData.envelope ? modelData.envelope : modelData
                            text: env.date || ""
                            color: stylixTheme ? stylixTheme.base04 : "#999999"
                            font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"
                            font.pixelSize: stylixTheme ? stylixTheme.globalFontSize - 4 : 12
                        }
                    }
                }
            }
        }
    }
}
