import QtQuick

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
                width: 160
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
                        ? stylixTheme.base08
                        : "#aa2222"

                radius: 6

                Text {
                    anchors.centerIn: parent
                    text: "Discard"
                    color: "white"
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

        Rectangle {
            width: parent.width
            height: 42

            color:
                stylixTheme
                    ? stylixTheme.base00
                    : "#1a1a2a"

            TextInput {
                id: addressField

                anchors.fill: parent
                anchors.margins: 8

                text: controller.composeToAddress

                color: "white"

                onTextChanged:
                    controller.composeToAddress = text
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

                onTextChanged:
                    controller.composeSubject = text
            }
        }

        Text {
            text: "Message"
            color: "white"
        }

        Rectangle {
            width: parent.width
            height: parent.height - 260

            color:
                stylixTheme
                    ? stylixTheme.base00
                    : "#1a1a2a"

            Flickable {
                anchors.fill: parent
                anchors.margins: 12

                clip: true

                contentHeight:
                    bodyEditor.paintedHeight + 40

                TextEdit {
                    id: bodyEditor

                    width: parent.width

                    text: controller.composeBodyText

                    wrapMode: TextEdit.WrapAnywhere

                    color: "white"

                    font.family: "monospace"

                    font.pixelSize:
                        stylixTheme
                            ? stylixTheme.globalFontSize
                            : 20

                    onTextChanged:
                        controller.composeBodyText = text

                    Keys.onEscapePressed: {
                        controller.isComposing = false
                    }
                }
            }
        }
    }
}
