import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Item {
    id: tooltipContainer
    anchors.fill: parent

    // ==========================================
    // HELPERS & ACTIONS
    // ==========================================

    /**
     * Handles formatting raw track duration seconds into a standard MM:SS string.
     * @param {int} secs - Total seconds to be formatted.
     * @returns {string} Formatted string (e.g., "3:45").
     */
    function formatTime(secs) {
        if (!secs || isNaN(secs) || secs < 0) return "0:00";
        var m = Math.floor(secs / 60);
        var s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }


    Shortcut {
        sequence: "Escape"
        enabled: true
        onActivated: {
            musicBox.popupActive = false;
            musicBox.confirmDeleteMode = false;
        }
    }


    // ==========================================
    // DISK FILE DELETION ACTIONS
    // ==========================================
    Process {
        id: deleteSongProc
        command: [
            "sh", "-c",
            "python3 -c \"\n" +
            "import os, subprocess\n" +
            "try:\n" +
            "    rel_path = '" + musicBox.currentFile + "'\n" +
            "    music_dir = os.path.expanduser('~/Music')\n" +
            "    abs_path = os.path.join(music_dir, rel_path)\n" +
            "    if os.path.exists(abs_path):\n" +
            "        os.remove(abs_path)\n" +
            "except Exception:\n" +
            "    pass\n" +
            "\""
        ]
        onRunningChanged: {
            if (!running && musicBox.confirmDeleteMode) {
                musicBox.confirmDeleteMode = false
                musicBox.mpdIpc.write("next\nstatus\ncurrentsong\n");
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
            spacing: 12

            // Track details block
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

            // Seek / Track Position Slider
            Row {
                width: parent.width
                spacing: 8

                Text {
                    id: currentTimeText
                    text: formatTime(musicBox.elapsedSeconds)
                    font.family: shell.theme.fontFamily ?? "monospace"
                    font.pixelSize: 12
                    color: musicBox.border.color
                    anchors.verticalCenter: parent.verticalCenter
                }

                Slider {
                    id: seekSlider
                    width: parent.width - currentTimeText.width - totalTimeText.width - 16
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: musicBox.totalSeconds > 0 ? musicBox.totalSeconds : 100

                    // handles 2-way binding without breaking when dragged
                    Binding on value {
                        value: musicBox.elapsedSeconds
                        when: !seekSlider.pressed
                    }

                    background: Rectangle {
                        x: seekSlider.leftPadding
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 4
                        width: seekSlider.availableWidth
                        height: implicitHeight
                        radius: 2
                        color: shell.theme.base03 ?? "#333333"

                        Rectangle {
                            width: seekSlider.visualPosition * parent.width
                            height: parent.height
                            color: musicBox.border.color
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 6
                        color: musicBox.border.color
                    }

                    onMoved: {
                        var idx = musicBox.currentTrackIdx - 1;
                        if (idx >= 0) {
                            musicBox.mpdIpc.write("seek " + idx + " " + Math.round(value) + "\nstatus\n");
                        }
                    }
                }

                Text {
                    id: totalTimeText
                    text: formatTime(musicBox.totalSeconds)
                    font.family: shell.theme.fontFamily ?? "monospace"
                    font.pixelSize: 12
                    color: musicBox.border.color
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Volume Control Slider
            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: "🔊"
                    font.pixelSize: 14
                    color: musicBox.border.color
                    anchors.verticalCenter: parent.verticalCenter
                }

                Slider {
                    id: volSlider
                    width: parent.width - 64
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: 100
                    value: musicBox.currentVolume

                    // 2-way binding without breaking when dragged
                    Binding on value {
                        value: musicBox.currentVolume
                        when: !volSlider.pressed
                    }

                    background: Rectangle {
                        x: volSlider.leftPadding
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 4
                        width: volSlider.availableWidth
                        height: implicitHeight
                        radius: 2
                        color: shell.theme.base03 ?? "#333333"

                        Rectangle {
                            width: volSlider.visualPosition * parent.width
                            height: parent.height
                            color: musicBox.border.color
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 6
                        color: musicBox.border.color
                    }

                    onMoved: {
                        // Using "setvol" to set absolute volume level directly
                        musicBox.mpdIpc.write("setvol " + Math.round(value) + "\nstatus\n");
                    }
                }

                Text {
                    text: Math.round(volSlider.value) + "%"
                    font.family: shell.theme.fontFamily ?? "monospace"
                    font.pixelSize: 11
                    color: musicBox.border.color
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Media control buttons
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24

                Row {
                    spacing: 12
                    visible: !musicBox.confirmDeleteMode

                    // Previous Track Button
                    Rectangle {
                        width: 55
                        height: 40
                        radius: shell.theme.defaultCardRadius ?? 4
                        border.width: shell.theme.globalBorderWidth ?? 2
                        color: "transparent"
                        border.color: musicBox.border.color

                        Text {
                            anchors.centerIn: parent
                            text: "⏮"
                            font.pixelSize: 20
                            color: parent.border.color
                        }

                        TapHandler {
                            onTapped: musicBox.mpdIpc.write("previous\nstatus\ncurrentsong\n")
                        }
                    }

                    // Play / Pause Button
                    Rectangle {
                        width: 55
                        height: 40
                        radius: shell.theme.defaultCardRadius ?? 4
                        border.width: shell.theme.globalBorderWidth ?? 2
                        color: "transparent"
                        border.color: musicBox.border.color

                        Text {
                            anchors.centerIn: parent
                            text: musicBox.playbackState === "play" ? "⏸" : "⏯"
                            font.pixelSize: 20
                            color: parent.border.color
                        }

                        TapHandler {
                            onTapped: {
                                if (musicBox.playbackState === "play") {
                                    musicBox.mpdIpc.write("pause 1\nstatus\n");
                                } else if (musicBox.playbackState === "pause") {
                                    musicBox.mpdIpc.write("pause 0\nstatus\n");
                                } else {
                                    musicBox.mpdIpc.write("play\nstatus\n");
                                }
                            }
                        }
                    }

                    // Next Track Button
                    Rectangle {
                        width: 55
                        height: 40
                        radius: shell.theme.defaultCardRadius ?? 4
                        border.width: shell.theme.globalBorderWidth ?? 2
                        color: "transparent"
                        border.color: musicBox.border.color

                        Text {
                            anchors.centerIn: parent
                            text: "⏭"
                            font.pixelSize: 20
                            color: parent.border.color
                        }

                        TapHandler {
                            onTapped: musicBox.mpdIpc.write("next\nstatus\ncurrentsong\n")
                        }
                    }

                    // Directory Folder Opener
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
                                    "abs_path=\"$HOME/Music/" + musicBox.currentFile + "\"; " +
                                    "dir_path=$(dirname \"$abs_path\"); " +
                                    "if [ -d \"$dir_path\" ]; then nohup nemo \"$dir_path\" >/dev/null 2>&1 & fi"
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
