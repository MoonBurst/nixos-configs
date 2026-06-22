import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Rectangle {
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

    width: 200
    height: parent ? parent.height : 40
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth
    color: shell.theme.base00
    border.color: shell.theme.base05

    // ==========================================
    // DISPLAY HELPER
    // ==========================================

    /**
     * Updates trackStr and trackCountStr immediately when state or tags change.
     * Ensures we fallback to just the file name (no path) if Title tag is missing.
     */
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

    // ==========================================
    // SOCKET IPC CONNECTION
    // ==========================================

    /**
     * Handles the background polling socket loop.
     * Periodically queries MPD and streams raw output directly inline to SplitParser.
     */
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

        /**
         * Custom write wrapper function.
         * Runs a fast, short-lived socket writer to bypass standard stream limitations.
         * Keeps full compatibility with existing tooltip components.
         */
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

        /**
         * Inline parser bound to the standard output of the process.
         * Performs case-insensitive checks on prefixes to handle varied tag definitions.
         */
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
                    musicBox.elapsedSeconds = parseInt(times[0], 10) || 0;
                    var parsedTotal = parseInt(times[1], 10) || 0;
                    if (parsedTotal > 0) musicBox.totalSeconds = parsedTotal;
                } else if (lowerLine.startsWith("duration: ")) {
                    var dur = parseFloat(line.substring(10));
                    if (!isNaN(dur)) musicBox.totalSeconds = Math.round(dur);
                } else if (lowerLine.startsWith("file: ")) {
                    musicBox.currentFile = line.substring(6).trim();
                    // Reset metadata fields to avoid retaining stale info from previous tracks
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
                        // Apply fallbacks (extracting filename only) when parsing is complete
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
        anchors.margins: shell.theme.globalPadding /4
        color: shell.theme.base05
        text: "🎵 " + musicBox.trackStr
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize - 2
        font.bold: true
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    /**
     * Self-healing connection maintenance.
     * Restarts the process if MPD or Python encounters an issue.
     */
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
            width: 400
            height: 270

            y: {
                if (!musicBox.barWindow || typeof mainBarContainer === "undefined" || !mainBarContainer) return 100;
                return shell.theme.globalPadding + mainBarContainer.capsuleHeight + 8;
            }

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
