import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Services.Apps

Item {
    id: launcherRoot
    anchors.fill: parent

    signal requestClose()

    Rectangle {
        anchors.fill: parent
        color: (root && root.theme && root.theme.base00 !== undefined) ? root.theme.base00.toString() : "black"
        opacity: 0.95
    }

    AppsModel {
        id: systemAppsMasterRegistry
        filter: searchInputField.text
    }

    Column {
        anchors.centerIn: parent
        spacing: 30
        width: 800

        TextField {
            id: searchInputField
            width: parent.width
            height: 50

            font.family: "monospace"
            font.pixelSize: 24
            font.bold: true

            color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"

            background: Rectangle {
                color: "black"
                border.width: 3
                border.color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"
                radius: 8
            }

            Component.onCompleted: {
                searchInputField.forceActiveFocus();
            }

            Keys.onEscapePressed: launcherRoot.requestClose()
            
            Keys.onEnterPressed: {
                if (systemAppsMasterRegistry.count > 0) {
                    var topMatchApp = systemAppsMasterRegistry.get(0);
                    if (topMatchApp && typeof topMatchApp.launch === "function") {
                        topMatchApp.launch();
                    }
                    launcherRoot.requestClose();
                }
            }
        }

        GridView {
            id: appLaunchGrid
            width: parent.width
            height: 500
            cellWidth: 200
            cellHeight: 120
            clip: true

            model: systemAppsMasterRegistry

            delegate: Rectangle {
                width: 180
                height: 100
                color: "black"
                border.width: 3
                border.color: appMouseArea.hovered
                    ? ((root && root.theme && root.theme.base0C !== undefined) ? root.theme.base0C.toString() : "#04f100")
                    : ((root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow")
                radius: 8

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter

                    Image {
                        width: 32
                        height: 32
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: (modelData && modelData.icon) ? "image://icon/" + modelData.icon : ""
                        fillMode: Image.PreserveAspectFit
                        visible: source != ""
                    }

                    Text {
                        text: modelData ? modelData.name : "App"
                        font.family: "monospace"
                        font.pixelSize: 20
                        font.bold: true
                        color: "white"
                        elide: Text.ElideRight
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                HoverHandler { id: appMouseArea }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (modelData && typeof modelData.launch === "function") {
                            modelData.launch();
                        }
                        launcherRoot.requestClose();
                    }
                }
            }
        }
    }
}
