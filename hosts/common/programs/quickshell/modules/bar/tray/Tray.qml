import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
    id: trayBox

    // Fallback static bindings preserve layout consistency if theme loops are refreshing
    color: (root && root.theme) ? root.theme.base00 : "black"
    radius: 10
    border.width: 3
    border.color: (root && root.theme) ? root.theme.base05 : "yellow"

    // Explicit calculations scale boundaries properly alongside your size 20 font rows
    width: Math.max(45, trayLayoutRow.implicitWidth + 20)
    height: 35
    anchors.verticalCenter: parent.verticalCenter

    property var barWindow: null

    Row {
        id: trayLayoutRow
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: iconDelegateItem
                width: 30
                height: 22
                anchors.verticalCenter: parent.verticalCenter

                property var itemData: modelData

                Image {
                    id: delegateAppletIconImage
                    anchors.fill: parent
                    source: iconDelegateItem.itemData.icon || ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: source != ""
                }

                Text {
                    anchors.centerIn: parent
                    text: iconDelegateItem.itemData.title ? iconDelegateItem.itemData.title.substring(0,2).toUpperCase() : "★"
                    color: (root && root.theme) ? root.theme.base05 : "yellow"
                    font.family: "monospace"
                    font.pixelSize: 20
                    font.bold: true
                    visible: !delegateAppletIconImage.visible
                }

                QsMenuAnchor {
                    id: officialMenuAnchor
                    anchor.window: trayBox.barWindow
                    menu: iconDelegateItem.itemData.menu
                    anchor.edges: PopupAnchor.Bottom | PopupAnchor.Left

                    anchor.rect: {
                        if (trayBox.barWindow) {
                            var globalPoint = iconDelegateItem.mapToItem(trayBox.barWindow.contentItem, 0, 0);
                            return Qt.rect(globalPoint.x, globalPoint.y, iconDelegateItem.width, iconDelegateItem.height);
                        }
                        return Qt.rect(0, 0, 22, 22);
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            iconDelegateItem.itemData.activate();
                        } else if (mouse.button === Qt.RightButton) {
                            if (iconDelegateItem.itemData.hasMenu) {
                                officialMenuAnchor.open();
                            }
                        }
                    }
                }
            }
        }
    }
}
