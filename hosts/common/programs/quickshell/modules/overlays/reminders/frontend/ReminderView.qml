import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend"
import "../../../style" as Style
import "../../../common/Utils.js" as Utils

Item {
    id: viewRoot

    required property ReminderEngine engine
    property var theme: null
    property var settingsManager: null

    readonly property int fieldHeight: settingsManager
        ? settingsManager.getWindowFieldHeight("reminders", 48) : 48
    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize : 16

    readonly property int controlBorderWidth: (settingsManager && settingsManager.controlBorderWidth)
        ? settingsManager.controlBorderWidth
        : ((theme && theme.controlBorderWidth) ? theme.controlBorderWidth : 2)

    readonly property var inputPad: Utils.getSafeInputPadding(settingsManager)

    signal completed()

    function clearAndFocus(q) {
        taskInput.text = q || "";
        whenInput.text = "";
        Qt.callLater(() => taskInput.forceActiveFocus());
    }

    Component.onCompleted: Qt.callLater(() => taskInput.forceActiveFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => taskInput.forceActiveFocus())

    function submitReminder() {
        if (taskInput.text.trim() === "" || whenInput.text.trim() === "") return;
        engine.addReminder(taskInput.text, whenInput.text);
        taskInput.text = "";
        whenInput.text = "";
        taskInput.forceActiveFocus();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14

        Text {
            text: "⏰ SCHEDULED CRITICAL REMINDERS"
            font.bold: true
            font.pixelSize: viewRoot.overlayFontSize + 2
            color: (theme && theme.base05) ? theme.base05 : "yellow"
        }

        Item {
            Layout.fillWidth: true
            height: viewRoot.fieldHeight

            Style.ShapeBox {
                id: taskBg
                anchors.fill: parent
                role: "input"
                color: (theme && theme.base00) ? theme.base00 : "#11111b"
                borderColor: taskInput.activeFocus ? ((theme && theme.base05) ? theme.base05 : "yellow") : ((theme && theme.base03) ? theme.base03 : "#45475a")
                borderWidth: viewRoot.controlBorderWidth
                slantWidth: 10
            }

            TextInput {
                id: taskInput
                anchors.fill: parent
                anchors.leftMargin: Math.max(14, taskBg.leftPadding)
                anchors.rightMargin: Math.max(14, taskBg.rightPadding)
                font.pixelSize: viewRoot.overlayFontSize
                color: (theme && theme.base05) ? theme.base05 : "yellow"
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "What to be reminded of..."
                    color: "#666"
                    visible: parent.text === "" && !parent.activeFocus
                    font.pixelSize: viewRoot.overlayFontSize
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) {
                        whenInput.forceActiveFocus();
                        event.accepted = true;
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            height: viewRoot.fieldHeight
            spacing: 10

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Style.ShapeBox {
                    id: whenBg
                    anchors.fill: parent
                    role: "input"
                    color: (theme && theme.base00) ? theme.base00 : "#11111b"
                    borderColor: whenInput.activeFocus ? ((theme && theme.base05) ? theme.base05 : "yellow") : ((theme && theme.base03) ? theme.base03 : "#45475a")
                    borderWidth: viewRoot.controlBorderWidth
                    slantWidth: 10
                }

                TextInput {
                    id: whenInput
                    anchors.fill: parent
                    anchors.leftMargin: Math.max(14, whenBg.leftPadding)
                    anchors.rightMargin: Math.max(14, whenBg.rightPadding)
                    font.pixelSize: viewRoot.overlayFontSize
                    color: (theme && theme.base05) ? theme.base05 : "yellow"
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "When (e.g. 15m, 1h 30m, 5pm, tomorrow 9am)..."
                        color: "#666"
                        visible: parent.text === "" && !parent.activeFocus
                        font.pixelSize: viewRoot.overlayFontSize
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            viewRoot.submitReminder();
                            event.accepted = true;
                        }
                    }
                }
            }

            Item {
                width: 130
                Layout.fillHeight: true

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    slantWidth: 8
                    color: schedHov.hovered ? ((theme && theme.base0C) ? theme.base0C : "#04f100") : ((theme && theme.base02) ? theme.base02 : "#1e1e2e")
                    borderColor: (theme && theme.base0C) ? theme.base0C : "#04f100"
                    borderWidth: viewRoot.controlBorderWidth
                }

                Text {
                    anchors.centerIn: parent
                    text: "+ Schedule"
                    font.bold: true
                    font.pixelSize: 13
                    color: schedHov.hovered ? "#000" : ((theme && theme.base0C) ? theme.base0C : "#04f100")
                }

                HoverHandler { id: schedHov }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: viewRoot.submitReminder()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text { text: "Quick:"; font.bold: true; font.pixelSize: 11; color: "#888" }

            Repeater {
                model: ["5m", "15m", "30m", "1h", "2h", "tomorrow 9am"]
                delegate: Item {
                    width: qTxt.implicitWidth + 20; height: 26

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 4
                        color: qHov.hovered ? ((theme && theme.base05) ? theme.base05 : "yellow") : "transparent"
                        borderColor: (theme && theme.base03) ? theme.base03 : "#45475a"
                        borderWidth: 1
                    }

                    Text {
                        id: qTxt
                        anchors.centerIn: parent
                        text: "+" + modelData
                        font.pixelSize: 11
                        font.bold: true
                        color: qHov.hovered ? "#000" : ((theme && theme.base05) ? theme.base05 : "yellow")
                    }

                    HoverHandler { id: qHov }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            whenInput.text = modelData;
                            whenInput.forceActiveFocus();
                        }
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: (theme && theme.base03) ? theme.base03 : "#45475a" }

        Item {
            visible: engine.remindersList.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent
                text: "No pending reminders scheduled."
                font.pixelSize: viewRoot.overlayFontSize
                color: "#666"
            }
        }

        ListView {
            id: reminderListView
            visible: engine.remindersList.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: engine.remindersList

            delegate: Item {
                width: reminderListView.width - 12
                height: 52

                Style.ShapeBox {
                    id: cardBg
                    anchors.fill: parent
                    role: "input"
                    slantWidth: 8
                    color: (theme && theme.base00) ? theme.base00 : "#11111b"
                    borderColor: (theme && theme.base05) ? theme.base05 : "yellow"
                    borderWidth: 1.5
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.max(14, cardBg.leftPadding)
                    anchors.rightMargin: Math.max(14, cardBg.rightPadding)
                    spacing: 12

                    Text { text: "⏰"; font.pixelSize: 18 }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: modelData.text
                            font.bold: true
                            font.pixelSize: viewRoot.overlayFontSize
                            color: (theme && theme.base05) ? theme.base05 : "yellow"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: modelData.targetStr
                            font.pixelSize: 11
                            color: "#888"
                        }
                    }

                    Rectangle {
                        height: 24; width: cdText.implicitWidth + 14; radius: 4
                        color: "#181825"; border.color: (theme && theme.base0C) ? theme.base0C : "#04f100"; border.width: 1

                        Text {
                            id: cdText
                            anchors.centerIn: parent
                            text: engine.formatRemaining(modelData.targetEpoch)
                            font.bold: true
                            font.pixelSize: 11
                            color: (theme && theme.base0C) ? theme.base0C : "#04f100"
                        }
                    }

                    Rectangle {
                        width: 26; height: 26; radius: 4
                        color: delHov.hovered ? "#ff5555" : "transparent"
                        border.color: "#ff5555"; border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.bold: true
                            font.pixelSize: 12
                            color: delHov.hovered ? "#000" : "#ff5555"
                        }

                        HoverHandler { id: delHov }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: engine.removeReminder(modelData.id)
                        }
                    }
                }
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }
}
