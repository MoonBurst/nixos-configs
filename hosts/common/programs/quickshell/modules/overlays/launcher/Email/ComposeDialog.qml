import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    required property QtObject controller
    required property QtObject processes

    property var stylixTheme

    visible: controller.isComposing

    anchors.centerIn: parent

    width: 1000
    height: 1000

    z: 99

    radius: stylixTheme ? stylixTheme.defaultCardRadius : 10

    color: stylixTheme ? stylixTheme.base01 : "#0F0F0F"

    border.color:
    stylixTheme
    ? stylixTheme.base03
    : "#675DDB"

    border.width:
    stylixTheme
    ? stylixTheme.globalBorderWidth + 2
    : 3

    focus: root.visible

    // FIX: Bubble up internal child properties to root scope via global property aliases
    property alias addressField: addressField
    property alias subjectField: subjectField
    property alias bodyEditor: bodyEditor

    property var cachedContactsList: []
    property var matchedSuggestions: []

    onVisibleChanged: {
        if (root.visible) {
            Qt.callLater(function() {
                addressField.forceActiveFocus();
            });
            matchedSuggestions = [];
            readContactsFileProcess.running = false;
            readContactsFileProcess.running = true;
        }
    }

    Process {
        id: readContactsFileProcess
        command: ["sh", "-c", "cat ~/Documents/Contacts"]

        stdout: StdioCollector {
            onStreamFinished: {
                var rawLines = text.split("\n");
                var cleanArray = [];
                for (var i = 0; i < rawLines.length; i++) {
                    var trimmed = rawLines[i].trim();
                    if (trimmed.length > 0) {
                        cleanArray.push(trimmed);
                    }
                }
                root.cachedContactsList = cleanArray;
            }
        }
    }

    function sendMessage() {
        var cleanBody =
        bodyEditor.text.replace(/"/g, '\\"')

        var cleanSubject =
        subjectField.text.replace(/"/g, '\\"')

        var cleanTo =
        addressField.text.replace(/"/g, '\\"')

        processes.sendEmail(
            controller.userEmailAddress,
            cleanTo,
            cleanSubject,
            cleanBody
        )

        controller.isComposing = false
    }

    Column {
        anchors.fill: parent
        anchors.margins:
        stylixTheme
        ? stylixTheme.globalPadding
        : 20

        spacing: 12

        Row {
            spacing: 12

            Rectangle {
                width: 200
                height: 50

                color:
                stylixTheme
                ? stylixTheme.base02
                : "#2a2a3a"

                radius: 6

                border.color:
                stylixTheme
                ? stylixTheme.base05
                : "#ffffff"

                border.width:
                stylixTheme
                ? stylixTheme.globalBorderWidth
                : 3

                Text {
                    anchors.centerIn: parent
                    text: "Send Message"

                    color:
                    stylixTheme
                    ? stylixTheme.base05
                    : "white"

                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: sendMessage()
                }
            }

            Rectangle {
                width: 120
                height: 50

                color:
                stylixTheme
                ? stylixTheme.base02
                : "#aa2222"

                radius: 6

                border.color:
                stylixTheme
                ? stylixTheme.base05
                : "#ffffff"

                border.width:
                stylixTheme
                ? stylixTheme.globalBorderWidth
                : 3

                Text {
                    anchors.centerIn: parent
                    text: "Discard"
                    color:
                    stylixTheme
                    ? stylixTheme.base05
                    : "#aa2222"

                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        controller.isComposing = false
                    }
                }
            }
        }
        Text {
            text: "To"
            color: "white"
        }

        Item {
            width: parent.width
            height: 42
            z: 100

            Rectangle {
                anchors.fill: parent
                color: stylixTheme ? stylixTheme.base00 : "#1a1a2a"

                TextInput {
                    id: addressField

                    anchors.fill: parent
                    anchors.margins: 8

                    text: controller.composeToAddress

                    color: "white"
                    focus: root.visible

                    onTextChanged: {
                        if (root.visible) {
                            controller.composeToAddress = text

                            if (text.trim().length === 0) {
                                root.matchedSuggestions = [];
                                return;
                            }

                            var query = text.toLowerCase();
                            var tempMatches = [];
                            for (var i = 0; i < root.cachedContactsList.length; i++) {
                                var contact = root.cachedContactsList[i];
                                if (contact.toLowerCase().indexOf(query) !== -1) {
                                    tempMatches.push(contact);
                                }
                            }
                            root.matchedSuggestions = tempMatches;
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            if (root.matchedSuggestions.length > 0) {
                                root.matchedSuggestions = [];
                            } else {
                                controller.isComposing = false;
                            }
                            event.accepted = true;
                            return;
                        }

                        // FIX: Pulls the first suggestion item out of the array matching your tab entry press
                        if (event.key === Qt.Key_Tab) {
                            if (root.matchedSuggestions.length > 0) {
                                addressField.text = root.matchedSuggestions[0];
                                root.matchedSuggestions = [];
                            }
                            subjectField.forceActiveFocus();
                            event.accepted = true;
                            return;
                        }

                        if (event.key === Qt.Key_Down && root.matchedSuggestions.length > 0) {
                            suggestionListView.forceActiveFocus();
                            suggestionListView.currentIndex = 0;
                            event.accepted = true;
                            return;
                        }

                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            subjectField.forceActiveFocus();
                            event.accepted = true;
                            return;
                        }
                    }
                }
            }

            Rectangle {
                id: suggestionPanel
                visible: root.matchedSuggestions.length > 0

                width: parent.width
                height: Math.min(200, root.matchedSuggestions.length * 40)

                anchors.top: parent.bottom
                anchors.topMargin: 4

                color: stylixTheme ? stylixTheme.base02 : "#222230"
                border.color: stylixTheme ? stylixTheme.base03 : "#444455"
                border.width: 1
                radius: 4

                ListView {
                    id: suggestionListView
                    anchors.fill: parent
                    model: root.matchedSuggestions
                    clip: true

                    highlight: Rectangle {
                        color: stylixTheme ? stylixTheme.base03 : "#333355"
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            root.matchedSuggestions = [];
                            addressField.forceActiveFocus();
                            event.accepted = true;
                            return;
                        }

                        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (currentIndex >= 0 && currentIndex < root.matchedSuggestions.length) {
                                addressField.text = root.matchedSuggestions[currentIndex];
                                root.matchedSuggestions = [];
                                subjectField.forceActiveFocus();
                            }
                            event.accepted = true;
                            return;
                        }
                    }

                    delegate: Item {
                        width: suggestionListView.width
                        height: 40

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            color: "white"
                            font.pixelSize: 16
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                addressField.text = modelData;
                                root.matchedSuggestions = [];
                                root.subjectField.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }
        Text {
            text: "Subject"
            color: "white"
        }

        Rectangle {
            width: parent.width
            height: 42

            color:
            stylixTheme
            ? stylixTheme.base00
            : "#1a1a2a"

            TextInput {
                id: subjectField

                anchors.fill: parent
                anchors.margins: 8

                text: controller.composeSubject

                color: "white"

                focus: root.visible

                onTextChanged: {
                    if (root.visible) {
                        controller.composeSubject = text
                    }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        controller.isComposing = false;
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        bodyEditor.forceActiveFocus();
                        event.accepted = true;
                        return;
                    }
                }
            }
        }

        Text {
            text: "Message"
            color: "white"
        }

        Rectangle {
            id: messageContainer
            width: parent.width
            height: parent.height - 300

            color:
            stylixTheme
            ? stylixTheme.base00
            : "#1a1a2a"

            clip: true

            Flickable {
                id: messageFlickable
                anchors.fill: parent
                anchors.margins: 12

                clip: true
                contentHeight: bodyEditor.paintedHeight + 40

                TextEdit {
                    id: bodyEditor

                    width: parent.width - 24

                    text: controller.composeBodyText

                    wrapMode: TextEdit.Wrap

                    color: "white"

                    font.family: "monospace"

                    font.pixelSize:
                    stylixTheme
                    ? stylixTheme.globalFontSize
                    : 20

                    focus: root.visible

                    onTextChanged: {
                        if (root.visible) {
                            controller.composeBodyText = text
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            controller.isComposing = false
                            event.accepted = true
                            return
                        }

                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
                            (event.modifiers & Qt.ControlModifier)) {

                            sendMessage()
                            event.accepted = true
                            return
                            }
                    }
                }
            }

            Rectangle {
                id: customScrollHandle
                visible: messageFlickable.contentHeight > messageFlickable.height

                width: 6
                radius: 3
                color: stylixTheme ? stylixTheme.base04 : "#555565"

                anchors.right: parent.right
                anchors.rightMargin: 4

                height: Math.max(30, (messageFlickable.height / messageFlickable.contentHeight) * messageFlickable.height)
                y: (messageFlickable.contentY / (messageFlickable.contentHeight - messageFlickable.height)) * (messageFlickable.height - height)
            }
        }
    }
}
