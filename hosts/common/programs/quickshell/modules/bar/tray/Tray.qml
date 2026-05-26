//@ pragma UseQApplication

import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts

import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
    id: trayBox

    color: shell.theme.base00
    height: parent.height
    width: trayLayoutRow.implicitWidth + 20
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth
    border.color: shell.theme.base05
    implicitWidth: trayLayoutRow.implicitWidth + 24
    property var barWindow: null




    Row {
        id: trayLayoutRow

        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: SystemTray.items

            delegate: Item {
                width: 30
                height: 22

                anchors.verticalCenter: parent.verticalCenter

                /*
                 * ICON
                 */

                Image {
                    id: trayIcon

                    anchors.fill: parent

                    source: modelData.icon || ""

                    fillMode: Image.PreserveAspectFit
                    smooth: true

                    visible: source !== ""
                }

                /*
                 * FALLBACK TEXT
                 */

                Text {
                    anchors.centerIn: parent

                    visible: !trayIcon.visible

                    text: modelData.title
                    ? modelData.title.substring(0, 2).toUpperCase()
                    : "★"

                    color: "yellow"

                    font.family: "monospace"
                    font.pixelSize: 20
                    font.bold: true
                }

                /*
                 * MENU ANCHOR
                 */

                QsMenuAnchor {
                    id: officialMenuAnchor

                    anchor.window: trayBox.barWindow

                    menu: modelData.menu

                    anchor.edges:
                    PopupAnchor.Bottom |
                    PopupAnchor.Left

                    anchor.rect: trayBox.barWindow
                    ? Qt.rect(
                        parent.mapToItem(
                            trayBox.barWindow.contentItem,
                            0,
                            0
                        ).x,

                        trayBox.barWindow.implicitHeight,

                        parent.width,
                        parent.height
                    )
                    : Qt.rect(0, 0, 22, 22)
                }

                /*
                 * HOVER EFFECT
                 */

                Rectangle {
                    anchors.fill: parent

                    radius: 6

                    color:
                    mouseArea.containsMouse
                    ? "#22ffff00"
                    : "transparent"

                    z: -1
                }

                /*
                 * INPUT
                 */

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent

                    hoverEnabled: true

                    acceptedButtons:
                    Qt.LeftButton |
                    Qt.RightButton

                    onClicked: (mouse) => {

                        if (mouse.button === Qt.LeftButton) {
                            modelData.activate()
                            return
                        }

                        if (
                            mouse.button === Qt.RightButton &&
                            modelData.hasMenu
                        ) {
                            officialMenuAnchor.open()
                        }
                    }
                }
            }
        }
    }
}
