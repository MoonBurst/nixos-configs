import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend"

Item {
    id: viewRoot

    required property PowerEngine engine
    property var theme: null

    signal completed()

    focus: true
    function takeFocus() { forceActiveFocus(); }
    Component.onCompleted: forceActiveFocus()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: (viewRoot.theme && viewRoot.theme.globalPadding) ? viewRoot.theme.globalPadding : 16
        spacing: 10

        Repeater {
            model: engine.allActions
            delegate: Rectangle {
                readonly property bool isSelected: index === engine.selectedIndex
                readonly property bool isConfirming: engine.confirmingId === modelData.id
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: 8
                color: isSelected ? ((theme && theme.base02) ? theme.base02 : "#333") : "transparent"
                border.width: isSelected ? 2.5 : 1
                border.color: isConfirming ? "#ff5555" : (isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#444")

                RowLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 16
                    Text { text: modelData.icon; font.pixelSize: 28 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text {
                            text: isConfirming ? "⚠️ Press [Enter] again to Confirm " + modelData.title : modelData.title
                            font.bold: true; font.pixelSize: 16
                            color: isConfirming ? "#ff5555" : ((theme && theme.base05) ? theme.base05 : "yellow")
                        }
                        Text { text: modelData.description; font.pixelSize: 12; color: "#aaa" }
                    }
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        engine.selectedIndex = index;
                        if (engine.execute(modelData)) viewRoot.completed();
                    }
                }
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            engine.selectedIndex = (engine.selectedIndex + 1) % engine.allActions.length;
            engine.confirmingId = "";
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            engine.selectedIndex = (engine.selectedIndex - 1 + engine.allActions.length) % engine.allActions.length;
            engine.confirmingId = "";
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (engine.execute(engine.allActions[engine.selectedIndex])) viewRoot.completed();
            event.accepted = true;
        }
    }
}
