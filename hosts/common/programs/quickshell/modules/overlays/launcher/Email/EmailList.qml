import QtQuick
import Quickshell

Rectangle {
    id: root

    required property QtObject controller
    required property QtObject processes

    property var stylixTheme

    property alias innerListView: emailList

    // Explicit root properties prevent dynamic shorthand color evaluations from crashing
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

    // Advanced Dynamic Filtering Engine with Fixed Case and Object Lookups
    function getFilteredEmails() {
        var list = controller.emails;
        if (!list) return [];
        if (controller.searchQuery.trim() === "") return list;

        var tempMatches = [];

        if (controller.isRegexSearch) {
            try {
                // Instantiates a case-insensitive regular expression from the input field string
                var regex = new RegExp(controller.searchQuery, "i");
                for (var i = 0; i < list.length; i++) {
                    var mail = list[i];
                    var subject = mail.subject ? String(mail.subject) : "";

                    // Safe verification of nested Himalaya sender metadata blocks
                    var fromName = (mail.from && mail.from.name) ? String(mail.from.name) : "";
                    var fromAddr = (mail.from && mail.from.addr) ? String(mail.from.addr) : "";

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
                var subject = mail.subject ? String(mail.subject).toLowerCase() : "";
                var fromName = (mail.from && mail.from.name) ? String(mail.from.name).toLowerCase() : "";
                var fromAddr = (mail.from && mail.from.addr) ? String(mail.from.addr).toLowerCase() : "";

                // Cleared the duplicate typo and unified accurate subset string indexing
                if (subject.indexOf(query) !== -1 ||
                    fromName.indexOf(query) !== -1 ||
                    fromAddr.indexOf(query) !== -1) {
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
        var email = filtered[emailList.currentIndex]

        if (!email)
            return

            controller.selectedId = email.id
            controller.messageBody = "Loading message from local cache..."

            controller.currentReplyTo =
            email.from ? email.from.addr : ""

            controller.currentSubject =
            email.subject ? email.subject : ""

            if (controller.currentSubject.toLowerCase().indexOf("re:") !== 0)
                controller.currentSubject =
                "Re: " + controller.currentSubject

                processes.loadMessage(email.id)
    }
    function deleteCurrentMessage() {
        var filtered = getFilteredEmails();
        var mail = filtered[emailList.currentIndex]

        if (!mail)
            return

            var isFlagged = false;
        if (mail && mail.flags && Array.isArray(mail.flags)) {
            for (var i = 0; i < mail.flags.length; i++) {
                var flag = String(mail.flags[i]).toLowerCase();
                if (flag === "flagged" || flag === "starred" || flag === "important") {
                    isFlagged = true;
                    break;
                }
            }
        }

        if (isFlagged) {
            controller.statusMessage = "⚠️ CRITICAL: Starred messages are immune to deletion!";
            return;
        }

        var tmp = controller.emails.slice()
        for (var j = 0; j < tmp.length; j++) {
            if (tmp[j].id === mail.id) {
                tmp.splice(j, 1);
                break;
            }
        }

        controller.emails = tmp
        controller.selectedId = ""
        controller.messageBody = "Message moved to Trash locally."

        Quickshell.execDetached([
            "himalaya",
            "message",
            "delete",
            mail.id
        ])
    }

    Column {
        anchors.fill: parent
        anchors.margins:
        stylixTheme
        ? stylixTheme.globalPadding / 2
        : 6

        spacing:
        stylixTheme
        ? stylixTheme.globalPadding / 2
        : 6

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
                width: 32
                height: 24
                radius: 3

                anchors.right: regexToggleButton.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter

                color: controller.isImportantOnlyView
                ? (stylixTheme ? stylixTheme.base03 : "#aa8800")
                : "transparent"

                border.color: controller.isImportantOnlyView ? root.searchActiveColor : "#333345"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "⭐"
                    font.pixelSize: 14
                    color: controller.isImportantOnlyView ? "white" : "#777785"
                }

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
                width: 32
                height: 24
                radius: 3

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                color: controller.isRegexSearch ? root.buttonActiveColor : "transparent"
                border.color: controller.isRegexSearch ? root.searchActiveColor : "#333345"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: ".*"
                    font.bold: true
                    font.pixelSize: 14
                    color: controller.isRegexSearch ? "white" : "#777785"
                }

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

                focus:
                !controller.isReplying &&
                !controller.isComposing

                activeFocusOnTab: true

                currentIndex: controller.currentListIndex

                onCurrentIndexChanged: {
                    if (controller.currentListIndex !== currentIndex) {
                        controller.currentListIndex = currentIndex;
                    }
                }

                Connections {
                    target: controller
                    function onIsReplyingChanged() {
                        if (!controller.isReplying && !controller.isComposing) {
                            emailList.forceActiveFocus()
                        }
                    }
                    function onIsComposingChanged() {
                        if (!controller.isReplying && !controller.isComposing) {
                            emailList.forceActiveFocus()
                        }
                    }
                }

                Keys.onUpPressed: (event) => {
                    if (currentIndex > 0) {
                        controller.currentListIndex = currentIndex - 1;
                        event.accepted = true;
                    }
                }

                Keys.onDownPressed: (event) => {
                    var filteredCount = root.getFilteredEmails().length;
                    if (currentIndex < filteredCount - 1) {
                        controller.currentListIndex = currentIndex + 1;
                        event.accepted = true;
                    }
                }

                Keys.onReturnPressed: {
                    if (controller.isReplying || controller.isComposing)
                        return

                        var filtered = root.getFilteredEmails();
                    var email = filtered[currentIndex]

                    if (!email)
                        return

                        if (controller.selectedId === email.id &&
                            controller.messageBody !== "" &&
                            controller.messageBody.indexOf("Loading") !== 0) {

                            controller.isReplying = true
                            } else {
                                openCurrentMessage()
                            }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Delete &&
                        !controller.isReplying &&
                        !controller.isComposing) {

                        deleteCurrentMessage()
                        event.accepted = true
                        }
                }

                delegate: Rectangle {
                    width: emailList.width
                    height: 105

                    radius:
                    stylixTheme
                    ? stylixTheme.defaultCardRadius - 2
                    : 8

                    color:
                    controller.currentListIndex === index
                    ? (stylixTheme
                    ? stylixTheme.base03
                    : "#003399")
                    : "transparent"

                    border.width:
                    controller.selectedId === modelData.id
                    ? 2
                    : 0

                    border.color:
                    stylixTheme
                    ? stylixTheme.base0A
                    : "#FABD2F"

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            controller.currentListIndex = index
                            openCurrentMessage()
                            emailList.forceActiveFocus()
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12

                        spacing: 4

                        Text {
                            width: parent.width - 24
                            text: modelData.from ? (modelData.from.name || modelData.from.addr) : ""
                            color: stylixTheme ? stylixTheme.base08 : "#ff6666"
                            font.bold: true
                            font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"
                            font.pixelSize: stylixTheme ? stylixTheme.globalFontSize + 2 : 22
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width - 24
                            text: modelData.subject || "(No Subject)"
                            color: stylixTheme ? stylixTheme.base05 : "white"
                            font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"
                            font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : 20
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.date || ""
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
