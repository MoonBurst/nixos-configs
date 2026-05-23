import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: appLauncherRoot

    property alias query: searchField.text
    property var appModel: launcherModel

    signal requestDictionary(string word)
    signal requestLaunch(string command)

    ListModel {
        id: launcherModel

        ListElement {
            name: "Firefox"
            exec: "firefox"
            icon: ""
        }

        ListElement {
            name: "Alacritty"
            exec: "alacritty"
            icon: ""
        }

        ListElement {
            name: "Files"
            exec: "nautilus"
            icon: ""
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000AA"
    }

    Rectangle {
        id: launcherBox

        width: 800
        height: 600
        anchors.centerIn: parent

        radius: 16
        color: launcherRoot.theme.base00

        border.width: 3
        border.color: launcherRoot.theme.base03

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            TextField {
                id: searchField

                width: parent.width
                height: 52

                color: launcherRoot.theme.base05
                font.pixelSize: 20

                placeholderText: "Search applications..."

                background: Rectangle {
                    radius: 12
                    color: launcherRoot.theme.base01
                    border.width: 2
                    border.color: launcherRoot.theme.base08
                }

                onTextChanged: {
                    if (text.indexOf("def ") === 0) {
                        appLauncherRoot.requestDictionary(
                            text.substring(4)
                        )
                    }
                }
            }

            ListView {
                id: appsView

                width: parent.width
                height: parent.height - 80

                spacing: 8
                clip: true

                model: launcherModel

                delegate: Rectangle {
                    width: appsView.width
                    height: 56
                    radius: 10

                    color: mouseArea.containsMouse
                    ? launcherRoot.theme.base02
                    : launcherRoot.theme.base01

                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 14

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            color: launcherRoot.theme.base03

                            Text {
                                anchors.centerIn: parent
                                text: name.charAt(0)
                                color: launcherRoot.theme.base05
                                font.pixelSize: 16
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: name
                                color: launcherRoot.theme.base05
                                font.pixelSize: 20
                                font.bold: true
                            }

                            Text {
                                text: exec
                                color: launcherRoot.theme.base07
                                font.pixelSize: 14
                            }
                        }
                    }

                    MouseArea {
                        id: mouseArea

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appLauncherRoot.requestLaunch(exec)
                        }
                    }
                }
            }
        }
    }
}
