import QtQuick

Rectangle {
    id: sideRoot

    required property QtObject controller
    required property QtObject processes
    property var stylixTheme

    focus: false
    activeFocusOnTab: false

    color: stylixTheme ? stylixTheme.base01 : "#1a1a24"
    border.color: stylixTheme ? stylixTheme.base02 : "#333345"
    border.width: stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth
    radius: stylixTheme ? stylixTheme.defaultCardRadius : controller.defaultCardRadius

    Keys.onPressed: (event) => {
        if (event.modifiers & Qt.AltModifier) {
            event.accepted = false;
            return;
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: stylixTheme ? (stylixTheme.globalPadding / 2) : (controller.globalPadding / 2)
        spacing: stylixTheme ? (stylixTheme.globalPadding / 2) : (controller.globalPadding / 2)

        Text {
            text: "📭 Mailboxes"
            color: stylixTheme ? stylixTheme.base05 : "white"
            font.bold: true
            font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily
            font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize + 2) : (controller.globalFontSize + 2)
        }

        Repeater {
            model: ["INBOX", "ALL MAIL", "DRAFTS", "SENT MAIL", "SPAM", "STARRED", "IMPORTANT", "TRASH"]

            delegate: Rectangle {
                width: parent.width
                height: stylixTheme ? (stylixTheme.defaultCardHeight * 0.4) : (controller.defaultCardHeight * 0.4)
                radius: stylixTheme ? (stylixTheme.defaultCardRadius - 4) : (controller.defaultCardRadius - 4)

                color: (controller.currentFolder === modelData)
                ? (stylixTheme ? stylixTheme.base02 : "#1a1a1a")
                : "transparent"

                border.width: (controller.currentFolder === modelData)
                ? (stylixTheme ? stylixTheme.globalBorderWidth : controller.globalBorderWidth)
                : 0
                border.color: stylixTheme ? stylixTheme.base05 : "#FABD2F"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: stylixTheme ? (stylixTheme.globalPadding * 0.6) : (controller.globalPadding * 0.6)
                    spacing: stylixTheme ? (stylixTheme.globalPadding / 2) : (controller.globalPadding / 2)

                    Text {
                        text: modelData === "INBOX" ? "📥 "
                        : (modelData === "ALL MAIL" ? "📦 "
                        : (modelData === "DRAFTS" ? "📝 "
                        : (modelData === "SENT MAIL" ? "📤 "
                        : (modelData === "SPAM" ? "🔥 "
                        : (modelData === "STARRED" ? "⭐ "
                        : (modelData === "IMPORTANT" ? "🏷️ " : "🗑️ "))))))
                        font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize - 2) : (controller.globalFontSize - 2)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: modelData
                        color: (controller.currentFolder === modelData) ? "white" : (stylixTheme ? stylixTheme.base04 : "#aaaaaa")
                        font.bold: (controller.currentFolder === modelData)
                        font.family: stylixTheme ? stylixTheme.fontFamily : controller.fontFamily
                        font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : controller.globalFontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    // FIXED: Cleared the invalid .innerListView reference evaluation pointer bug
                    onClicked: {
                        controller.currentFolder = modelData;
                    }
                }
            }
        }
    }
}
