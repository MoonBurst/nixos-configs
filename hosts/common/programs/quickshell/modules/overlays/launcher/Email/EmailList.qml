import QtQuick

Rectangle {
    id: root

    required property QtObject controller
    required property QtObject processes

    property var stylixTheme

    color: stylixTheme ? stylixTheme.base01 : "#1a1a24"
    border.color: stylixTheme ? stylixTheme.base02 : "#333333"
    border.width: stylixTheme ? stylixTheme.globalBorderWidth : 1
    radius: stylixTheme ? stylixTheme.defaultCardRadius : 0

    function openCurrentMessage() {
        var email = controller.emails[emailList.currentIndex]

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
        var mail = controller.emails[emailList.currentIndex]

        if (!mail)
            return

        var tmp = controller.emails.slice()

        tmp.splice(emailList.currentIndex, 1)

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

            color:
                stylixTheme
                    ? stylixTheme.base07
                    : "#aaaaaa"

            font.family:
                stylixTheme
                    ? stylixTheme.fontFamily
                    : "Fira Sans"

            font.pixelSize:
                stylixTheme
                    ? stylixTheme.globalFontSize + 4
                    : 24
        }

        ListView {
            id: emailList

            width: parent.width
            height: parent.height - statusText.height - 20

            model: controller.emails

            clip: true
            spacing: 8

            focus:
                !controller.isReplying &&
                !controller.isComposing

            activeFocusOnTab: true

            onCurrentIndexChanged:
                controller.currentListIndex = currentIndex

            Keys.onUpPressed: {
                if (currentIndex > 0)
                    currentIndex--
            }

            Keys.onDownPressed: {
                if (currentIndex <
                    controller.emails.length - 1)
                    currentIndex++
            }

            Keys.onReturnPressed: {
                if (controller.isReplying ||
                    controller.isComposing)
                    return

                var email =
                    controller.emails[currentIndex]

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
                        emailList.currentIndex = index
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

                        text:
                            modelData.from
                                ? (modelData.from.name ||
                                   modelData.from.addr)
                                : ""

                        color:
                            stylixTheme
                                ? stylixTheme.base08
                                : "#ff6666"

                        font.bold: true

                        font.family:
                            stylixTheme
                                ? stylixTheme.fontFamily
                                : "Fira Sans"

                        font.pixelSize:
                            stylixTheme
                                ? stylixTheme.globalFontSize + 2
                                : 22

                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width - 24

                        text:
                            modelData.subject ||
                            "(No Subject)"

                        color:
                            stylixTheme
                                ? stylixTheme.base05
                                : "white"

                        font.family:
                            stylixTheme
                                ? stylixTheme.fontFamily
                                : "Fira Sans"

                        font.pixelSize:
                            stylixTheme
                                ? stylixTheme.globalFontSize
                                : 20

                        elide: Text.ElideRight
                    }

                    Text {
                        text: modelData.date || ""

                        color:
                            stylixTheme
                                ? stylixTheme.base04
                                : "#999999"

                        font.family:
                            stylixTheme
                                ? stylixTheme.fontFamily
                                : "Fira Sans"

                        font.pixelSize:
                            stylixTheme
                                ? stylixTheme.globalFontSize - 4
                                : 12
                    }
                }
            }
        }
    }
}
