
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: launcherRoot
    property var shell
    property var launcherWindow
    anchors.fill: parent
    color: "#00000088"
    focus: visible
    enabled: visible

    property string currentDefinition: ""

    function open() {
        launcherWindow.visible = true
        if (launcherWindow.visible) {
            searchField.forceActiveFocus()
        }
        console.log("IPC OPEN:", launcherWindow.visible)
    }

    function close() {
        launcherWindow.visible = false
        searchField.text = ""
        console.log("IPC CLOSE:", launcherWindow.visible)
    }

    function toggle() {
        launcherWindow.visible = !launcherWindow.visible
        if (launcherWindow.visible) {
            searchField.forceActiveFocus()
        } else {
            searchField.text = ""
        }
        console.log("IPC TOGGLE:", launcherWindow.visible)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            close()
        }
    }

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
        close()
    }


    IpcHandler {
        target: "launcher"
        function open() {
            launcherRoot.open()
        }

        function close() {
            launcherRoot.close()
        }

        function toggle() {
            launcherRoot.toggle()
        }

        function clipboard() {
            console.log("IPC CLIPBOARD")
        }

    }

    Process {
        id: dictionaryProcess
        stdout: SplitParser {
            onRead: data => {
                launcherRoot.currentDefinition = data.trim() ? data : "No definition found."
            }
        }
    }

    Process {
        id: appLoader
        command: [
            "sh",
            "-c",
            "\n            find \\\n            /run/current-system/sw/share/applications \\\n            $HOME/.local/share/applications \\\n            -name '*.desktop' 2>/dev/null |\n            while read -r file; do\n                name=$(grep -m1 '^Name=' \"$file\" | cut -d= -f2-)\n\n                exec_cmd=$(grep -m1 '^Exec=' \"$file\" | cut -d= -f2-)\n                icon=$(grep -m1 '^Icon=' \"$file\" | cut -d= -f2-)\n\n                exec_cmd=$(printf '%s\\n' \"$exec_cmd\" | \\\n                sed -E 's/[[:space:]]+%[fFuUdDnNickvm]//g')\n\n                exec_cmd=$(echo \"$exec_cmd\" | sed 's/^ *//;s/ *$//')\n\n                [ -z \"$name\" ] && continue\n                [ -z \"$exec_cmd\" ] && continue\n\n                [ -z \"$icon\" ] && icon='application-x-executable'\n\n                echo \"$name|$exec_cmd|$icon\"\n\n                done\n                "
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

        MouseArea {
            anchors.fill: parent
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20

            spacing: 16

            TextField {
                id: searchField

                width: parent.width
                height: 50

                color: shell.theme.base05
                activeFocusOnPress: false

                font.pixelSize: 20

                background: Rectangle {
                    radius: 8

                    color: "transparent"

                    border.width: 2
                    border.color: shell.theme.base03
                }

                onTextChanged: {
                    if (searchField.text.startsWith("def ")) {
                        listView.visible = false
                        dictionaryView.visible = true
                        let word = searchField.text.substring(4).trim()
                        if (word.length > 0) {
                            launcherRoot.currentDefinition = "Loading definition for '" + word + "'..."
                            dictionaryProcess.command = ["sh", "-c", `dict "${word}" 2>/dev/null || echo "No definition found."`]
                            dictionaryProcess.running = true
                        } else {
                            launcherRoot.currentDefinition = "Enter a word to define."
                        }
                    } else {
                        launcherRoot.currentDefinition = ""
                        listView.visible = true
                        dictionaryView.visible = false
                        refreshFilter()
                        if (filteredModel.count > 0) {
                            listView.currentIndex = 0
                        }
                    }
                }

                Keys.onUpPressed: {
                    if (listView.visible && listView.currentIndex > 0) {
                        listView.currentIndex--
                    }
                }

                Keys.onDownPressed: {
                    if (listView.visible && listView.currentIndex < listView.count - 1) {
                        listView.currentIndex++
                    }
                }

                Keys.onEscapePressed: {
                    close()
                }

                Keys.onReturnPressed: {
                    if (listView.visible && listView.currentIndex >= 0) {
                        launch(filteredModel.get(listView.currentIndex).exec)
                    }
                }
            }

            ListView {
                id: listView
                width: parent.width
                height: parent.height - 70

                clip: true

                spacing: 4

                model: filteredModel
                focus: true

                Keys.onReturnPressed: {
                    if (currentIndex >= 0) {
                        launch(filteredModel.get(currentIndex).exec)
                    }
                }

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 56

                    radius: 8

                    color: ListView.isCurrentItem
                    ? shell.theme.base02
                    : (mouse.containsMouse ? shell.theme.base02 : "transparent")

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
            ScrollView {
                id: dictionaryView
                width: parent.width
                height: parent.height - 70
                visible: false
                clip: true

                Text {
                    width: parent.width - 10
                    text: launcherRoot.currentDefinition
                    color: shell.theme.base05
                    wrapMode: Text.WordWrap
                    font.pixelSize: 16
                }
            }
        }
    }
}
