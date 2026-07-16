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

    // ==========================================
    // GLOBAL STATE PROPERTIES
    // ==========================================
    property var barWindow: null
    property string trackStr: "No Track"
    property string tooltipTitle: "No Title Playing"
    property string tooltipArtist: "No Artist Data"
    property string trackCountStr: "Track 0 of 0"

    // Expose the internal IPC process to child components loaded via Loader
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

    // Slant config
    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: shell.theme.slantWidth

    // Centralized SlantedBox Background
    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: musicBox.slantLeft
        slantRight: musicBox.slantRight
        slantWidth: musicBox.slantWidth
    }

    width: 200
    height: parent ? parent.height : 40

    // Calculated Helpers (Local background math)
    readonly property real halfBorder: shell.theme.globalBorderWidth / 2
    readonly property int leftPadding: slantLeft === "None" ? shell.theme.globalPadding : (slantWidth + 6)
    readonly property int rightPadding: slantRight === "None" ? shell.theme.globalPadding : (slantWidth + 6)

    // Points Math for Top Bar
    property real x1: (slantLeft === "Right") ? (slantWidth + halfBorder) : halfBorder
    property real x2: (slantLeft === "Left") ? (slantWidth + halfBorder) : halfBorder
    property real x3: (slantRight === "Left") ? (width - slantWidth - halfBorder) : (width - halfBorder)
    property real x4: (slantRight === "Right") ? (width - slantWidth - halfBorder) : (width - halfBorder)

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
        anchors.topMargin: shell.theme.globalPadding / 4
        anchors.bottomMargin: shell.theme.globalPadding / 4

        color: shell.theme.base05
        text: musicBox.trackStr
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize - 2
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

    PanelWindow {
        id: musicTooltipWindow

        screen: musicBox.barWindow ? musicBox.barWindow.screen : Quickshell.screens
        visible: musicBox.popupActive

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-music-tooltip"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.left: true
        anchors.right: true
        anchors.bottom: true
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onPressed: {
                musicBox.popupActive = false;
                musicBox.confirmDeleteMode = false;
            }
        }

        Item {
            id: cardContainer

            // Dynamically scale the popup size based on the loaded tooltip's implicit calculations
            width: contentLoader.item ? contentLoader.item.implicitWidth : 674
            height: contentLoader.item ? contentLoader.item.implicitHeight : 420

            y: shell.theme.globalPadding + 55

            x: {
                if (!musicBox.barWindow) return 100;
                var globalCoords = musicBox.mapToItem(null, 0, 0);
                var musicCenterAbsolute = globalCoords.x + (musicBox.width / 2);
                var targetLeftMargin = Math.round(musicCenterAbsolute - (width / 2));

                if (targetLeftMargin < shell.theme.globalPadding) return shell.theme.globalPadding;
                return targetLeftMargin;
            }

            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: false
                onPressed: (mouse) => mouse.accepted = true
                onReleased: (mouse) => mouse.accepted = true
                onClicked: (mouse) => mouse.accepted = true
            }

            Loader {
                id: contentLoader
                anchors.fill: parent
                source: "MusicTooltip.qml"
            }
        }
    }
}
