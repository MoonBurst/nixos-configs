import QtQml
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    required property QtObject controller
    required property QtObject processes
    property var stylixTheme

    visible: controller.isReplying
    anchors.centerIn: parent

    width: stylixTheme ? (controller.defaultCardWidth * 2.3) : 1000
    height: stylixTheme ? (controller.defaultCardHeight * 6.4) : 900
    z: 99

    radius: stylixTheme ? stylixTheme.defaultCardRadius : controller.defaultCardRadius

    color: stylixTheme ? stylixTheme.base01 : "#1a1a24"
    border.color: stylixTheme ? stylixTheme.base05 : "#ffffff"
    border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth

    onVisibleChanged: {
        if (root.visible) {
            var rawBody = "";
            if (controller.messageBody && String(controller.messageBody).trim().length > 0) {
                rawBody = String(controller.messageBody);
            } else if (controller.currentMessageBody && String(controller.currentMessageBody).trim().length > 0) {
                rawBody = String(controller.currentMessageBody);
            } else if (processes.innerMessageBody && String(processes.innerMessageBody).trim().length > 0) {
                rawBody = String(processes.innerMessageBody);
            }

            rawBody = rawBody.trim();
            if (rawBody === "" || rawBody === "Loading message...") {
                rawBody = "(No plain text content available in message body)";
            } else {
                rawBody = rawBody.replace(/<#part[^>]*>/gi, "");
                rawBody = rawBody.replace(/<#\/part>/gi, "");
                rawBody = rawBody.trim();
            }

            var sender = controller.currentReplyTo ? String(controller.currentReplyTo) : "Sender";
            var attribution = "\n\nOn " + new Date().toLocaleString() + ", " + sender + " wrote:\n";

            // FIXED: Added safe fallback to guarantee string data structure compliance before running regex match pipelines
            var cleanString = rawBody ? String(rawBody) : "";
            var cleanLines = cleanString.replace(/\r\n/g, "\n").split("\n");
            var citedHistory = cleanLines.map(function(line) {
                return "> " + line;
            }).join("\n");

            replyEditor.text = attribution + citedHistory;
            replyEditor.cursorPosition = 0;
            replyEditor.forceActiveFocus();
        }
    }

    function sendReply() {
        if (processes.sendRawMessage) {
            processes.sendRawMessage(replyEditor.text);
        } else if (processes.sendRawEmail) {
            processes.sendRawEmail(replyEditor.text);
        } else {
            if (processes.sendEmail) {
                processes.sendEmail(controller.userEmailAddress, controller.currentReplyTo, controller.currentSubject, replyEditor.text);
                controller.isReplying = false;
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.topMargin: stylixTheme ? (stylixTheme.globalPadding + 8) : 28
        anchors.bottomMargin: stylixTheme ? (stylixTheme.globalPadding) : 20
        anchors.leftMargin: stylixTheme ? (stylixTheme.globalPadding) : 20
        anchors.rightMargin: stylixTheme ? (stylixTheme.globalPadding) : 20
        spacing: 16
        z: 1

        Row {
            spacing: stylixTheme ? (stylixTheme.globalPadding / 2) : 10

            Rectangle {
                width: 250; height: 40; radius: 6
                color: stylixTheme ? stylixTheme.base02 : "#1a1a1a"
                border.color: stylixTheme ? stylixTheme.base05 : "#ffffff"
                border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth
                Text { anchors.centerIn: parent; text: "Send (Ctrl+Enter)"; color: stylixTheme ? stylixTheme.base05 : "white"; font.bold: true; font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily }
                MouseArea { anchors.fill: parent; onClicked: sendReply() }
            }

            Rectangle {
                width: 160; height: 40; radius: 6
                color: stylixTheme ? stylixTheme.base02 : "#1a1a1a"
                border.color: stylixTheme ? stylixTheme.base05 : "#ffffff"
                border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth
                Text { anchors.centerIn: parent; text: "Cancel (Esc)"; color: stylixTheme ? stylixTheme.base05 : "white"; font.bold: true; font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily }
                MouseArea { anchors.fill: parent; onClicked: { controller.isReplying = false; } }
            }
        }

        Rectangle {
            width: parent.width
            height: parent.height - 70
            color: stylixTheme ? stylixTheme.base00 : "#1a1a2a"
            border.color: replyEditor.activeFocus ? (stylixTheme ? stylixTheme.base05 : "#ffffff") : (stylixTheme ? stylixTheme.base02 : "#333345")
            border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth
            radius: 4

            Flickable {
                anchors.fill: parent
                anchors.margins: 12
                clip: true
                contentHeight: replyEditor.contentHeight + 20

                TextEdit {
                    id: replyEditor
                    width: parent.width
                    wrapMode: TextEdit.Wrap
                    color: "white"
                    font.family: "monospace"
                    font.pixelSize: stylixTheme ? controller.globalFontSize : 20
                    activeFocusOnTab: true

                    onTextChanged: {
                        if (root.visible) {
                            controller.replyText = text;
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            controller.isReplying = false;
                            event.accepted = true;
                            return;
                        }

                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                            sendReply();
                            event.accepted = true;
                            return;
                        }
                    }
                }
            }
        }
    }
}
