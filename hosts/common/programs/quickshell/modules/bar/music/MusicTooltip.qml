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
            // TRACK DETAILS SECTION (With Dynamic Queue Counter Row)
            // ============================================================================
            Rectangle {
                width: parent.width
                height: 90
                radius: shell.theme.defaultCardRadius ?? 8
                border.width: shell.theme.globalBorderWidth ?? 3
                color: "transparent"
                border.color: parent.border.color

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
                        font.pixelSize: 14
                        color: musicBox.border.color
                        opacity: 0.8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: musicBox.trackCountStr
                        font.family: shell.theme.fontFamily ?? "monospace"
                        font.pixelSize: 12
                        color: shell.theme.base04 ?? musicBox.border.color
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // ============================================================================
            // INTERACTIVE CONTROL BUTTON ROW (CLEAN SIDE-BY-SIDE ALLOCATION)
            // ============================================================================
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 32

                // Normal Media Control Action Setup Layout Array
                Row {
                    spacing: 16
                    visible: !musicBox.confirmDeleteMode

                    Repeater {
                        model: [
                            { icon: "⏮", proc: prevProc },
                            { icon: "⏯", proc: playPauseProc },
                            { icon: "⏭", proc: nextProc }
                        ]

                        delegate: Rectangle {
                            width: 60
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
                                onTargetChanged: modelData.proc.running = true
                            }
                        }
                    }
                }

                // ============================================================================
                // DYNAMIC CONFIRMATION PIECE
                // ============================================================================

                // 1. THE TRASHCAN / "SURE?" BUTTON
                Rectangle {
                    id: sureButton
                    width: musicBox.confirmDeleteMode ? 140 : 60
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
                    width: 60
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
