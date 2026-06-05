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

    width: 1000
    height: 1000

    z: 99

    radius: stylixTheme ? stylixTheme.defaultCardRadius : 10

    color: stylixTheme
    ? stylixTheme.base01
    : "#0F0F0F"

    border.color: stylixTheme
    ? stylixTheme.base0C
    : "#04f100"

    border.width: stylixTheme
    ? stylixTheme.globalBorderWidth
    : 3

    function sendReply() {
        if (processes.sendRawMessage) {
            processes.sendRawMessage(replyEditor.text)
        } else if (processes.sendRawEmail) {
            processes.sendRawEmail(replyEditor.text)
        } else {
            console.log("No reply send function found")
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: stylixTheme
        ? stylixTheme.globalPadding
        : 20

        spacing: 12

        Row {
            spacing: 12

            Rectangle {
                width: 180
                height: 40

                radius: 6

                color: stylixTheme
                ? stylixTheme.base03
                : "#003399"

                Text {
                    anchors.centerIn: parent

                    text: "Send (Ctrl+Enter)"

                    color: stylixTheme
                    ? stylixTheme.base05
                    : "#F7F700"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: sendReply()
                }
            }

            Rectangle {
                width: 140
                height: 40

                radius: 6

                color: stylixTheme
                ? stylixTheme.base08
                : "#aa2222"

                Text {
                    anchors.centerIn: parent
                    text: "Cancel (Esc)"
                    color: "white"
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        controller.isReplying = false
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: parent.height - 70

            color: stylixTheme
            ? stylixTheme.base00
            : "#1a1a2a"

            Flickable {
                anchors.fill: parent
                anchors.margins: 12

                clip: true

                contentHeight: replyEditor.contentHeight + 20

                TextEdit {
                    id: replyEditor

                    width: parent.width

                    text: controller.replyText

                    wrapMode: TextEdit.Wrap

                    color: stylixTheme
                    ? stylixTheme.base05
                    : "#F7F700"

                    font.family: "monospace"

                    font.pixelSize: stylixTheme
                    ? stylixTheme.globalFontSize + 4
                    : 24

                    onTextChanged: {
                        controller.replyText = text
                    }

                    Keys.onPressed: function(event) {

                        if (event.key === Qt.Key_Escape) {
                            controller.isReplying = false
                            event.accepted = true
                            return
                        }

                        if (event.key === Qt.Key_Return &&
                            (event.modifiers & Qt.ControlModifier)) {

                            sendReply()
                            event.accepted = true
                            return
                            }
                    }
                }
            }
        }
    }


}
