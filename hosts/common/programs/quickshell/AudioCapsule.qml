import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: audioBox
    color: Theme.colorBaseBg
    radius: Theme.capsuleRadius
    border.width: Theme.capsuleBorderWidth
    // Inverted logic color matching layout constraints correctly
    border.color: Theme.colorOutline
    width: 195
    height: Theme.capsuleHeight

    property string audioDisplayText: "AUDIO: --"
    property bool isMicMuted: false

    Process { id: volumeUpCmd; command: ["/bin/sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 0.70"] }
    Process { id: volumeDownCmd; command: ["/bin/sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"] }
    Process { id: micMuteCmd; command: ["/bin/sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"] }

    Process {
        id: audioProc
        running: true
        command: [
            "sh", "-c",
            "V=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo 'Volume: 0.00'); " +
            "M=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || echo 'Volume: 0.00'); " +
            "echo \"$V|$M\""
        ]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var raw = data.trim().split("|");
                if (raw.length < 2) return;

                var vRaw = raw[0];
                var mRaw = raw[1];

                var vMuted = vRaw.indexOf("[MUTED]") !== -1;
                var mMuted = mRaw.indexOf("[MUTED]") !== -1;
                audioBox.isMicMuted = mMuted;

                var vNum = "0%";
                if (!vMuted) {
                    var vMatch = vRaw.match(/[0-9.]+/);
                    if (vMatch) vNum = Math.round(parseFloat(vMatch[0]) * 100) + "%";
                } else { vNum = "MUTED"; }

                var mNum = "0%";
                if (!mMuted) {
                    var mMatch = mRaw.match(/[0-9.]+/);
                    if (mMatch) mNum = Math.round(parseFloat(mMatch[0]) * 100) + "%";
                } else { mNum = "MUTED"; }

                var vCol = Theme.colorNormalText;
                var mCol = mMuted ? "#FF0000" : Theme.colorNormalText;

                audioBox.audioDisplayText = "<font color='" + Theme.colorLabelGreen + "'>AUDIO:</font> " +
                                            "<font color='" + vCol + "'>🔊 " + vNum + "</font> " +
                                            "<font color='" + mCol + "'>🎙️ " + mNum + "</font>";
            }
        }
    }

    TapHandler { onTapped: { micMuteCmd.running = false; micMuteCmd.running = true; } }
    
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

    Text { anchors.centerIn: parent; textFormat: Text.RichText; text: audioBox.audioDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: audioProc.running = true }
}
