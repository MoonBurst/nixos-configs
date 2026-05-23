import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Rectangle {
    id: audioBox

    // FIXED: Registered the missing barWindow property definition to clear the shell boot crash
    property var barWindow: null
    property string audioDisplayText: "Audio: --%"

    // FIXED: Geometric constraints scale dynamically to match your global design specifications
    width: 140
    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth

    color: shell.theme.base00
    border.color: shell.theme.base05

    Process {
        id: audioFetcher
        running: true
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]

        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var cleanData = data.trim();
                var isMuted = cleanData.indexOf("[MUTED]") !== -1;

                var match = cleanData.match(/Volume:\s+([0-9.]+)/);
                var vNum = "--%";
                if (match && match !== undefined) {
                    var val = parseFloat(match[1]);
                    vNum = Math.round(val * 100) + "%";
                }

                // FIXED: Directing audio colors securely to your system-wide color scheme tokens
                var textColor = isMuted ? shell.theme.base08.toString() : shell.theme.base05.toString();
                var tagColor = shell.theme.base05.toString();

                audioBox.audioDisplayText = "<font color='" + tagColor + "'>Audio:</font> <font color='" + textColor + "'>" + vNum + "</font>";
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                deviceToggleProcess.running = true;
            } else if (mouse.button === Qt.RightButton) {
                mixerOpenProcess.running = true;
            }
        }

        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                volUpProcess.running = true;
            } else if (wheel.angleDelta.y < 0) {
                volDownProcess.running = true;
            }
        }
    }

    Text {
        id: audioText
        anchors.fill: parent
        text: audioBox.audioDisplayText
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        textFormat: Text.RichText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Process {
        id: deviceToggleProcess
        running: false
        command: ["/home/moonburst/nix/hosts/common/scripts/sound_sink_switcher.sh"]
    }

    Process { id: volUpProcess; running: false; command: ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"] }
    Process { id: volDownProcess; running: false; command: ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"] }
    Process { id: mixerOpenProcess; running: false; command: ["pavucontrol"] }

    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            audioFetcher.running = false;
            audioFetcher.running = true;
        }
    }
}
