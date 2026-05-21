import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: audioBox
    width: 140

    property string audioDisplayText: "Audio: --"

    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(audioBox, audioText);
        }
    }

    Process { id: volumeUpCmd; command: ["/bin/sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 0.70"] }
    Process { id: volumeDownCmd; command: ["/bin/sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"] }

    Process {
        id: audioProc
        running: true
        command: [
            "sh", "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo 'Volume: 0.00'"
        ]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var raw = data.trim();
                var isMuted = raw.indexOf("[MUTED]") !== -1;

                var vNum = "0%";
                if (!isMuted) {
                    var vMatch = raw.match(/[0-9.]+/);
                    if (vMatch) vNum = Math.round(parseFloat(vMatch[0]) * 100) + "%";
                } else {
                    vNum = "MUTED";
                }

                const textColor = isMuted ? (root.theme ? root.theme.base08 : "red") : (root.theme ? root.theme.base05 : "white");

                audioBox.audioDisplayText = "<font color='" + (root.theme ? root.theme.base0C : "green") + "'>Audio:</font> <font color='" + textColor + "'>" + vNum + "</font>";
            }
        }
    }

    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y > 0) {
                volumeUpCmd.running = false; volumeUpCmd.running = true;
            } else if (event.angleDelta.y < 0) {
                volumeDownCmd.running = false; volumeDownCmd.running = true;
            }
            audioProc.running = false; audioProc.running = true;
        }
    }

    Text {
        id: audioText;
        anchors.centerIn: parent;
        textFormat: Text.RichText;
        text: audioBox.audioDisplayText;
        font.family: "monospace";
        font.pixelSize: 20;
        font.bold: true
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: audioProc.running = true }
}
