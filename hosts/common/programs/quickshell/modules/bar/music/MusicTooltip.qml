import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Item {
    id: tooltipContainer
    anchors.fill: parent

    // Scoped shortcut catches Escape cleanly across all tab button views
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

    // FIXED: Correctly handles paths without file:// and explicitly launches Nemo
    Process {
        id: openFolderProc
        command: [
            "python3", "-c",
            "import subprocess, os, urllib.parse;\n" +
            "try:\n" +
            "    path = subprocess.check_output(['audtool', 'current-song-filename']).decode('utf-8').strip()\n" +
            "    if path.startswith('file://'): path = path[7:]\n" +
            "    clean_path = urllib.parse.unquote(path)\n" +
            "    if os.path.exists(clean_path):\n" +
            "        folder = os.path.dirname(os.path.abspath(clean_path))\n" +
            "        subprocess.Popen(['nemo', folder], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n" +
            "except Exception as e: pass"
        ]
    }

    Process {
        id: deleteSongProc
        command: [
            "python3", "-c",
            "import subprocess, os, urllib.parse; " +
            "try: " +
            "    path = subprocess.check_output(['audtool', 'current-song-filename']).decode('utf-8').strip(); " +
            "    if path.startswith('file://'): path = urllib.parse.unquote(path[7:]); " +
            "    if os.path.exists(path): " +
            "        pos = subprocess.check_output(['audtool', 'playlist-position']).decode('utf-8').strip(); " +
            "        os.remove(path); " +
            "        subprocess.run(['audtool', 'playlist-advance']); " +
            "        subprocess.run(['audtool', 'playlist-delete', pos]); " +
            "except Exception as e: pass"
        ]
        onRunningChanged: {
            if (!running) {
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
            anchors.margins: 20
            spacing: 14

            // ============================================================================
            // TRACK DETAILS SECTION
            // ============================================================================
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
            // ============================================================================
            // INTERACTIVE CONTROL BUTTON ROW
            // ============================================================================
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24

                // Normal Media Control Action Setup Layout Array
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

                    // Open File Location Button
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
                            onTapped: openFolderProc.running = true
                        }
                    }
                }

                // ============================================================================
                // DYNAMIC CONFIRMATION PIECE
                // ============================================================================

                // 1. THE TRASHCAN / "SURE?" BUTTON
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

                // 2. THE EXTRA 25PX LAYOUT SPACER
                Item {
                    width: 25
                    height: 40
                    visible: musicBox.confirmDeleteMode
                }

                // 3. THE CANCEL "NO" BUTTON
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
                        onTapped: musicBox.confirmDeleteMode = false
                    }
                }
            }
        }
    }
}
