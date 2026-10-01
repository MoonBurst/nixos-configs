import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import "../backend"

Item {
    id: viewRoot

    required property GeminiEngine engine
    property var theme: null

    readonly property int fieldHeight: (shell && shell.settingsManager)
        ? shell.settingsManager.getWindowFieldHeight("gemini", 52) : 52
    readonly property int overlayFontSize: (shell && shell.settingsManager && shell.settingsManager.overlayFontSize > 0)
        ? shell.settingsManager.overlayFontSize : 16

    function clearAndFocus(prompt) {
        if (prompt && prompt.trim() !== "") {
            engine.sendMessage(prompt.trim());
            promptField.clear();
        }
        Qt.callLater(() => promptField.forceActiveFocus());
    }

    Component.onCompleted: Qt.callLater(() => promptField.forceActiveFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => promptField.forceActiveFocus())

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: (viewRoot.theme && viewRoot.theme.globalPadding) ? viewRoot.theme.globalPadding : 16
        spacing: 14

        // Top-anchored vertically centered input box
        Rectangle {
            id: promptBox
            Layout.fillWidth: true
            Layout.preferredHeight: viewRoot.fieldHeight
            Layout.minimumHeight: viewRoot.fieldHeight
            Layout.maximumHeight: viewRoot.fieldHeight
            height: viewRoot.fieldHeight
            radius: 8
            color: (theme && theme.base00) ? theme.base00 : "#11111b"
            border.width: promptField.activeFocus ? 2 : 1
            border.color: promptField.activeFocus ? ((theme && theme.base05) ? theme.base05 : "yellow") : ((theme && theme.base03) ? theme.base03 : "#45475a")

            Text {
                id: aiIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "🤖"
                font.pixelSize: Math.min(26, Math.max(16, parent.height * 0.42))
            }

            TextInput {
                id: promptField
                anchors.left: aiIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                font.pixelSize: Math.min(viewRoot.overlayFontSize + 2, Math.max(13, parent.height * 0.42))
                color: (theme && theme.base05) ? theme.base05 : "yellow"
                selectByMouse: true
                focus: true
                clip: true

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Ask Gemini anything... [Enter to send]"
                    color: (theme && theme.base0B) ? theme.base0B : "#666"
                    font.pixelSize: parent.font.pixelSize
                    font.family: parent.font.family
                    visible: parent.text === "" && !parent.activeFocus
                    elide: Text.ElideRight
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (text.trim() !== "") {
                            engine.sendMessage(text.trim());
                            text = "";
                        }
                        event.accepted = true;
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Context: " + engine.conversationHistory.length + " turns"
                color: (theme && theme.base05) ? theme.base05 : "yellow"; font.bold: true
                Layout.fillWidth: true
            }
            Rectangle {
                width: 110; height: 28; radius: 4; color: "transparent"
                border.color: (theme && theme.base05) ? theme.base05 : "yellow"; border.width: 1
                Text { anchors.centerIn: parent; text: "Clear Context"; color: (theme && theme.base05) ? theme.base05 : "yellow"; font.bold: true; font.pixelSize: 11 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: engine.clearContext() }
            }
        }

        ListView {
            id: chatList
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 12
            model: engine.chatModel
            onCountChanged: chatList.positionViewAtEnd()

            delegate: RowLayout {
                width: chatList.width
                spacing: 8
                layoutDirection: model.role === "user" ? Qt.RightToLeft : Qt.LeftToRight

                Rectangle {
                    Layout.maximumWidth: chatList.width * 0.90
                    implicitWidth: Math.max(msgText.implicitWidth + 32, 140)
                    implicitHeight: msgText.implicitHeight + (model.role === "user" ? 24 : 44)
                    radius: 10
                    color: model.role === "user" ? ((theme && theme.base02) ? theme.base02 : "#333") : ((theme && theme.base00) ? theme.base00 : "#11111b")
                    border.color: model.role === "error" ? "#ff5555" : ((theme && theme.base05) ? theme.base05 : "yellow")
                    border.width: 1.5

                    TextEdit {
                        id: msgText
                        anchors.fill: parent; anchors.margins: 12
                        text: model.text
                        color: model.role === "error" ? "#ff5555" : ((theme && theme.base05) ? theme.base05 : "yellow")
                        font.pixelSize: 14; font.family: "monospace"
                        wrapMode: Text.Wrap; readOnly: true; selectByMouse: true
                    }

                    Rectangle {
                        visible: model.role === "model"
                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6
                        width: 70; height: 22; radius: 4
                        color: (theme && theme.base02) ? theme.base02 : "#333"
                        border.color: (theme && theme.base05) ? theme.base05 : "yellow"; border.width: 1
                        Text { anchors.centerIn: parent; text: "Copy"; font.pixelSize: 10; color: (theme && theme.base05) ? theme.base05 : "yellow" }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.clipboardText = engine.extractCodeOnly(model.text)
                        }
                    }
                }
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }
}
