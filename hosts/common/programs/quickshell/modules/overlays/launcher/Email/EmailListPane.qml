import QtQuick

Rectangle {
    id: root

    required property var controller
    required property var stylixTheme
    required property ListView emailList

    color: stylixTheme ? stylixTheme.base01 : "#1a1a24"
    border.color: stylixTheme ? stylixTheme.base02 : "#333333"
    border.width: stylixTheme ? stylixTheme.globalBorderWidth : 1
    radius: stylixTheme ? stylixTheme.defaultCardRadius : 0

    Column {
        anchors.fill: parent
        anchors.margins: stylixTheme ? stylixTheme.globalPadding / 2 : 6
        spacing: stylixTheme ? stylixTheme.globalPadding / 2 : 6

        Text {
            id: statusText

            text: controller.statusText
            color: stylixTheme ? stylixTheme.base07 : "#aaaaaa"

            font.family: stylixTheme
                ? stylixTheme.fontFamily
                : "Fira Sans"

            font.pixelSize: stylixTheme
                ? stylixTheme.globalFontSize + 4
                : 24
        }

        ListView {
            id: listView

            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height - statusText.height - 20

            model: controller.emails

            spacing: 8
            clip: true

            focus: !controller.isReplying && !controller.isComposing
            activeFocusOnTab: true
            highlightFollowsCurrentItem: true

            onCurrentIndexChanged: {
                controller.currentListIndex = currentIndex
            }

            Keys.onUpPressed: {
                if (currentIndex > 0)
                    currentIndex--
            }

            Keys.onDownPressed: {
                if (currentIndex < controller.emails.length - 1)
                    currentIndex++
            }

            Keys.onReturnPressed: {
                if (controller.isReplying || controller.isComposing)
                    return

                var email = controller.emails[currentIndex]

                if (!email)
                    return

                if (controller.selectedId === email.id
                        && controller.messageBody.length > 0) {

                    controller.openReply()

                } else {

                    controller.loadMessage(email.id)
                }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Delete) {
                    controller.deleteCurrentMessage()
                    event.accepted = true
                }
            }

            delegate: Rectangle {
                width: listView.width
                height: 105

                radius: stylixTheme
                    ? stylixTheme.defaultCardRadius - 2
                    : 8

                color: controller.currentListIndex === index
                    ? (stylixTheme
                        ? stylixTheme.base03
                        : "#003399")
                    : "transparent"

                border.width: controller.selectedId === modelData.id
                    ? 2
                    : 0

                border.color: stylixTheme
                    ? stylixTheme.base0A
                    : "#FABD2F"

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        listView.currentIndex = index
                        controller.loadMessage(modelData.id)
                        listView.forceActiveFocus()
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12

                    spacing: 4

                    Text {
                        width: parent.width - 24

                        text: modelData.from
                            ? (modelData.from.name
                               || modelData.from.addr)
                            : ""

                        color: stylixTheme
                            ? stylixTheme.base08
                            : "#ff6666"

                        font.bold: true

                        font.family: stylixTheme
                            ? stylixTheme.fontFamily
                            : "Fira Sans"

                        font.pixelSize: stylixTheme
                            ? stylixTheme.globalFontSize + 2
                            : 22

                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width - 24

                        text: modelData.subject || "(No Subject)"

                        color: stylixTheme
                            ? stylixTheme.base05
                            : "white"

                        font.family: stylixTheme
                            ? stylixTheme.fontFamily
                            : "Fira Sans"

                        font.pixelSize: stylixTheme
                            ? stylixTheme.globalFontSize
                            : 20

                        elide: Text.ElideRight
                    }

                    Text {
                        text: modelData.date || ""

                        color: stylixTheme
                            ? stylixTheme.base04
                            : "#999999"

                        font.family: stylixTheme
                            ? stylixTheme.fontFamily
                            : "Fira Sans"

                        font.pixelSize: stylixTheme
                            ? stylixTheme.globalFontSize - 4
                            : 12
                    }
                }
            }
        }
    }
}
