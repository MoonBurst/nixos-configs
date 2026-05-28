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
    height: parent ? parent.height : 40
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth
    color: shell.theme.base00
    border.color: shell.theme.base05

    Process {
        id: musicProc
        running: true
        command: ["sh", "-c", "TITLE=$(audtool current-song-tuple-data title 2>/dev/null); ARTIST=$(audtool current-song-tuple-data artist 2>/dev/null); POS=$(audtool playlist-position 2>/dev/null); LEN=$(audtool playlist-length 2>/dev/null); echo \"$TITLE|$ARTIST|$POS|$LEN\""]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim() !== "") {
                    var parts = data.trim().split("|");
                    var rawTitle = parts[0] ? parts[0].trim() : "No Track";
                    var rawArtist = parts[1] ? parts[1].trim() : "Unknown Artist";
                    var currentPos = parts[2] ? parts[2].trim() : "0";
                    var totalLen = parts[3] ? parts[3].trim() : "0";

                    if (rawTitle === "") {
                        rawTitle = "No Track";
                    }

                    musicBox.tooltipTitle = rawTitle;
                    musicBox.tooltipArtist = rawArtist;
                    musicBox.trackStr = rawTitle;
                    musicBox.trackCountStr = "Track " + currentPos + " of " + totalLen;
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
            height: 210

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
