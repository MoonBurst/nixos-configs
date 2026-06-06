import QtQml
import QtQuick
import QtQuick.Controls
import Quickshell

Rectangle {
    id: root

    required property QtObject controller
    required property QtObject processes

    property var stylixTheme

    color: stylixTheme ? stylixTheme.base01 : "#181818"
    border.color: stylixTheme ? stylixTheme.base02 : "#333333"
    border.width: stylixTheme ? stylixTheme.globalBorderWidth : 1
    radius: stylixTheme ? stylixTheme.defaultCardRadius : 0

    function openReply() {
        if (!controller.messageBody ||
            controller.messageBody.indexOf("Loading") === 0)
            return

            controller.replyText =
            "From: " + controller.userEmailAddress + "\n" +
            "To: " + controller.currentReplyTo + "\n" +
            "Subject: " + controller.currentSubject + "\n\n" +
            "--- Original Message ---\n" +
            controller.messageBody

            controller.isReplying = true
    }

    function trashCurrentMessage() {
        if (controller.currentListIndex < 0)
            return

            var mail =
            controller.emails[controller.currentListIndex]

            if (!mail)
                return

                var tmp = controller.emails.slice()

                tmp.splice(controller.currentListIndex, 1)

                controller.emails = tmp
                controller.selectedId = ""
                controller.messageBody =
                "Message moved to Trash locally."

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
        ? stylixTheme.globalPadding
        : 8

        spacing:
        stylixTheme
        ? stylixTheme.globalPadding
        : 8

        Row {
            spacing: 8

            Rectangle {
                width: 140
                height: 50

                color:
                stylixTheme
                ? stylixTheme.base00
                : "#675DDB"

                radius: 4

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

                    text: "✉ New Email"

                    color:
                    stylixTheme
                    ? stylixTheme.base05
                    : "white"

                    font.bold: true

                    font.family:
                    stylixTheme
                    ? stylixTheme.fontFamily
                    : "Fira Sans"

                    font.pixelSize:
                    stylixTheme
                    ? stylixTheme.globalFontSize
                    : 20
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        controller.composeToAddress = ""
                        controller.composeSubject = ""
                        controller.composeBodyText = ""
                        controller.isComposing = true
                    }
                }
            }
            Rectangle {
                width: 120
                height: 50

                color:
                stylixTheme
                ? stylixTheme.base02
                : "#2a2a3a"

                radius: 4

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

                    text: "Refresh (F5)"

                    color:
                    stylixTheme
                    ? stylixTheme.base05
                    : "white"

                    font.bold: true

                    font.family:
                    stylixTheme
                    ? stylixTheme.fontFamily
                    : "Fira Sans"

                    font.pixelSize:
                    stylixTheme
                    ? stylixTheme.globalFontSize
                    : 20
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: processes.refreshMail()
                }
            }

            Rectangle {
                width: 130
                height: 50

                color:
                stylixTheme
                ? stylixTheme.base02
                : "#2a2a3a"

                radius: 4

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

                    text: "Reply (Enter)"

                    color:
                    stylixTheme
                    ? stylixTheme.base05
                    : "white"

                    font.bold: true

                    font.family:
                    stylixTheme
                    ? stylixTheme.fontFamily
                    : "Fira Sans"

                    font.pixelSize:
                    stylixTheme
                    ? stylixTheme.globalFontSize
                    : 20
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: openReply()
                }
            }

        }

        Rectangle {
            width: parent.width
            height: parent.height - 70

            color: "transparent"

            Flickable {
                anchors.fill: parent

                clip: true

                contentHeight:
                messageText.paintedHeight + 40

                Text {
                    id: messageText

                    width: parent.width

                    text: controller.messageBody

                    wrapMode: Text.Wrap

                    textFormat: Text.PlainText

                    color:
                    stylixTheme
                    ? stylixTheme.base06
                    : "white"

                    font.family:
                    stylixTheme
                    ? stylixTheme.fontFamily
                    : "Fira Sans"

                    font.pixelSize:
                    stylixTheme
                    ? stylixTheme.globalFontSize + 2
                    : 22

                    lineHeight: 1.15
                }
            }
        }
    }
}
