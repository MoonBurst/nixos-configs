import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

import Theme

Rectangle {
    id: audioBox
    width: 140
    height: 35
    radius: 8
    border.width: 2

    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base03 !== undefined) ? Theme.base03 : "blue"

    property string audioDisplayText: "Audio: --%"

    Component.onCompleted: {
        if (typeof root !== 'undefined' && typeof root.applyCapsuleTheme !== 'undefined') {
            root.applyCapsuleTheme(audioBox, audioText);
        }
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
                if (match && match[1] !== undefined) {
                    var val = parseFloat(match[1]);
                    vNum = Math.round(val * 100) + "%";
                }

                var textColor = "white";
                if (typeof Theme !== 'undefined' && Theme.base05 !== undefined && Theme.base08 !== undefined) {
                    textColor = isMuted ? Theme.base08 : Theme.base05;
                } else {
                    textColor = isMuted ? "red" : "white";
                }

                var tagColor = (typeof Theme !== 'undefined' && Theme.base0C !== undefined) ? Theme.base0C : "green";
                audioBox.audioDisplayText = "<font color='" + tagColor + "'>Audio:</font> <font color='" + textColor + "'>" + vNum + "</font>";
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                // Left click now reliably switches between your available headphones/speakers
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
        color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"
        textFormat: Text.RichText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // Automatically gathers your sinks and switches your system default profile to the next available device
    Process {
        id: deviceToggleProcess
        running: false
        command: [
            "sh", "-c",
            "sinks=$(wpctl status | sed -n '/Audio/,/^$/p' | grep -E '^[[:space:]]*[*[:space:]][[:space:]]*[0-9]+\\.' | sed -E 's/^[[:space:]]*[*[:space:]][[:space:]]*([0-9]+)\\..*/\\1/'); " +
            "current=$(wpctl status | sed -n '/Audio/,/^$/p' | grep -E '^[[:space:]]*\\*' | sed -E 's/^[[:space:]]*\\*[[:space:]]*([0-9]+)\\..*/\\1/'); " +
            "next=$(echo \"$sinks\" | grep -A1 \"^$current$\" | tail -n1); " +
            "[ \"$next\" = \"$current\" ] || [ -z \"$next\" ] && next=$(echo \"$sinks\" | head -n1); " +
            "[ -n \"$next\" ] && wpctl set-default \"$next\""
        ]
    }

    Process { id: volUpProcess; running: false; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"] }
    Process { id: volDownProcess; running: false; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"] }
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
