import "../../common/Utils.js" as Utils
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

    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property int themeBorderWidth: (shell && shell.theme && typeof shell.theme.globalBorderWidth !== "undefined") ? shell.theme.globalBorderWidth : 3
    readonly property var themeBase00: (shell && shell.theme && shell.theme.base00 !== undefined) ? shell.theme.base00 : "black"
    readonly property var themeBase02: (shell && shell.theme && shell.theme.base02 !== undefined) ? shell.theme.base02 : "#222222"
    readonly property var themeBase03: (shell && shell.theme && shell.theme.base03 !== undefined) ? shell.theme.base03 : "#333333"
    readonly property var themeBase05: (shell && shell.theme && shell.theme.base05 !== undefined) ? shell.theme.base05 : "yellow"
    readonly property var themeBase0C: (shell && shell.theme && shell.theme.base0C !== undefined) ? shell.theme.base0C : "#04f100"

    property int tooltipHeight: 420
    property int tooltipCollapsedWidth: 179
    property int tooltipExpandedWidth: 430
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: musicBox.themeSlantWidth

    property var barWindow: null
    property string moduleName: "music"
    property string trackStr: "No Track"
    property string tooltipTitle: "No Title Playing"
    property string tooltipArtist: "No Artist Data"
    property string trackCountStr: "Track 0 of 0"

    property string currentFile: ""
    property int currentVolume: 0
    property int elapsedSeconds: 0
    property int totalSeconds: 0
    property int currentTrackIdx: 0
    property int totalTracks: 0
    property string playbackState: "stop"

    property bool popupActive: false
    property bool confirmDeleteMode: false

    implicitWidth: Math.max(180, musicText.implicitWidth + bg.leftPadding + bg.rightPadding + 16)
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: musicBox.slantLeft
        slantRight: musicBox.slantRight
        slantWidth: musicBox.slantWidth
    }

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

    function formatTime(secs) {
        return Utils.formatDuration(secs, false);
    }

    // Direct, zero-fork command dispatcher via stdin
    function sendMpdCommand(cmd) {
        if (!cmd) return;
        var clean = cmd.endsWith("\n") ? cmd : (cmd + "\n");
        try {
            mpdProcess.write(clean);
        } catch (e) {
            Quickshell.execDetached([
                "python3", "-c",
                "import socket, sys\ntry:\n    s = socket.socket()\n    s.connect(('127.0.0.1', 6600))\n    s.recv(1024)\n    s.sendall(sys.argv[1].encode())\nexcept Exception: pass",
                clean
            ]);
        }
    }

    // Backward-compatibility wrapper for any external callers
    property var mpdIpc: QtObject {
        function write(data) {
            musicBox.sendMpdCommand(data);
        }
    }

    // Persistent event & command engine: single connection, zero fork on actions
    Process {
        id: mpdProcess
        running: true

        command: [
            "python3", "-u", "-c",
            "import socket, sys, time, select\n" +
            "def connect():\n" +
            "    while True:\n" +
            "        try:\n" +
            "            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)\n" +
            "            s.connect(('127.0.0.1', 6600))\n" +
            "            s.recv(1024)\n" +
            "            s.setblocking(False)\n" +
            "            return s\n" +
            "        except Exception:\n" +
            "            time.sleep(1)\n" +
            "s = connect()\n" +
            "buf = b''\n" +
            "last_poll = 0\n" +
            "while True:\n" +
            "    now = time.time()\n" +
            "    if s is None:\n" +
            "        time.sleep(1)\n" +
            "        s = connect()\n" +
            "        continue\n" +
            "    if now - last_poll >= 1.0:\n" +
            "        last_poll = now\n" +
            "        try:\n" +
            "            s.sendall(b'status\\ncurrentsong\\n')\n" +
            "        except Exception:\n" +
            "            try: s.close()\n" +
            "            except: pass\n" +
            "            s = None\n" +
            "            continue\n" +
            "    try:\n" +
            "        r, _, _ = select.select([sys.stdin, s], [], [], 0.3)\n" +
            "    except Exception:\n" +
            "        break\n" +
            "    for src in r:\n" +
            "        if src is sys.stdin:\n" +
            "            line = sys.stdin.readline()\n" +
            "            if not line: sys.exit(0)\n" +
            "            try: s.sendall(line.encode('utf-8'))\n" +
            "            except Exception:\n" +
            "                try: s.close()\n" +
            "                except: pass\n" +
            "                s = None\n" +
            "                break\n" +
            "        elif src is s:\n" +
            "            try:\n" +
            "                chunk = s.recv(4096)\n" +
            "                if not chunk:\n" +
            "                    s.close()\n" +
            "                    s = None\n" +
            "                    break\n" +
            "                buf += chunk\n" +
            "                while b'\\n' in buf:\n" +
            "                    line_data, buf = buf.split(b'\\n', 1)\n" +
            "                    sys.stdout.write(line_data.decode('utf-8', errors='ignore') + '\\n')\n" +
            "                    sys.stdout.flush()\n" +
            "            except Exception:\n" +
            "                try: s.close()\n" +
            "                except: pass\n" +
            "                s = None\n" +
            "                break\n"
        ]

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
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: 2
        anchors.bottomMargin: 2

        color: themeBase05
        text: musicBox.trackStr
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        clip: true
    }

    TapHandler {
        onTapped: {
            musicBox.popupActive = !musicBox.popupActive;
            if (!musicBox.popupActive) {
                musicBox.confirmDeleteMode = false;
            } else {
                musicBox.sendMpdCommand("status\ncurrentsong\n");
            }
        }
    }

    SlantedTooltip {
        id: musicTooltip
        moduleItem: musicBox
        barWindow: musicBox.barWindow
        tooltipActive: musicBox.popupActive
        alignSide: "Left"

        tooltipHeight: musicBox.tooltipHeight
        collapsedCoreWidth: musicBox.tooltipCollapsedWidth
        expandedCoreWidth: musicBox.tooltipExpandedWidth
        topOffset: musicBox.tooltipTopOffset
        rightOffset: musicBox.tooltipRightOffset
        slantLeft: musicBox.slantLeft
        slantRight: musicBox.slantRight

        Item {
            id: containerWrapper
            anchors.fill: parent
            readonly property real slantRatio: musicTooltip.tooltipSlantWidth / musicTooltip.tooltipHeight

            Shortcut {
                sequence: "Escape"
                enabled: true
                onActivated: {
                    musicBox.popupActive = false;
                    musicBox.confirmDeleteMode = false;
                }
            }

            // 1. TRACK DETAILS CARD
            Item {
                id: trackCard
                y: 40
                x: musicTooltip.slantX(y) + 36
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                height: 105

                SlantedBox {
                    id: innerCardBg
                    anchors.fill: parent
                    slantLeft: "Left"
                    slantRight: "Left"
                    slantWidth: parent.height * containerWrapper.slantRatio
                    borderColor: themeBase05
                    color: "transparent"
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - (parent.height * containerWrapper.slantRatio) - 20
                    spacing: 4

                    Text {
                        width: parent.width
                        text: musicBox.tooltipTitle && musicBox.tooltipTitle !== "" ? musicBox.tooltipTitle : musicBox.trackStr
                        font.family: themeFontFamily
                        font.pixelSize: 18
                        font.bold: true
                        color: themeBase05
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: musicBox.tooltipArtist && musicBox.tooltipArtist !== "" ? musicBox.tooltipArtist : "Unknown Artist"
                        font.family: themeFontFamily
                        font.pixelSize: 15
                        color: themeBase05
                        opacity: 0.8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: musicBox.trackCountStr
                        font.family: themeFontFamily
                        font.pixelSize: 13
                        color: themeBase05
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // 2. TRACK POSITION SEEK SLIDER
            Row {
                y: 165
                x: musicTooltip.slantX(y) + 24
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                spacing: 8

                Text {
                    text: musicBox.formatTime(musicBox.elapsedSeconds)
                    font.family: themeFontFamily
                    font.pixelSize: 12
                    color: themeBase05
                    anchors.verticalCenter: parent.verticalCenter
                }

                Slider {
                    id: seekSlider
                    width: parent.width - 90
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: musicBox.totalSeconds > 0 ? musicBox.totalSeconds : 100
                    value: musicBox.elapsedSeconds

                    background: SlantedBox {
                        implicitHeight: 8
                        slantLeft: "Left"
                        slantRight: "Left"
                        slantWidth: 10
                        color: themeBase03
                        borderColor: "transparent"

                        SlantedBox {
                            height: parent.height
                            width: Math.max(10, seekSlider.visualPosition * parent.width)
                            slantLeft: "Left"
                            slantRight: "Left"
                            slantWidth: 10
                            color: themeBase05
                            borderColor: "transparent"
                        }
                    }

                    handle: SlantedBox {
                        x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                        implicitWidth: 14; implicitHeight: 14
                        slantLeft: "Left"; slantRight: "Left"; slantWidth: 6
                        color: themeBase05; borderColor: themeBase05
                    }

                    onMoved: {
                        var idx = musicBox.currentTrackIdx - 1;
                        if (idx >= 0) {
                            musicBox.sendMpdCommand("seek " + idx + " " + Math.round(value) + "\nstatus\n");
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
                    text: musicBox.formatTime(musicBox.totalSeconds)
                    font.family: themeFontFamily
                    font.pixelSize: 12
                    color: themeBase05
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 3. VOLUME CONTROL SLIDER
            Row {
                y: 215
                x: musicTooltip.slantX(y) + 24
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                spacing: 8

                Text {
                    text: "VOL"
                    font.family: themeFontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: themeBase05
                    anchors.verticalCenter: parent.verticalCenter
                }

                Slider {
                    id: volSlider
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0; to: 100; value: musicBox.currentVolume

                    Binding on value {
                        value: musicBox.currentVolume
                        when: !volSlider.pressed
                    }

                    background: SlantedBox {
                        implicitHeight: 8
                        slantLeft: "Left"; slantRight: "Left"; slantWidth: 10
                        color: themeBase03; borderColor: "transparent"

                        SlantedBox {
                            height: parent.height
                            width: Math.max(10, volSlider.visualPosition * parent.width)
                            slantLeft: "Left"; slantRight: "Left"; slantWidth: 10
                            color: themeBase05; borderColor: "transparent"
                        }
                    }

                    handle: SlantedBox {
                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        implicitWidth: 14; implicitHeight: 14
                        slantLeft: "Left"; slantRight: "Left"; slantWidth: 6
                        color: themeBase05; borderColor: themeBase05
                    }

                    onMoved: musicBox.sendMpdCommand("setvol " + Math.round(value) + "\nstatus\n")
                }

                Text {
                    text: Math.round(volSlider.value) + "%"
                    font.family: themeFontFamily
                    font.pixelSize: 12
                    color: themeBase05
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 4. PRIMARY PLAYBACK CONTROLS
            Row {
                y: 275
                x: musicTooltip.slantX(y) + 24
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                spacing: 12

                Item { width: Math.max(0, (parent.width - 324) / 2); height: 42 }

                Item {
                    width: 100; height: 42
                    SlantedBox {
                        anchors.fill: parent; slantLeft: "Left"; slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"; borderColor: themeBase05
                    }
                    Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 20; color: themeBase05 }
                    TapHandler { onTapped: musicBox.sendMpdCommand("previous\nstatus\ncurrentsong\n") }
                }

                Item {
                    width: 100; height: 42
                    SlantedBox {
                        anchors.fill: parent; slantLeft: "Left"; slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"; borderColor: themeBase05
                    }
                    Text {
                        anchors.centerIn: parent
                        text: musicBox.playbackState === "play" ? "⏸" : "⏯"
                        font.pixelSize: 20; color: themeBase05
                    }
                    TapHandler {
                        onTapped: {
                            if (musicBox.playbackState === "play") musicBox.sendMpdCommand("pause 1\nstatus\n");
                            else musicBox.sendMpdCommand("play\nstatus\n");
                        }
                    }
                }

                Item {
                    width: 100; height: 42
                    SlantedBox {
                        anchors.fill: parent; slantLeft: "Left"; slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"; borderColor: themeBase05
                    }
                    Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 20; color: themeBase05 }
                    TapHandler { onTapped: musicBox.sendMpdCommand("next\nstatus\ncurrentsong\n") }
                }
            }

            // 5. SECONDARY UTILITY CONTROLS
            Row {
                y: 335
                x: musicTooltip.slantX(y) + 24
                width: musicTooltip.width - musicTooltip.tooltipSlantWidth - 48
                spacing: 12

                Item {
                    width: {
                        var totalBtnW = musicBox.confirmDeleteMode ? 240 : 180;
                        return Math.max(0, (parent.width - totalBtnW) / 2);
                    }
                    height: 38
                }

                Item {
                    width: 80; height: 38
                    visible: !musicBox.confirmDeleteMode
                    SlantedBox {
                        anchors.fill: parent; slantLeft: "Left"; slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"; borderColor: themeBase05
                    }
                    Text { anchors.centerIn: parent; text: "📂"; font.pixelSize: 18; color: themeBase05 }
                    TapHandler {
                        onTapped: {
                            Quickshell.execDetached([
                                "sh", "-c",
                                'abs_path="$HOME/Music/$1"; dir_path=$(dirname "$abs_path"); [ -d "$dir_path" ] && xdg-open "$dir_path" &',
                                "sh",
                                musicBox.currentFile
                            ]);
                            musicBox.popupActive = false;
                        }
                    }
                }

                Item {
                    width: musicBox.confirmDeleteMode ? 140 : 80
                    height: 38
                    SlantedBox {
                        anchors.fill: parent; slantLeft: "Left"; slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        borderColor: musicBox.confirmDeleteMode ? "#ffffff" : themeBase05
                        color: musicBox.confirmDeleteMode ? "#ff5555" : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: musicBox.confirmDeleteMode ? "⚠️ Sure?" : "🗑️"
                        font.pixelSize: musicBox.confirmDeleteMode ? 14 : 20
                        font.bold: musicBox.confirmDeleteMode
                        color: musicBox.confirmDeleteMode ? "#ffffff" : themeBase05
                    }
                    TapHandler {
                        onTapped: {
                            if (!musicBox.confirmDeleteMode) {
                                musicBox.confirmDeleteMode = true;
                            } else {
                                Quickshell.execDetached([
                                    "sh", "-c",
                                    'rm -f "$HOME/Music/$1"',
                                    "sh",
                                    musicBox.currentFile
                                ]);
                                musicBox.confirmDeleteMode = false;
                                musicBox.sendMpdCommand("next\nstatus\ncurrentsong\n");
                            }
                        }
                    }
                }

                Item {
                    width: 70; height: 38
                    visible: musicBox.confirmDeleteMode
                    SlantedBox {
                        anchors.fill: parent; slantLeft: "Left"; slantRight: "Left"
                        slantWidth: parent.height * containerWrapper.slantRatio
                        color: "transparent"; borderColor: themeBase05
                    }
                    Text { anchors.centerIn: parent; text: "No"; font.pixelSize: 16; color: themeBase05 }
                    TapHandler {
                        onTapped: {
                            musicBox.popupActive = false;
                            musicBox.confirmDeleteMode = false;
                        }
                    }
                }
            }
        }
    }
}
