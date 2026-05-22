import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

import Theme

Rectangle {
    id: audioBox

    // Explicit sizing rules keep it completely separate from your mic container frame
    width: 140
    height: 35
    radius: 10
    border.width: 3

    // Explicit anchoring stops it from overlapping or getting buried inside horizontal rows
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

    property string audioDisplayText: "Audio: --%"

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

                var textColor = "white";
                if (typeof Theme !== 'undefined' && Theme.base05 !== undefined && Theme.base08 !== undefined) {
                    textColor = isMuted ? Theme.base08 : Theme.base05;
                } else {
                    textColor = isMuted ? "red" : "white";
                }

                var tagColor = (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow";
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
        font.family: "monospace"
        font.pixelSize: 20
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
