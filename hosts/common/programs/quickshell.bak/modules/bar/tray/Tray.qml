import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
    id: trayBox
    color: "black"; radius: 10; border.width: 3; border.color: "yellow"
    width: Math.max(45, trayLayoutRow.implicitWidth + 20); height: 35
    property var barWindow: null

    Row {
        id: trayLayoutRow; anchors.centerIn: parent; spacing: 5
        Repeater {
            model: SystemTray.items
            delegate: Item {
                width: 30; height: 22; anchors.verticalCenter: parent.verticalCenter
                Image { anchors.fill: parent; source: modelData.icon || ""; fillMode: Image.PreserveAspectFit; smooth: true; visible: source != "" }
                Text { anchors.centerIn: parent; text: modelData.title ? modelData.title.substring(0,2).toUpperCase() : "★"; color: "yellow"; font.family: "monospace"; font.pixelSize: 20; font.bold: true; visible: !parent.children[0].visible }
                QsMenuAnchor { id: officialMenuAnchor; anchor.window: trayBox.barWindow; menu: modelData.menu; anchor.edges: PopupAnchor.Bottom | PopupAnchor.Left
                    anchor.rect: trayBox.barWindow ? Qt.rect(parent.mapToItem(trayBox.barWindow.contentItem, 0, 0).x, trayBox.barWindow.implicitHeight, parent.width, parent.height) : Qt.rect(0,0,22,22)
                }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => { if (mouse.button === Qt.LeftButton) modelData.activate(); else if (mouse.button === Qt.RightButton && modelData.hasMenu) officialMenuAnchor.open(); }
                }
            }
        }
    }
}
