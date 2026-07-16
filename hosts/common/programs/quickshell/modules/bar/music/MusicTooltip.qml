import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../../style"

Item {
    id: tooltipContainer
    anchors.fill: parent

    implicitHeight: 420
    readonly property real tooltipSlantWidth: implicitHeight * tooltipBg.slantRatio
    implicitWidth: 408 + (tooltipSlantWidth * 2)

    // Force parent PanelWindow to expand to correct slanted dimensions
    Binding {
        target: tooltipContainer.Window.window
        property: "width"
        value: tooltipContainer.implicitWidth
    }
    Binding {
        target: tooltipContainer.Window.window
        property: "height"
        value: tooltipContainer.implicitHeight
    }

    // Helpers and Actions
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

    //File Deleter
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

    // Tooltip Background and slant geometry
    SlantedBox {
        id: tooltipBg
        anchors.fill: parent
        slantLeft: "Left"
        slantRight: "Left"
        slantWidth: tooltipContainer.tooltipSlantWidth

        color: (shell && shell.theme) ? (shell.theme.base00 || "black") : "black"
        borderColor: (shell && shell.theme) ? (shell.theme.base05 || "yellow") : "yellow"
        borderWidth: (shell && shell.theme) ? (shell.theme.globalBorderWidth || 3) : 3

        readonly property real slantRatio: (musicBox && musicBox.height > 0) ? (shell.theme.slantWidth / musicBox.height) : 0.35
        readonly property color colorBase05: (shell && shell.theme) ? (shell.theme.base05 || "yellow") : "yellow"
        readonly property color colorBase03: (shell && shell.theme) ? (shell.theme.base03 || "#333333") : "#333333"
        readonly property color colorBase02: (shell && shell.theme) ? (shell.theme.base02 || "#222222") : "#222222"
        readonly property string fontFamily: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"
    }


    Item {
        id: trackDetailsBlock
        y: 45
        x: (y * tooltipBg.slantRatio) + 24
        width: tooltipBg.width - tooltipContainer.tooltipSlantWidth - 48
        height: 110

        SlantedBox {
            id: blockBg
            anchors.fill: parent
            slantLeft: "Left"
            slantRight: "Left"
            slantWidth: parent.height * tooltipBg.slantRatio
            borderColor: tooltipBg.colorBase05
            color: "transparent"
        }

        // Staggered Title Text inside Track block
        Text {
            id: titleText
            y: 18
            x: (63 * tooltipBg.slantRatio) + 12 // Absolute Y = 45 + 18 = 63
            width: parent.width - (parent.height * tooltipBg.slantRatio) - 24
            text: musicBox.tooltipTitle && musicBox.tooltipTitle !== "" ? musicBox.tooltipTitle : musicBox.trackStr
            font.family: tooltipBg.fontFamily
            font.pixelSize: 18
            font.bold: true
            color: tooltipBg.colorBase05
            elide: Text.ElideRight
        }

        // Staggered Artist Text inside Track block
        Text {
            id: artistText
            y: 48
            x: (93 * tooltipBg.slantRatio) + 12 // Absolute Y = 45 + 48 = 93
            width: parent.width - (parent.height * tooltipBg.slantRatio) - 24
            text: musicBox.tooltipArtist && musicBox.tooltipArtist !== "" ? musicBox.tooltipArtist : "Unknown Artist"
            font.family: tooltipBg.fontFamily
            font.pixelSize: 20
            color: tooltipBg.colorBase05
            opacity: 0.8
            elide: Text.ElideRight
        }

        // Staggered Track Count Text inside Track block
        Text {
            id: countText
            y: 78
            x: (123 * tooltipBg.slantRatio) + 12
            width: parent.width - (parent.height * tooltipBg.slantRatio) - 24
            text: musicBox.trackCountStr
            font.family: tooltipBg.fontFamily
            font.pixelSize: 20
            color: tooltipBg.colorBase05
        }
    }

    // Slanted Seek / Track Position Slider
    Row {
        y: 185
        x: (y * tooltipBg.slantRatio) + 24
        width: tooltipBg.width - tooltipContainer.tooltipSlantWidth - 48
        spacing: 8

        Text {
            id: currentTimeText
            text: formatTime(musicBox.elapsedSeconds)
            font.family: tooltipBg.fontFamily
            font.pixelSize: 12
            color: tooltipBg.colorBase05
            anchors.verticalCenter: parent.verticalCenter
        }

        Slider {
            id: seekSlider
            width: parent.width - currentTimeText.width - totalTimeText.width - 16
            anchors.verticalCenter: parent.verticalCenter
            from: 0
            to: musicBox.totalSeconds > 0 ? musicBox.totalSeconds : 100
            value: musicBox.elapsedSeconds

            // Slanted background track
            background: SlantedBox {
                id: seekTrackBg
                implicitWidth: 200
                implicitHeight: 10
                width: seekSlider.availableWidth
                height: implicitHeight
                slantLeft: "Left"
                slantRight: "Left"
                slantWidth: 14
                color: tooltipBg.colorBase03
                borderColor: "transparent"

                // Filled Progress Track
                SlantedBox {
                    id: seekFillShape
                    height: parent.height
                    width: Math.max(16, seekSlider.visualPosition * parent.width)
                    visible: width > 0
                    slantLeft: "Left"
                    slantRight: "Left"
                    slantWidth: 14
                    color: tooltipBg.colorBase05
                    borderColor: "transparent"
                }
            }

            // Slanted Handle (Thumb)
            handle: SlantedBox {
                id: seekThumb
                x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                implicitWidth: 16
                implicitHeight: 16
                slantLeft: "Left"
                slantRight: "Left"
                slantWidth: 10
                color: tooltipBg.colorBase05
                borderColor: tooltipBg.colorBase05
            }

            onMoved: {
                var idx = musicBox.currentTrackIdx - 1;
                if (idx >= 0) {
                    musicBox.mpdIpc.write("seek " + idx + " " + Math.round(value) + "\nstatus\n");
                }
            }
        }

        Binding {
            target: seekSlider
            property: "value"
            value: musicBox.elapsedSeconds
            when: !seekSlider.pressed
        }

        Text {
            id: totalTimeText
            text: formatTime(musicBox.totalSeconds)
            font.family: tooltipBg.fontFamily
            font.pixelSize: 12
            color: tooltipBg.colorBase05
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Slanted Volume Control Slider
    Row {
        y: 240
        x: (y * tooltipBg.slantRatio) + 24
        width: tooltipBg.width - tooltipContainer.tooltipSlantWidth - 48
        spacing: 8

        Text {
            text: "VOL"
            font.pixelSize: 20
            color: tooltipBg.colorBase05
            anchors.verticalCenter: parent.verticalCenter
        }

        Slider {
            id: volSlider
            width: parent.width - 64
            anchors.verticalCenter: parent.verticalCenter
            from: 0
            to: 100
            value: musicBox.currentVolume

            Binding on value {
                value: musicBox.currentVolume
                when: !volSlider.pressed
            }

            // Slanted background track
            background: SlantedBox {
                id: volTrackBg
                implicitWidth: 200
                implicitHeight: 10
                width: volSlider.availableWidth
                height: implicitHeight
                slantLeft: "Left"
                slantRight: "Left"
                slantWidth: 14
                color: tooltipBg.colorBase03
                borderColor: "transparent"

                // Filled Progress Track
                SlantedBox {
                    id: volFillShape
                    height: parent.height
                    width: Math.max(16, volSlider.visualPosition * parent.width)
                    visible: width > 0
                    slantLeft: "Left"
                    slantRight: "Left"
                    slantWidth: 14
                    color: tooltipBg.colorBase05
                    borderColor: "transparent"
                }
            }

            // Slanted Handle (Thumb)
            handle: SlantedBox {
                id: volThumb
                x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                implicitWidth: 16
                implicitHeight: 16
                slantLeft: "Left"
                slantRight: "Left"
                slantWidth: 10
                color: tooltipBg.colorBase05
                borderColor: tooltipBg.colorBase05
            }

            onMoved: {
                musicBox.mpdIpc.write("setvol " + Math.round(value) + "\nstatus\n");
            }
        }

        Text {
            text: Math.round(volSlider.value) + "%"
            font.family: tooltipBg.fontFamily
            font.pixelSize: 11
            color: tooltipBg.colorBase05
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    //  Media Control Buttons Row
    Row {
        y: 295
        x: (y * tooltipBg.slantRatio) + 24
        width: tooltipBg.width - tooltipContainer.tooltipSlantWidth - 48
        spacing: 10

        // Dummy item to dynamically center the enlarged buttons inside the wider container
        Item {
            width: {
                var totalBtnWidth = musicBox.confirmDeleteMode
                ? (sureButton.width + 10 + 25 + 10 + noButton.width)
                : (prevButton.width + 10 + playButton.width + 10 + nextButton.width + 10 + folderButton.width + 10 + sureButton.width);
                return Math.max(0, (parent.width - totalBtnWidth) / 2);
            }
            height: 50
        }

        Row {
            spacing: 10
            visible: !musicBox.confirmDeleteMode

            // Previous Track Button (Enlarged to 100x50px)
            Item {
                id: prevButton
                width: 100
                height: 50
                readonly property real btnSlantWidth: height * tooltipBg.slantRatio

                SlantedBox {
                    anchors.fill: parent
                    slantLeft: "Left"
                    slantRight: "Left"
                    slantWidth: parent.height * tooltipBg.slantRatio
                    color: "transparent"
                    borderColor: tooltipBg.colorBase05
                }

                Text {
                    anchors.centerIn: parent
                    text: "⏮"
                    font.pixelSize: 20
                    color: tooltipBg.colorBase05
                }

                TapHandler {
                    onTapped: musicBox.mpdIpc.write("previous\nstatus\ncurrentsong\n")
                }
            }

            // Play / Pause Button (Enlarged to 100x50px)
            Item {
                id: playButton
                width: 100
                height: 50
                readonly property real btnSlantWidth: height * tooltipBg.slantRatio

                SlantedBox {
                    anchors.fill: parent
                    slantLeft: "Left"
                    slantRight: "Left"
                    slantWidth: parent.height * tooltipBg.slantRatio
                    color: "transparent"
                    borderColor: tooltipBg.colorBase05
                }

                Text {
                    anchors.centerIn: parent
                    text: musicBox.playbackState === "play" ? "⏸" : "⏯"
                    font.pixelSize: 20
                    color: tooltipBg.colorBase05
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
            Item {
                id: nextButton
                width: 100
                height: 50
                readonly property real btnSlantWidth: height * tooltipBg.slantRatio

                SlantedBox {
                    anchors.fill: parent
                    slantLeft: "Left"
                    slantRight: "Left"
                    slantWidth: parent.height * tooltipBg.slantRatio
                    color: "transparent"
                    borderColor: tooltipBg.colorBase05
                }

                Text {
                    anchors.centerIn: parent
                    text: "⏭"
                    font.pixelSize: 20
                    color: tooltipBg.colorBase05
                }

                TapHandler {
                    onTapped: musicBox.mpdIpc.write("next\nstatus\ncurrentsong\n")
                }
            }

            // Directory Folder Opener
            Item {
                id: folderButton
                width: 100
                height: 50
                readonly property real btnSlantWidth: height * tooltipBg.slantRatio

                SlantedBox {
                    anchors.fill: parent
                    slantLeft: "Left"
                    slantRight: "Left"
                    slantWidth: parent.height * tooltipBg.slantRatio
                    color: "transparent"
                    borderColor: tooltipBg.colorBase05
                }

                Text {
                    anchors.centerIn: parent
                    text: "📂"
                    font.pixelSize: 18
                    color: tooltipBg.colorBase05
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

        // Sure Button
        Item {
            id: sureButton
            width: musicBox.confirmDeleteMode ? 200 : 100
            height: 50
            readonly property real btnSlantWidth: height * tooltipBg.slantRatio

            Behavior on width { NumberAnimation { duration: 100 } }

            SlantedBox {
                anchors.fill: parent
                slantLeft: "Left"
                slantRight: "Left"
                slantWidth: parent.height * tooltipBg.slantRatio
                borderColor: musicBox.confirmDeleteMode ? "#ffffff" : tooltipBg.colorBase05
                color: musicBox.confirmDeleteMode ? "#ff5555" : "transparent"
            }

            Text {
                anchors.centerIn: parent
                text: musicBox.confirmDeleteMode ? "⚠️ Sure?" : "🗑️"
                font.pixelSize: musicBox.confirmDeleteMode ? 14 : 22
                font.bold: musicBox.confirmDeleteMode
                color: musicBox.confirmDeleteMode ? "#ffffff" : tooltipBg.colorBase05 // Fixed TypeError reference
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
            height: 50
            visible: musicBox.confirmDeleteMode
        }

        // Cancel "No" Button
        Item {
            id: noButton
            width: 100
            height: 50
            visible: musicBox.confirmDeleteMode
            readonly property real btnSlantWidth: height * tooltipBg.slantRatio

            SlantedBox {
                anchors.fill: parent
                slantLeft: "Left"
                slantRight: "Left"
                slantWidth: parent.height * tooltipBg.slantRatio
                color: "transparent"
                borderColor: tooltipBg.colorBase05
            }

            Text {
                anchors.centerIn: parent
                text: "No"
                font.pixelSize: 14
                color: tooltipBg.colorBase05
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
