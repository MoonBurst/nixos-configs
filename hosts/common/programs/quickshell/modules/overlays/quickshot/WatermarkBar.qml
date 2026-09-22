import QtQuick

// Floating top-center input pill with reveal toggle and clear action
Rectangle {
    id: bar

    signal revealClicked()
    signal clearClicked()
    signal accepted()

    width: 480
    height: 36
    radius: 8
    color: Style.panel
    border.color: ShotState.watermarkText.length > 0 ? (Style.selectionBorder || ShotState.strokeColor) : Style.panelBorder
    border.width: 1.5

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: function(mouse) {
            inputField.forceActiveFocus();
            mouse.accepted = true;
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "≋"
            color: ShotState.watermarkText.length > 0 ? Style.accent : Style.text
            font.pixelSize: 18
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 150
            height: parent.height

            TextInput {
                id: inputField
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                text: ShotState.watermarkText
                color: Style.text
                font.family: Style.fontFamily
                font.pixelSize: 13
                selectByMouse: true
                clip: true

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Recipients (e.g. alice, bob, charlie)..."
                    color: "#6c7086"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    visible: !inputField.text && !inputField.activeFocus
                }

                onTextChanged: ShotState.watermarkText = text
                onAccepted: bar.accepted()
            }
        }

        // Reveal/Hide Button
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 86
            height: 24
            radius: 6
            color: ShotState.scanMode ? "#00f0ff" : "#24273a"
            border.color: ShotState.scanMode ? "#00f0ff" : "#494d64"
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 4
                Text { text: "🔍"; font.pixelSize: 11 }
                Text {
                    text: ShotState.scanMode ? "HIDE" : "REVEAL"
                    color: ShotState.scanMode ? "#11111b" : Style.text
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.revealClicked()
            }
        }

        // Clear Button
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "✕"
            color: Style.text
            opacity: 0.6
            font.pixelSize: 12
            visible: inputField.text.length > 0

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    inputField.text = "";
                    bar.clearClicked();
                }
            }
        }
    }
}
