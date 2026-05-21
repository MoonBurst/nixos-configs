import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: micBox
    width: 140

    property color colorLabelGreen: "#00FF00"
    property color colorLabelYellow: "#FFFF00"
    property color colorMuted: "#FF0000"
    property color colorNormalText: "#FFFFFF"

    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(micBox, micText);
        }
    }

    property string micDisplayText: "Mic: --"

    Process { id: micMuteCmd; command: ["/bin/sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"] }

    Process {
        id: micProc
        running: true
        command: [
            "sh", "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || echo 'Volume: 0.00'"
        ]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var raw = data.trim();
                var isMuted = raw.indexOf("[MUTED]") !== -1;

                var mNum = "0%";
                if (!isMuted) {
                    var mMatch = raw.match(/[0-9.]+/);
                    if (mMatch) mNum = Math.round(parseFloat(mMatch[0]) * 100) + "%";
                } else {
                    mNum = "MUTED";
                }

                var mCol = isMuted ? micBox.colorMuted : micBox.colorLabelYellow;
                micBox.micDisplayText = "<font color='" + micBox.colorLabelGreen + "'>Mic:</font> <font color='" + mCol + "'>" + mNum + "</font>";
            }
        }
    }

    TapHandler {
        onTapped: {
            micMuteCmd.running = false; micMuteCmd.running = true;
            micProc.running = false; micProc.running = true;
        }
    }

    Text { id: micText; anchors.centerIn: parent; textFormat: Text.RichText; text: micBox.micDisplayText; font.family: "monospace"; font.pixelSize: 20; font.bold: true }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: micProc.running = true }
}
