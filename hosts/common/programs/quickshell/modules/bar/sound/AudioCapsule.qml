import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io
import "../../style"

Item {
    id: audioBox

    property var barWindow: null
    property string audioDisplayText: "Audio: --%"

    width: 140
    height: parent.height

    // Centralized SlantedBox Background
    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: "Left"
        slantRight: "Left"
    }

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

                var textColor = isMuted ? ((shell && shell.theme) ? shell.theme.base08.toString() : "red") : ((shell && shell.theme) ? shell.theme.base05.toString() : "yellow");
                var tagColor = (shell && shell.theme) ? shell.theme.base05.toString() : "yellow";

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

        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: (shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12
        anchors.bottomMargin: (shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12

        text: audioBox.audioDisplayText
        font.family: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"
        font.pixelSize: (shell && shell.theme) ? (shell.theme.globalFontSize || 14) : 14
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
        id: audioPollerTimer
        interval: 500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            audioFetcher.running = false;
            audioFetcher.running = true;
        }
    }
}
