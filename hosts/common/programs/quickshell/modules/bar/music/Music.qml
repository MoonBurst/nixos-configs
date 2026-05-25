import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Rectangle {
    id: musicBox

    property var barWindow: null
    property string trackStr: "No Track"
    property string tooltipTitle: "No Title Playing"
    property string tooltipArtist: "No Artist Data"
    property string trackCountStr: "Track 0 of 0"

    property bool popupActive: false
    property bool confirmDeleteMode: false

    width: 200
    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth
    color: shell.theme.base00
    border.color: shell.theme.base05

    Process {
        id: musicProc
        running: true
        command: ["sh", "-c", "TITLE=$(audtool current-song 2>/dev/null); ARTIST=$(audtool current-song-tuple-data artist 2>/dev/null); POS=$(audtool playlist-position 2>/dev/null); LEN=$(audtool playlist-length 2>/dev/null); echo \"$TITLE|$ARTIST|$POS|$LEN\""]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim() !== "") {
                    var parts = data.trim().split("|");
                    var rawTitle = parts[0] ? parts[0] : "No Track";
                    var rawArtist = parts[1] ? parts[1] : "Unknown Artist";
                    var currentPos = parts[2] ? parts[2] : "0";
                    var totalLen = parts[3] ? parts[3] : "0";

                    musicBox.tooltipTitle = rawTitle;
                    musicBox.tooltipArtist = rawArtist;
                    musicBox.trackStr = (rawArtist + " - " + rawTitle).substring(0, 15);
                    musicBox.trackCountStr = "Track " + currentPos + " of " + totalLen;
                }
            }
        }
    }

    Text {
        id: musicText
        anchors.fill: parent
        anchors.margins: 5
        color: shell.theme.base05
        text: "🎵 " + musicBox.trackStr
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize - 2
        font.bold: true
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    Timer {
        id: updateTimer
        interval: 2000; running: true; repeat: true
        onTriggered: {
            if (!musicBox.confirmDeleteMode) {
                musicProc.running = false;
                musicProc.running = true;
            }
        }
    }

    TapHandler {
        onTapped: {
            musicBox.popupActive = !musicBox.popupActive
            if (!musicBox.popupActive) {
                musicBox.confirmDeleteMode = false
            }
        }
    }

    PanelWindow {
        id: musicTooltipWindow

        screen: musicBox.barWindow ? musicBox.barWindow.screen : null
        visible: musicBox.popupActive

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-music-tooltip"

        // Exclusive focus forces non-Hyprland Wayland compositors to route keys to this layer
        WlrLayershell.keyboardFocus: musicBox.popupActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors.top: true
        anchors.left: true
        anchors.right: false
        anchors.bottom: false

        implicitWidth: 400
        implicitHeight: 210
        color: "transparent"

        WlrLayershell.margins.top: {
            if (!musicBox.barWindow || typeof mainBarContainer === "undefined" || !mainBarContainer) return 100;
            return shell.theme.globalPadding + mainBarContainer.capsuleHeight + 8;
        }

        WlrLayershell.margins.left: {
            if (!musicBox.barWindow) return 100;
            var containerX = musicBox.x;
            var musicCenterAbsolute = containerX + (musicBox.width / 2);
            var targetLeftMargin = Math.round(musicCenterAbsolute - (implicitWidth / 2));
            if (targetLeftMargin < shell.theme.globalPadding) return shell.theme.globalPadding;
            return targetLeftMargin;
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            source: "MusicTooltip.qml"
        }
    }
}
