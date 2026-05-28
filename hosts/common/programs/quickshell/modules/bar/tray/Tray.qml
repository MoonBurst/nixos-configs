//@ pragma UseQApplication

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland

Item {
    id: trayRoot

    property var barWindow: null
    property var activeMenu: null

    width: trayBubbleWrapper.width
    implicitWidth: trayBubbleWrapper.width
    height: parent.height

    Rectangle {
        id: trayBubbleWrapper

        color: shell.theme.base00
        radius: shell.theme.defaultCardRadius
        border.color: shell.theme.base05
        border.width: shell.theme.globalBorderWidth

        width: trayLayoutRow.width + 16
       height: parent.height
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        Row {
            id: trayLayoutRow
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: SystemTray.items

                delegate: Item {
                    id: trayItem
                    width: 25
                    height: 25
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: modelData.icon || ""
                        fillMode: Image.PreserveAspectFit
                    }

                    // -----------------------------
                    // MENU MODEL
                    // -----------------------------
                    QsMenuOpener {
                        id: menuSource
                        menu: modelData.menu
                    }

                    // -----------------------------
                    // MENU POPUP
                    // -----------------------------
                    PanelWindow {
                        id: menuPopup

                        screen: barWindow ? barWindow.screen : null
                        visible: false
                        anchors.top: true
                        anchors.right: true

                        WlrLayershell.layer: WlrLayer.Overlay
                        WlrLayershell.keyboardFocus: menuPopup.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                        margins.top: shell.theme.globalPadding + 55
                        margins.right: {
                            if (!barWindow || !barWindow.contentItem) return shell.theme.globalPadding;
                            var globalIconPos = trayItem.mapToItem(barWindow.contentItem, 0, 0);
                            return barWindow.width - (globalIconPos.x + trayItem.width);
                        }

                        implicitWidth: barWindow ? barWindow.width : 220
                        implicitHeight: 1080
                        color: "transparent"

                        onVisibleChanged: {
                            if (visible) {
                                escapeFocusProxy.forceActiveFocus();
                            } else {

                                if (trayRoot.activeMenu === menuPopup) {
                                    trayRoot.activeMenu = null;
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: menuPopup.visible = false
                        }

                        Item {
                            id: escapeFocusProxy
                            focus: true
                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Escape) {
                                    menuPopup.visible = false;
                                    event.accepted = true;
                                }
                            }
                        }

                        Rectangle {
                            width: 220
                            height: popupLayoutColumn.implicitHeight + 12

                            anchors.top: parent.top
                            anchors.right: parent.right

                            color: shell.theme.base00
                            border.color: shell.theme.base05
                            border.width: shell.theme.globalBorderWidth
                            radius: shell.theme.defaultCardRadius

                            MouseArea {
                                anchors.fill: parent
                                propagateComposedEvents: false
                                onClicked: (mouse) => mouse.accepted = true
                            }

                            Column {
                                id: popupLayoutColumn
                                width: parent.width - 12
                                anchors.centerIn: parent
                                spacing: 4

                                Repeater {
                                    model: menuSource.children

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 38
                                        radius: 6

                                        color: mouse.containsMouse ? shell.theme.base0D : "transparent"

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: globalPadding
                                            text: modelData.text || ""
                                            color:  shell.theme.base05

                                            font.family: shell.theme.fontFamily
                                            font.pixelSize: shell.theme.globalFontSize
                                        }

                                        MouseArea {
                                            id: mouse
                                            anchors.fill: parent
                                            hoverEnabled: true

                                            onClicked: {
                                                modelData.triggered()
                                                menuPopup.visible = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // -----------------------------
                    // INPUT
                    // -----------------------------
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                //  Left click action closes any active menu cleanly
                                if (trayRoot.activeMenu !== null) {
                                    trayRoot.activeMenu.visible = false;
                                }
                                modelData.activate()
                                return
                            }

                            if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                                // If clicking the SAME icon that is already open, toggle it off
                                if (menuPopup.visible) {
                                    menuPopup.visible = false;
                                    return;
                                }

                                // Closes whatever menu is currently open before opening the new one
                                if (trayRoot.activeMenu !== null && trayRoot.activeMenu !== menuPopup) {
                                    trayRoot.activeMenu.visible = false;
                                }

                                // Open this menu and register it as the globally active one
                                menuPopup.visible = true;
                                trayRoot.activeMenu = menuPopup;
                            }
                        }
                    }
                }
            }
        }
    }
}
