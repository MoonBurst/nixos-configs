import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: launcherRoot

    property var shell

    anchors.fill: parent

    visible: false
    enabled: visible

    color: "#00000088"

    focus: visible

    Keys.onEscapePressed: {
        close()
    }

    ListModel {
        id: launcherModel
    }

    ListModel {
        id: filteredModel
    }

    function refreshFilter() {
        filteredModel.clear()

        let query = searchField.text.toLowerCase()

        for (let i = 0; i < launcherModel.count; ++i) {
            let app = launcherModel.get(i)

            if (
                query === "" ||
                app.name.toLowerCase().includes(query)
            ) {
                filteredModel.append(app)
            }
        }
    }

    function launch(command) {
        console.log("Launching:", command)

        Quickshell.execDetached([
            "sh",
            "-c",
            command
        ])

        launcherRoot.visible = false
    }


IpcHandler {
    target: "launcher"

    function open() {
        launcherRoot.visible = true

        if (launcherRoot.visible) {
            searchField.forceActiveFocus()
        }

        console.log("IPC OPEN:", launcherRoot.visible)
    }

    function close() {
        launcherRoot.visible = false

        console.log("IPC CLOSE:", launcherRoot.visible)
    }

    function toggle() {
        launcherRoot.visible = !launcherRoot.visible

        if (launcherRoot.visible) {
            searchField.forceActiveFocus()
        }

        console.log("IPC TOGGLE:", launcherRoot.visible)
    }

    function clipboard() {
        console.log("IPC CLIPBOARD")
    }
}
    Process {
        id: appLoader

        command: [
            "sh",
            "-c",
            "
            find \
            /run/current-system/sw/share/applications \
            $HOME/.local/share/applications \
            -name '*.desktop' 2>/dev/null |

            while read -r file; do

                name=$(grep -m1 '^Name=' \"$file\" | cut -d= -f2-)
                exec_cmd=$(grep -m1 '^Exec=' \"$file\" | cut -d= -f2-)
                icon=$(grep -m1 '^Icon=' \"$file\" | cut -d= -f2-)

                exec_cmd=$(printf '%s\n' \"$exec_cmd\" | \
                sed -E 's/[[:space:]]+%[fFuUdDnNickvm]//g')

                exec_cmd=$(echo \"$exec_cmd\" | sed 's/^ *//;s/ *$//')

                [ -z \"$name\" ] && continue
                [ -z \"$exec_cmd\" ] && continue

                [ -z \"$icon\" ] && icon='application-x-executable'

                echo \"$name|$exec_cmd|$icon\"

                done
                "
        ]

        stdout: SplitParser {
            onRead: function(data) {
                let lines = data.trim().split("\n")

                for (let i = 0; i < lines.length; ++i) {
                    let parts = lines[i].split("|")

                    if (parts.length < 3)
                        continue

                        launcherModel.append({
                            "name": parts[0],
                            "exec": parts[1],
                            "icon": parts[2]
                        })
                }

                refreshFilter()
            }
        }

        running: true
    }

    Rectangle {
        width: 800
        height: 600

        anchors.centerIn: parent

        radius: 12

        color: shell.theme.base01

        border.width: 3
        border.color: shell.theme.base03

        Column {
            anchors.fill: parent
            anchors.margins: 20

            spacing: 16

            TextField {
                id: searchField

                width: parent.width
                height: 50

                color: shell.theme.base08

                font.pixelSize: 20

                background: Rectangle {
                    radius: 8

                    color: "transparent"

                    border.width: 2
                    border.color: shell.theme.base03
                }

                onTextChanged: {
                    refreshFilter()

                    if (text.startsWith("def ")) {
                        console.log("Dictionary mode:", text)
                    }
                }

                Keys.onEscapePressed: {
                    launcherRoot.close()
                }

                Keys.onReturnPressed: {
                    if (filteredModel.count > 0) {
                        launch(filteredModel.get(0).exec)
                    }
                }
            }

            ListView {
                width: parent.width
                height: parent.height - 70

                clip: true

                spacing: 4

                model: filteredModel

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 56

                    radius: 8

                    color: mouse.containsMouse
                    ? shell.theme.base02
                    : "transparent"

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 16

                        spacing: 16

                        Text {
                            text: "◉"

                            color: shell.theme.base05

                            font.pixelSize: 18
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            spacing: 2

                            Text {
                                text: model.name

                                color: shell.theme.base05

                                font.pixelSize: 20
                            }

                            Text {
                                text: model.exec

                                color: shell.theme.base07

                                font.pixelSize: 14
                            }
                        }
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent

                        hoverEnabled: true

                        onClicked: {
                            launch(model.exec)
                        }
                    }
                }
            }
        }
    }
}
