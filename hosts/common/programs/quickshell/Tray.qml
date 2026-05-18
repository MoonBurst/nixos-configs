import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
    id: trayBox
    color: Theme.colorBaseBg
    radius: Theme.capsuleRadius
    border.width: Theme.capsuleBorderWidth
    border.color: Theme.colorOutline
    
    width: Math.max(45, trayLayoutRow.implicitWidth + 20)
    height: Theme.capsuleHeight
    anchors.verticalCenter: parent.verticalCenter
    
    // FIXED: Adding the missing property back to the active uppercase file
    property var barWindow: null
    
    Row {
        id: trayLayoutRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: iconDelegateItem
                width: 22
                height: 22
                anchors.verticalCenter: parent.verticalCenter

                property var itemData: modelData

                Image {
                    anchors.fill: parent
                    source: iconDelegateItem.itemData.icon || ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: source != ""
                }

                Text {
                    anchors.centerIn: parent
                    text: iconDelegateItem.itemData.title ? iconDelegateItem.itemData.title.substring(0,2).toUpperCase() : "★"
                    color: Theme.colorNormalText
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.bold: true
                    visible: !parent.children.visible
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
