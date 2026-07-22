// MusicCapsule.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

Item {
    id: musicBox

    // =========================================================================
    // SAFE VAR THEME FALLBACKS (Preserves exact string color-profiles)
    // =========================================================================
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property int themeBorderWidth: (shell && shell.theme && typeof shell.theme.globalBorderWidth !== "undefined") ? shell.theme.globalBorderWidth : 3
    readonly property var themeBase00: (shell && shell.theme && shell.theme.base00 !== undefined) ? shell.theme.base00 : "black"
    readonly property var themeBase02: (shell && shell.theme && shell.theme.base02 !== undefined) ? shell.theme.base02 : "#222222"
    readonly property var themeBase03: (shell && shell.theme && shell.theme.base03 !== undefined) ? shell.theme.base03 : "#333333"
    readonly property var themeBase05: (shell && shell.theme && shell.theme.base05 !== undefined) ? shell.theme.base05 : "yellow"
    // =========================================================================

    // =========================================================================
    //  EDITABLE TOOLTIP CONFIGURATION
    // =========================================================================
    property int tooltipHeight: 420          // Vertical height of the expanded box
    property int tooltipCollapsedWidth: 179  // Sleek, thin width during the downward unroll
    property int tooltipExpandedWidth: 430   // Final horizontal width once fully open (410px matches old dimensions)
    property int tooltipTopOffset: -2         // Micro-adjust vertical spacing (px)
    property int tooltipRightOffset: 21       // Micro-adjust horizontal alignment (px)
    // =========================================================================

    // Module slant configurations (Leans left)
    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: musicBox.themeSlantWidth

    property var barWindow: null
    property string trackStr: "No Track"
    property string tooltipTitle: "No Title Playing"
    property string tooltipArtist: "No Artist Data"
    property string trackCountStr: "Track 0 of 0"

    // Expose the internal IPC process to child components
    property var mpdIpc: mpdIpc

    property string currentFile: ""
    property int currentVolume: 0
    property int elapsedSeconds: 0
    property int totalSeconds: 0
    property int currentTrackIdx: 0
    property int totalTracks: 0
    property string playbackState: "stop"

    property bool popupActive: false
    property bool confirmDeleteMode: false

    // Unified Layout Constraints
    width: 200
    Layout.preferredWidth: 200
    height: parent ? parent.height : 40 // Safe guard against null-parent startup evaluations

    // Calculated Helpers (Local background math)
    readonly property real halfBorder: musicBox.themeBorderWidth / 2
    readonly property int leftPadding: slantLeft === "None" ? musicBox.themePadding : (slantWidth + 6)
    readonly property int rightPadding: slantRight === "None" ? musicBox.themePadding : (slantWidth + 6)

    // Points Math for Top Bar
    property real x1: (slantLeft === "Right") ? (slantWidth + halfBorder) : halfBorder
    property real x2: (slantLeft === "Left") ? (slantWidth + halfBorder) : halfBorder
    property real x3: (slantRight === "Left") ? (width - slantWidth - halfBorder) : (width - halfBorder)
    property real x4: (slantRight === "Right") ? (width - slantWidth - halfBorder) : (width - halfBorder)


    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: musicBox.slantLeft
        slantRight: musicBox.slantRight
        slantWidth: musicBox.slantWidth
    }

    // Display Helper
    function updateTrackString() {
        if (musicBox.playbackState === "stop") {
            musicBox.trackStr = "No Track";
            musicBox.trackCountStr = "Track 0 of 0";
            return;
        }

        var displayTitle = musicBox.tooltipTitle;
        if (!displayTitle || displayTitle === "No Title Playing") {
            var rawFile = musicBox.currentFile;
            displayTitle = rawFile ? rawFile.substring(rawFile.lastIndexOf("/") + 1) : "";
        }

        musicBox.trackStr = displayTitle ? displayTitle : "No Track";
        musicBox.trackCountStr = "Track " + musicBox.currentTrackIdx + " of " + musicBox.totalTracks;
    }

    // Time Formatting Helper (Moved to root for global component scope access)
    function formatTime(secs) {
        if (!secs || isNaN(secs) || secs < 0) return "0:00";
        var m = Math.floor(secs / 60);
        var s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Socket IPC connection
    Process {
        id: mpdIpc
        running: true

        command: [
            "python3", "-u", "-c",
            "import socket, sys, time\n" +
            "while True:\n" +
            "    try:\n" +
            "        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)\n" +
            "        s.connect(('127.0.0.1', 6600))\n" +
            "        s.recv(1024)\n" +
            "        s.sendall(b'''status\ncurrentsong\n''')\n" +
            "        res = b''\n" +
            "        while True:\n" +
            "            chunk = s.recv(4096)\n" +
            "            if not chunk: break\n" +
            "            res += chunk\n" +
            "            norm = res.replace(b'''\\r\\n''', b'''\\n''')\n" +
            "            if norm.endswith(b'''\\nOK\\n''') or norm == b'''OK\\n''':\n" +
            "                break\n" +
            "        s.close()\n" +
            "        sys.stdout.write(res.decode('utf-8', errors='ignore'))\n" +
            "        sys.stdout.flush()\n" +
            "    except Exception:\n" +
            "        pass\n" +
            "    time.sleep(1)"
        ]

        function write(data) {
            Quickshell.execDetached([
                "python3", "-c",
                "import socket\n" +
                "try:\n" +
                "    s = socket.socket()\n" +
                "    s.connect(('127.0.0.1', 6600))\n" +
                "    s.recv(1024)\n" +
                "    s.sendall('''" + data + "'''.encode())\n" +
                "except Exception: pass"
            ]);
        }

        stdout: SplitParser {
            onRead: line => {
                if (!line) return;
                line = line.trim();
                var lowerLine = line.toLowerCase();

                if (lowerLine.startsWith("volume: ")) {
                    var vol = parseInt(line.substring(8), 10);
                    if (!isNaN(vol)) musicBox.currentVolume = vol;
                } else if (lowerLine.startsWith("state: ")) {
                    musicBox.playbackState = line.substring(7).trim();
                    musicBox.updateTrackString();
                } else if (lowerLine.startsWith("song: ")) {
                    musicBox.currentTrackIdx = parseInt(line.substring(6), 10) + 1;
                    musicBox.updateTrackString();
                } else if (lowerLine.startsWith("playlistlength: ")) {
                    musicBox.totalTracks = parseInt(line.substring(16), 10);
                    musicBox.updateTrackString();
                } else if (lowerLine.startsWith("time: ")) {
                    var times = line.substring(6).split(":");
                    if (times.length > 1) {
                        musicBox.elapsedSeconds = parseInt(times[0], 10) || 0;
                        var parsedTotal = parseInt(times[1], 10) || 0;
                        if (parsedTotal > 0) musicBox.totalSeconds = parsedTotal;
                    }
                } else if (lowerLine.startsWith("duration: ")) {
                    var dur = parseFloat(line.substring(10));
                    if (!isNaN(dur)) musicBox.totalSeconds = Math.round(dur);
                } else if (lowerLine.startsWith("file: ")) {
                    musicBox.currentFile = line.substring(6).trim();
                    musicBox.tooltipTitle = "";
                    musicBox.tooltipArtist = "";
                    musicBox.updateTrackString();
                } else if (lowerLine.startsWith("title: ")) {
                    musicBox.tooltipTitle = line.substring(7).trim();
                    musicBox.updateTrackString();
                } else if (lowerLine.startsWith("artist: ")) {
                    musicBox.tooltipArtist = line.substring(8).trim();
                } else if (line === "OK") {
                    if (musicBox.playbackState === "stop") {
                        musicBox.tooltipTitle = "No Title Playing";
                        musicBox.tooltipArtist = "No Artist Data";
                        musicBox.currentTrackIdx = 0;
                        musicBox.totalTracks = 0;
                        musicBox.currentFile = "";
                        musicBox.elapsedSeconds = 0;
                        musicBox.totalSeconds = 0;
                        musicBox.updateTrackString();
                    } else {
                        if (!musicBox.tooltipTitle && musicBox.currentFile) {
                            var rawFile = musicBox.currentFile;
                            musicBox.tooltipTitle = rawFile.substring(rawFile.lastIndexOf("/") + 1);
                        }
                        if (!musicBox.tooltipArtist) {
                            musicBox.tooltipArtist = "Unknown Artist";
                        }
                        musicBox.updateTrackString();
                    }
                }
            }
        }
    }

    Text {
        id: musicText
        anchors.fill: parent

        anchors.leftMargin: musicBox.leftPadding
        anchors.rightMargin: musicBox.rightPadding
        anchors.topMargin: themePadding / 4
        anchors.bottomMargin: themePadding / 4

        color: themeBase05
        text: musicBox.trackStr
        font.family: themeFontFamily
        font.pixelSize: themeFontSize - 20 // Restored to your original relative size
        font.bold: true
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter

        // Auto-scale text down slightly if the title is very long
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        elide: Text.ElideRight
    }

    Timer {
        id: updateTimer
        interval: 1000; running: true; repeat: true
        onTriggered: {
            if (!mpdIpc.running) {
                mpdIpc.running = true;
            }
        }
    }

    TapHandler {
        onTapped: {
            musicBox.popupActive = !musicBox.popupActive
            if (!musicBox.popupActive) {
                musicBox.confirmDeleteMode = false
            } else {
                mpdIpc.write("status\ncurrentsong\n");
            }
        }
    }

    // Tooltip Window (Directly Instantiated for smooth reverse collapse)
    SlantedTooltip {
        id: musicTooltip
        moduleItem: musicBox
        barWindow: musicBox.barWindow
        tooltipActive: musicBox.popupActive

        // Instruct the template to align left and expand rightwards
        alignSide: "Left"

        // Maps variables defined at the top of the file
        tooltipHeight: musicBox.tooltipHeight
        collapsedCoreWidth: musicBox.tooltipCollapsedWidth
        expandedCoreWidth: musicBox.tooltipExpandedWidth
        topOffset: musicBox.tooltipTopOffset
        rightOffset: musicBox.tooltipRightOffset

        // pass capsule slants to keep the window parallel
        slantLeft: musicBox.slantLeft
        slantRight: musicBox.slantRight

        // Stationary layout wrapper (Restored local bindings to prevent type-coercion color shifts)
        Item {
            id: containerWrapper
            anchors.fill: parent

            readonly property string fontFamily: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"
            readonly property var colorBase05: (shell && shell.theme) ? (shell.theme.base05 || "yellow") : "yellow"
            readonly property var colorBase03: (shell && shell.theme) ? (shell.theme.base03 || "#333333") : "#333333"
            readonly property var colorBase02: (shell && shell.theme) ? (shell.theme.base02 || "#222222") : "#222222"
            readonly property real slantRatio: musicTooltip.tooltipSlantWidth / musicTooltip.tooltipHeight

            Shortcut {
                sequence: "Escape"
                enabled: true
                onActivated: {
                    musicBox.popupActive = false;
                    musicBox.confirmDeleteMode = false;
                }
            }

            // File Deleter
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

            Item {
                id: trackDetailsBlock
                y: 45
                x: musicTooltip.slantX(y) + 60
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                height: 110

                SlantedBox {
                    id: blockBg
                    anchors.fill: parent
                    slantLeft: "Left"
                    slantRight: "Left"
                    slantWidth: parent.height * containerWrapper.slantRatio
                    borderColor: containerWrapper.colorBase05
                    color: "transparent"
                }

                //  Title Text inside Track block
                Text {
                    id: titleText
                    y: 18
                    x: musicTooltip.slantX(45 + y) + 12
                    width: parent.width - (parent.height * containerWrapper.slantRatio) - 24
                    text: musicBox.tooltipTitle && musicBox.tooltipTitle !== "" ? musicBox.tooltipTitle : musicBox.trackStr
                    font.family: themeFontFamily
                    font.pixelSize: 18
                    font.bold: true
                    color: containerWrapper.colorBase05
                    elide: Text.ElideRight
                }

                // Staggered Artist Text inside Track block
                Text {
                    id: artistText
                    y: 48
                    x: musicTooltip.slantX(45 + y) + 12
                    width: parent.width - (parent.height * containerWrapper.slantRatio) - 24
                    text: musicBox.tooltipArtist && musicBox.tooltipArtist !== "" ? musicBox.tooltipArtist : "Unknown Artist"
                    font.family: themeFontFamily
                    font.pixelSize: 20
                    color: containerWrapper.colorBase05
                    opacity: 0.8
                    elide: Text.ElideRight
                }

                // Staggered Track Count Text inside Track block
                Text {
                    id: countText
                    y: 78
                    x: musicTooltip.slantX(45 + y) + 12
                    width: parent.width - (parent.height * containerWrapper.slantRatio) - 24
                    text: musicBox.trackCountStr
                    font.family: themeFontFamily
                    font.pixelSize: 20
                    color: containerWrapper.colorBase05
                }
            }

            // Seek / Track Position Slider
            Row {
                y: 185
                x: musicTooltip.slantX(y) + 24
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                spacing: 8

                Text {
                    id: currentTimeText
                    text: musicBox.formatTime(musicBox.elapsedSeconds)
                    font.family: themeFontFamily
                    font.pixelSize: 12
                    color: containerWrapper.colorBase05
                    anchors.verticalCenter: parent.verticalCenter
                }

                Slider {
                    id: seekSlider
                    width: parent.width - currentTimeText.width - totalTimeText.width - 16
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: musicBox.totalSeconds > 0 ? musicBox.totalSeconds : 100
                    value: musicBox.elapsedSeconds

                    // background track
                    background: SlantedBox {
                        id: seekTrackBg
                        implicitWidth: 200
                        implicitHeight: 10
                        width: seekSlider.availableWidth
                        height: implicitHeight
                        slantLeft: "Left"
                        slantRight: "Left"
                        slantWidth: 14
                        color: containerWrapper.colorBase03
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
                            color: containerWrapper.colorBase05
                            borderColor: "transparent"
                        }
                    }

                    // Handle (Thumb)
                    handle: SlantedBox {
                        id: seekThumb
                        x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                        implicitWidth: 16
                        implicitHeight: 16
                        slantLeft: "Left"
                        slantRight: "Left"
                        slantWidth: 10
                        color: containerWrapper.colorBase05
                        borderColor: containerWrapper.colorBase05
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
                    text: musicBox.formatTime(musicBox.totalSeconds)
                    font.family: themeFontFamily
                    font.pixelSize: 20
                    color: containerWrapper.colorBase05
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Slanted Volume Control Slider
            Row {
                y: 240
                x: musicTooltip.slantX(y) + 24
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                spacing: 8

                Text {
                    text: "VOL"
                    font.pixelSize: 20
                    color: containerWrapper.colorBase05
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

                    // background track
                    background: SlantedBox {
                        id: volTrackBg
                        implicitWidth: 200
                        implicitHeight: 10
                        width: volSlider.availableWidth
                        height: implicitHeight
                        slantLeft: "Left"
                        slantRight: "Left"
                        slantWidth: 14
                        color: containerWrapper.colorBase03
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
                            color: containerWrapper.colorBase05
                            borderColor: "transparent"
                        }
                    }

                    // Handle (Thumb)
                    handle: SlantedBox {
                        id: volThumb
                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        implicitWidth: 16
                        implicitHeight: 16
                        slantLeft: "Left"
                        slantRight: "Left"
                        slantWidth: 10
                        color: containerWrapper.colorBase05
                        borderColor: containerWrapper.colorBase05
                    }

                    onMoved: {
                        musicBox.mpdIpc.write("setvol " + Math.round(value) + "\nstatus\n");
                    }
                }

                Text {
                    text: Math.round(volSlider.value) + "%"
                    font.family: themeFontFamily
                    font.pixelSize: 20
                    color: containerWrapper.colorBase05
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Row 1: Primary Playback Controls (Aligned cleanly at y: 285)
            Row {
                y: 285
                x: musicTooltip.slantX(y) + 24
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                spacing: 12

                // Dynamic spacer to center the primary media buttons horizontally
                Item {
                    width: Math.max(0, (parent.width - 324) / 2) // 3x 100px buttons + 2x 12px spacers = 324px
                    height: 45
                }

                // Previous Track Button
                Item {
                    id: prevButton
                    width: 100
                    height: 45
                    readonly property real btnSlantWidth: height * containerWrapper.slantRatio

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"
                        slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"
                        borderColor: containerWrapper.colorBase05
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "⏮"
                        font.pixelSize: 20
                        color: containerWrapper.colorBase05
                    }

                    TapHandler {
                        onTapped: musicBox.mpdIpc.write("previous\nstatus\ncurrentsong\n")
                    }
                }

                // Play / Pause Button
                Item {
                    id: playButton
                    width: 100
                    height: 45
                    readonly property real btnSlantWidth: height * containerWrapper.slantRatio

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"
                        slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"
                        borderColor: containerWrapper.colorBase05
                    }

                    Text {
                        anchors.centerIn: parent
                        text: musicBox.playbackState === "play" ? "⏸" : "⏯"
                        font.pixelSize: 20
                        color: containerWrapper.colorBase05
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
                    height: 45
                    readonly property real btnSlantWidth: height * containerWrapper.slantRatio

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"
                        slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"
                        borderColor: containerWrapper.colorBase05
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "⏭"
                        font.pixelSize: 20
                        color: containerWrapper.colorBase05
                    }

                    TapHandler {
                        onTapped: musicBox.mpdIpc.write("next\nstatus\ncurrentsong\n")
                    }
                }
            }

            // Row 2: Secondary Utility Controls (📂 Open Folder & 🗑️ Delete/Confirm Actions at y: 345)
            Row {
                y: 345
                x: musicTooltip.slantX(y) + 24
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                spacing: 12

                // Dynamic spacer to center the secondary utility buttons horizontally
                Item {
                    width: {
                        var totalBtnWidth = musicBox.confirmDeleteMode
                        ? (sureButton.width + 12 + 25 + 12 + noButton.width)
                        : (folderButton.width + 12 + sureButton.width);
                        return Math.max(0, (parent.width - totalBtnWidth) / 2);
                    }
                    height: 40
                }

                // Directory Folder Opener
                Item {
                    id: folderButton
                    width: 80
                    height: 40
                    visible: !musicBox.confirmDeleteMode
                    readonly property real btnSlantWidth: height * containerWrapper.slantRatio

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"
                        slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"
                        borderColor: containerWrapper.colorBase05
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "📂"
                        font.pixelSize: 20
                        color: containerWrapper.colorBase05
                    }

                    TapHandler {
                        onTapped: {
                            Quickshell.execDetached([
                                "sh", "-c",
                                "abs_path=\"$HOME/Music/" + musicBox.currentFile + "\"; " +
                                "dir_path=$(dirname \"$abs_path\"); " +
                                "if [ -d \"$dir_path\" ]; then nemo \"$dir_path\" >/dev/null 2>&1 & fi"
                            ])
                            musicBox.popupActive = false
                        }
                    }
                }

                // Sure / Delete Trigger Button
                Item {
                    id: sureButton
                    width: musicBox.confirmDeleteMode ? 140 : 80 // Adapts width smoothly on deletion triggers
                    height: 40
                    readonly property real btnSlantWidth: height * containerWrapper.slantRatio

                    Behavior on width { NumberAnimation { duration: 100 } }

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"
                        slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        borderColor: musicBox.confirmDeleteMode ? "#ffffff" : containerWrapper.colorBase05
                        color: musicBox.confirmDeleteMode ? "#ff5555" : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: musicBox.confirmDeleteMode ? "⚠️ Sure?" : "🗑️"
                        font.pixelSize: musicBox.confirmDeleteMode ? 14 : 22
                        font.bold: musicBox.confirmDeleteMode
                        color: musicBox.confirmDeleteMode ? "#ffffff" : containerWrapper.colorBase05
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

                // Gap spacing item during confirm-delete mode
                Item {
                    width: 25
                    height: 40
                    visible: musicBox.confirmDeleteMode
                }

                // Cancel "No" Button
                Item {
                    id: noButton
                    width: 80
                    height: 40
                    visible: musicBox.confirmDeleteMode
                    readonly property real btnSlantWidth: height * containerWrapper.slantRatio

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"
                        slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"
                        borderColor: containerWrapper.colorBase05
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No"
                        font.pixelSize: 20
                        color: containerWrapper.colorBase05
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
