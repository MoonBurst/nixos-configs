import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Item {
    id: tooltipContainer
    anchors.fill: parent

    Shortcut {
        sequence: "Escape"
        enabled: true
        onActivated: {
            musicBox.popupActive = false;
            musicBox.confirmDeleteMode = false;
        }
    }

    Process { id: playPauseProc; command: ["audtool", "playback-playpause"] }
    Process { id: prevProc; command: ["audtool", "playlist-reverse"] }
    Process { id: nextProc; command: ["audtool", "playlist-advance"] }

    Process {
        id: deleteSongProc
        // Using "sh -c" allows Quickshell to correctly pipe commands and execute multi-statement Python code
        command: [
            "sh", "-c",
            "python3 -c \"\n" +
            "import subprocess, os, urllib.parse\n" +
            "try:\n" +
            "    raw_path = subprocess.check_output(['audtool', 'current-song-filename']).decode('utf-8').strip()\n" +
            "    if raw_path.startswith('file://'):\n" +
            "        path = urllib.parse.unquote(raw_path[7:])\n" +
            "    else:\n" +
            "        path = raw_path\n" +
            "    if os.path.exists(path):\n" +
            "        pos = subprocess.check_output(['audtool', 'playlist-position']).decode('utf-8').strip()\n" +
            "        os.remove(path)\n" +
            "        subprocess.run(['audtool', 'playlist-advance'])\n" +
            "        subprocess.run(['audtool', 'playlist-delete', pos])\n" +
            "except Exception as e:\n" +
            "    pass\n" +
            "\""
        ]
        onRunningChanged: {
            if (!running && musicBox.confirmDeleteMode) {
                musicBox.confirmDeleteMode = false
                musicProc.running = false
                musicProc.running = true
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: shell.theme.defaultCardRadius ?? 8
        border.width: shell.theme.globalBorderWidth ?? 3
        color: shell.theme.base00 ?? "black"
        border.color: shell.theme.base05 ?? "yellow"

        Column {
            anchors.fill: parent
            anchors.margins: shell.theme.globalPadding
            spacing: 14

            Rectangle {
                width: parent.width
                height: 90
                radius: shell.theme.defaultCardRadius ?? 8
                border.width: shell.theme.globalBorderWidth ?? 3
                color: "transparent"

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    spacing: 4

                    Text {
                        width: parent.width
                        text: musicBox.tooltipTitle
                        font.family: shell.theme.fontFamily ?? "monospace"
                        font.pixelSize: 18
                        font.bold: true
                        color: musicBox.border.color
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: musicBox.tooltipArtist
                        font.family: shell.theme.fontFamily ?? "monospace"
                        font.pixelSize: 20
                        color: musicBox.border.color
                        opacity: 0.8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: musicBox.trackCountStr
                        font.family: shell.theme.fontFamily ?? "monospace"
                        font.pixelSize: 20
                        color: shell.theme.base05 ?? musicBox.border.color
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24

                Row {
                    spacing: 12
                    visible: !musicBox.confirmDeleteMode

                    Repeater {
                        model: [
                            { icon: "⏮", proc: prevProc },
                            { icon: "⏯", proc: playPauseProc },
                            { icon: "⏭", proc: nextProc }
                        ]

                        delegate: Rectangle {
                            width: 55
                            height: 40
                            radius: shell.theme.defaultCardRadius ?? 4
                            border.width: shell.theme.globalBorderWidth ?? 2
                            color: "transparent"
                            border.color: musicBox.border.color

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.pixelSize: 20
                                color: parent.border.color
                            }

                            TapHandler {
                                onTapped: modelData.proc.running = true
                            }
                        }
                    }

                    Rectangle {
                        width: 55
                        height: 40
                        radius: shell.theme.defaultCardRadius ?? 4
                        border.width: shell.theme.globalBorderWidth ?? 2
                        color: "transparent"
                        border.color: musicBox.border.color

                        Text {
                            anchors.centerIn: parent
                            text: "📂"
                            font.pixelSize: 18
                            color: parent.border.color
                        }

                        TapHandler {
                            onTapped: {
                                Quickshell.execDetached([
                                    "sh", "-c",
                                    "path=$(audtool current-song-filename | sed 's|^file://||'); " +
                                    "clean_path=$(python3 -c \"import urllib.parse, sys; print(urllib.parse.unquote(sys.argv[1]))\" \"$path\"); " +
                                    "[ -d \"$clean_path\" ] || clean_path=$(dirname \"$clean_path\"); " +
                                    "if [ -e \"$clean_path\" ]; then nohup nemo \"$clean_path\" >/dev/null 2>&1 & fi"
                                ])
                                musicBox.popupActive = false
                            }
                        }
                    }
                }

                Rectangle {
                    id: sureButton
                    width: musicBox.confirmDeleteMode ? 140 : 55
                    height: 40
                    radius: shell.theme.defaultCardRadius ?? 4
                    border.width: shell.theme.globalBorderWidth ?? 2

                    color: musicBox.confirmDeleteMode ? "#ff5555" : "transparent"
                    border.color: musicBox.confirmDeleteMode ? "#ffffff" : musicBox.border.color

                    Behavior on width { NumberAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: musicBox.confirmDeleteMode ? "⚠️ Sure?" : "🗑️"
                        font.pixelSize: musicBox.confirmDeleteMode ? 14 : 20
                        font.bold: musicBox.confirmDeleteMode
                        color: parent.border.color
                    }

                    TapHandler {
                        onTapped: {
                            if (!musicBox.confirmDeleteMode) {
                                musicBox.confirmDeleteMode = true
                            } else {
                                deleteSongProc.running = true
                            }
                        }
                    }
                }

                Item {
                    width: 25
                    height: 40
                    visible: musicBox.confirmDeleteMode
                }

                Rectangle {
                    width: 55
                    height: 40
                    radius: shell.theme.defaultCardRadius ?? 4
                    border.width: shell.theme.globalBorderWidth ?? 2
                    color: "transparent"
                    border.color: musicBox.border.color
                    visible: musicBox.confirmDeleteMode

                    Text {
                        anchors.centerIn: parent
                        text: "No"
                        font.pixelSize: 14
                        color: parent.border.color
                    }

                    TapHandler {
                        onTapped: {
                            musicBox.popupActive = false
                            musicBox.confirmDeleteMode = false
                        }
                    }
                }
            }
        }
    }
}
