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
    // SOCKET IPC CONNECTION
    // ==========================================

    /**
     * Handles the persistent TCP socket connection to MPD.
     * Parses streaming stdout messages line-by-line to update properties.
     */
    Process {
        id: mpdIpc
        running: true
        command: ["nc", "localhost", "6600"]
        stdout: SplitParser {
            onRead: line => {
                if (!line) return;
                line = line.trim();

                if (line.startsWith("volume: ")) {
                    var vol = parseInt(line.substring(8), 10);
                    if (!isNaN(vol)) musicBox.currentVolume = vol;
                } else if (line.startsWith("state: ")) {
                    musicBox.playbackState = line.substring(7).trim();
                } else if (line.startsWith("song: ")) {
                    musicBox.currentTrackIdx = parseInt(line.substring(6), 10) + 1;
                } else if (line.startsWith("playlistlength: ")) {
                    musicBox.totalTracks = parseInt(line.substring(16), 10);
                } else if (line.startsWith("time: ")) {
                    var times = line.substring(6).split(":");
                    musicBox.elapsedSeconds = parseInt(times[0], 10) || 0;
                    musicBox.totalSeconds = parseInt(times[1], 10) || 0;
                } else if (line.startsWith("Title: ")) {
                    musicBox.tooltipTitle = line.substring(7).trim();
                } else if (line.startsWith("Artist: ")) {
                    musicBox.tooltipArtist = line.substring(8).trim();
                } else if (line.startsWith("file: ")) {
                    musicBox.currentFile = line.substring(6).trim();
                } else if (line === "OK") {
                    if (musicBox.playbackState === "stop") {
                        musicBox.tooltipTitle = "No Title Playing";
                        musicBox.tooltipArtist = "No Artist Data";
                        musicBox.currentTrackIdx = 0;
                        musicBox.totalTracks = 0;
                        musicBox.currentFile = "";
                        musicBox.elapsedSeconds = 0;
                        musicBox.totalSeconds = 0;
                    }
                    musicBox.trackStr = musicBox.tooltipTitle !== "No Title Playing" ? musicBox.tooltipTitle : "No Track";
                    musicBox.trackCountStr = "Track " + musicBox.currentTrackIdx + " of " + musicBox.totalTracks;
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
     * Handles polling queries & self-healing connection maintenance.
     * Fires every 1 second to request data or reconnect if MPD was restarted.
     */
    Timer {
        id: updateTimer
        interval: 1000; running: true; repeat: true
        onTriggered: {
            if (!mpdIpc.running) {
                mpdIpc.running = true;
            } else if (!musicBox.confirmDeleteMode) {
                mpdIpc.write("status\ncurrentsong\n");
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
