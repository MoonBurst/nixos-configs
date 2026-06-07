import QtQml
import QtQuick
import QtQuick.Controls
import Quickshell.Io

Rectangle {
    id: root

    required property QtObject controller
    required property QtObject processes
    property var stylixTheme

    visible: controller.isComposing
    anchors.centerIn: parent

    width: stylixTheme ? (controller.defaultCardWidth * 2.3) : 1000
    height: stylixTheme ? (controller.defaultCardHeight * 6.4) : 900
    z: 99

    radius: stylixTheme ? stylixTheme.defaultCardRadius : controller.defaultCardRadius

    color: stylixTheme ? stylixTheme.base01 : "#1a1a24"
    border.color: stylixTheme ? stylixTheme.base05 : "#ffffff"
    border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth

    property var rawContacts: []
    property var filteredContacts: []

    onVisibleChanged: {
        if (root.visible) {
            toField.forceActiveFocus();
            contactsLoader.running = true;
        }
    }

    function handleSend() {
        if (toField.text.trim() === "") return;
        processes.sendEmail(
            controller.userEmailAddress,
            toField.text,
            subjectField.text,
            bodyEditor.text
        );
        controller.isComposing = false;
    }

    Process {
        id: contactsLoader
        command: ["cat", "/home/moonburst/Documents/Contacts"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rawLines = text.split("\n");
                var cleanList = [];
                for (var i = 0; i < rawLines.length; i++) {
                    var trimmed = rawLines[i].trim();
                    if (trimmed.length > 0) cleanList.push(trimmed);
                }
                root.rawContacts = cleanList;
            }
        }
    }

    function updateSuggestions(currentInput) {
        if (currentInput.trim() === "") {
            root.filteredContacts = [];
            return;
        }
        var matches = [];
        var query = currentInput.toLowerCase();
        for (var i = 0; i < root.rawContacts.length; i++) {
            var item = root.rawContacts[i];
            if (item.toLowerCase().indexOf(query) !== -1) {
                matches.push(item);
            }
        }
        root.filteredContacts = matches;
    }
    Column {
        anchors.fill: parent
        anchors.margins: stylixTheme ? stylixTheme.globalPadding : controller.globalPadding
        spacing: 12

        Row {
            spacing: stylixTheme ? (stylixTheme.globalPadding / 2) : 10

            Rectangle {
                width: 180; height: 40; radius: 6
                color: stylixTheme ? stylixTheme.base02 : "#003399"
                border.color: stylixTheme ? stylixTheme.base05 : "#ffffff"
                border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth
                Text { anchors.centerIn: parent; text: "Send (Ctrl+Enter)"; color: stylixTheme ? stylixTheme.base05 : "white"; font.bold: true; font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily }
                MouseArea { anchors.fill: parent; onClicked: handleSend() }
            }

            Rectangle {
                width: 160; height: 40; radius: 6
                color: stylixTheme ? stylixTheme.base02 : "#1a1a2a"
                border.color: stylixTheme ? stylixTheme.base05 : "#ffffff"
                border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth
                Text { anchors.centerIn: parent; text: "Cancel (Esc)"; color: stylixTheme ? stylixTheme.base05 : "white"; font.bold: true; font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily }
                MouseArea { anchors.fill: parent; onClicked: { controller.isComposing = false; } }
            }
        }

        Column {
            width: parent.width
            spacing: 6
            z: 10

            Text { text: "To:"; color: stylixTheme ? stylixTheme.base05 : "white"; font.bold: true; font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily }
            Rectangle {
                width: parent.width; height: 40; radius: 4
                color: stylixTheme ? stylixTheme.base00 : "#16161c"
                border.color: toField.activeFocus ? (stylixTheme ? stylixTheme.base05 : "#ffffff") : (stylixTheme ? stylixTheme.base02 : "#333345")
                border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth

                TextInput {
                    id: toField; anchors.fill: parent; anchors.margins: 8; color: "white";
                    text: controller.composeToAddress
                    font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily;
                    font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : controller.globalFontSize
                    activeFocusOnTab: true

                    onTextChanged: {
                        controller.composeToAddress = text;
                        root.updateSuggestions(text);
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Tab) {
                            if (root.filteredContacts.length > 0) {
                                var topSuggestion = String(root.filteredContacts[0]);
                                text = topSuggestion;
                                controller.composeToAddress = topSuggestion;
                                root.filteredContacts = [];
                                subjectField.forceActiveFocus();
                                event.accepted = true;
                                return;
                            }
                        }
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                            root.handleSend();
                            event.accepted = true;
                        }
                    }
                }
            }

            Rectangle {
                id: suggestionsMenuFrame
                width: parent.width
                height: Math.min(200, filteredContactsRepeater.count * 35)
                visible: root.filteredContacts.length > 0
                color: stylixTheme ? stylixTheme.base00 : "#1e1e24"
                border.color: stylixTheme ? stylixTheme.base03 : "#333345"
                border.width: 1
                radius: 4

                Flickable {
                    id: suggestionsFlickable
                    anchors.fill: parent
                    clip: true
                    contentWidth: parent.width
                    contentHeight: filteredContactsRepeater.count * 35
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        width: parent.width
                        Repeater {
                            id: filteredContactsRepeater
                            model: root.filteredContacts
                            delegate: Rectangle {
                                width: parent.width; height: 35
                                color: mouseInSuggestion.containsMouse ? (stylixTheme ? stylixTheme.base02 : "#333355") : "transparent"

                                Text {
                                    anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                    text: modelData; color: "white"
                                    font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily
                                }
                                MouseArea {
                                    id: mouseInSuggestion
                                    anchors.fill: parent; hoverEnabled: true
                                    onClicked: {
                                        toField.text = modelData;
                                        root.filteredContacts = [];
                                        subjectField.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: menuScrollIndicator
                    visible: suggestionsFlickable.contentHeight > suggestionsMenuFrame.height
                    width: 5; radius: 2.5
                    color: stylixTheme ? stylixTheme.base04 : "#555565"
                    anchors.right: parent.right; anchors.rightMargin: 3
                    height: Math.max(20, (suggestionsMenuFrame.height / suggestionsFlickable.contentHeight) * suggestionsMenuFrame.height)
                    y: (suggestionsFlickable.contentY / (suggestionsFlickable.contentHeight - suggestionsMenuFrame.height)) * (suggestionsMenuFrame.height - height)
                }
            }
            Text { text: "Subject:"; color: stylixTheme ? stylixTheme.base05 : "white"; font.bold: true; font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily }
            Rectangle {
                width: parent.width; height: 40; radius: 4
                color: stylixTheme ? stylixTheme.base00 : "#16161c"
                border.color: subjectField.activeFocus ? (stylixTheme ? stylixTheme.base05 : "#ffffff") : (stylixTheme ? stylixTheme.base02 : "#333345")
                border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth

                TextInput {
                    id: subjectField; anchors.fill: parent; anchors.margins: 8; color: "white";
                    text: controller.composeSubject; onTextChanged: controller.composeSubject = text;
                    font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily;
                    font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : controller.globalFontSize
                    activeFocusOnTab: true

                    Keys.onPressed: (event) => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                            root.handleSend();
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: parent.height - 240
            color: stylixTheme ? stylixTheme.base00 : "#1a1a2a"
            border.color: bodyEditor.activeFocus ? (stylixTheme ? stylixTheme.base05 : "#ffffff") : (stylixTheme ? stylixTheme.base02 : "#333345")
            border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth
            radius: 4

            Flickable {
                anchors.fill: parent
                anchors.margins: 12
                clip: true
                contentHeight: bodyEditor.contentHeight + 20

                TextEdit {
                    id: bodyEditor
                    width: parent.width
                    text: controller.composeBodyText
                    wrapMode: TextEdit.Wrap
                    color: "white"
                    font.family: "monospace"
                    font.pixelSize: stylixTheme ? controller.globalFontSize : 20
                    activeFocusOnTab: true

                    onTextChanged: controller.composeBodyText = text

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            controller.isComposing = false;
                            event.accepted = true;
                            return;
                        }
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                            root.handleSend();
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }
}

