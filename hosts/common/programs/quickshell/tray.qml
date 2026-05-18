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

                Image {
                    anchors.fill: parent
                    source: modelData.icon || ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: source != ""
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.title ? modelData.title.substring(0,2).toUpperCase() : "★"
                    color: Theme.colorNormalText
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.bold: true
                    visible: !parent.children.visible
                }

                Menu {
                    id: nativeRightClickMenu
                    
                    Instantiator {
                        model: modelData.menu
                        
                        delegate: MenuItem {
                            text: model.label || ""
                            enabled: model.enabled !== false
                            checkable: model.checkable || false
                            checked: model.checked || false
                            
                            onTriggered: {
                                model.trigger();
                            }
                        }
                        
                        onObjectAdded: (index, object) => nativeRightClickMenu.insertItem(index, object)
                        onObjectRemoved: (index, object) => nativeRightClickMenu.removeItem(object)
                    }
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onTapped: (eventPoint) => {
                        if (eventPoint.button === Qt.LeftButton) {
                            modelData.activate();
                        } else if (eventPoint.button === Qt.RightButton) {
                            nativeRightClickMenu.popup(iconDelegateItem, 0, iconDelegateItem.height + 6);
                        }
                    }
                }

                HoverHandler { id: iconHover }
                ToolTip {
                    visible: iconHover.hovered; delay: 200
                    contentItem: Text { 
                        text: modelData.title || modelData.id || "Background App"
                        color: Theme.colorNormalText 
                        font.family: "monospace"
                        font.pixelSize: 12 
                    }
                    background: Rectangle { 
                        color: Theme.colorBaseBg 
                        border.color: "#003399" 
                        border.width: Theme.capsuleBorderWidth 
                        radius: 4 
                    }
                }
            }
        }
    }
}
