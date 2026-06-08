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
    property bool isExpanded: false

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

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
        }

        RowLayout {
            id: trayLayoutRow
            anchors.centerIn: parent
            spacing: 10

            Item {
                id: expandToggleBtn
                width: 20
                height: 20
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: trayRoot.isExpanded ? "▶" : "◀"
                    color: shell.theme.base05
                    font.pixelSize: shell.theme.globalFontSize || 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        trayRoot.isExpanded = !trayRoot.isExpanded;
                        if (!trayRoot.isExpanded && trayRoot.activeMenu !== null) {
                            trayRoot.activeMenu.visible = false;
                        }
                    }
                }
            }

            // RowLayout allows seamless runtime layout space collapsing
            RowLayout {
                id: repeaterContainer
                spacing: 10
                Layout.alignment: Qt.AlignVCenter

                visible: opacity > 0
                opacity: trayRoot.isExpanded ? 1.0 : 0.0
                clip: true

                // Safe structural collapse replacement using attached Layout bounds
                Layout.preferredWidth: trayRoot.isExpanded ? -1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                Repeater {
                    model: SystemTray.items
                    delegate: trayItemDelegate
                }
            }
        }
    }
    Component {
        id: trayItemDelegate

        Item {
            id: trayItem
            width: 25
            height: 25

            Image {
                anchors.fill: parent
                source: modelData.iconName ? "image://icon/" + modelData.iconName : (modelData.icon || "")
                fillMode: Image.PreserveAspectFit
            }

            QsMenuOpener {
                id: menuSource
                menu: modelData.menu
            }

            PanelWindow {
                id: menuPopup
                screen: barWindow ? barWindow.screen : null
                visible: false

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
                        onClicked: (mouse) => { mouse.accepted = true; }
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
                                color: itemMouseArea.containsMouse ? shell.theme.base0D : "transparent"

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: shell.theme.globalPadding
                                    text: modelData.text || ""
                                    color: shell.theme.base05
                                    font.family: shell.theme.fontFamily
                                    font.pixelSize: shell.theme.globalFontSize
                                }

                                MouseArea {
                                    id: itemMouseArea
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

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        if (trayRoot.activeMenu !== null) {
                            trayRoot.activeMenu.visible = false;
                        }
                        modelData.activate()
                        return
                    }
                    if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                        if (menuPopup.visible) {
                            menuPopup.visible = false;
                            return;
                        }
                        if (trayRoot.activeMenu !== null && trayRoot.activeMenu !== menuPopup) {
                            trayRoot.activeMenu.visible = false;
                        }
                        menuPopup.visible = true;
                        trayRoot.activeMenu = menuPopup;
                    }
                }
            }
        }
    }
}
