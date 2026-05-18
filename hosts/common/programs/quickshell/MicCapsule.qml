import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: micBox
    color: Theme.colorBaseBg
    radius: Theme.capsuleRadius
    border.width: Theme.capsuleBorderWidth
    border.color: Theme.colorOutline
    width: 115
    height: Theme.capsuleHeight

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

                var mCol = isMuted ? "#FF0000" : Theme.colorNormalText;
                micBox.micDisplayText = "<font color='" + Theme.colorLabelGreen + "'>Mic:</font> <font color='" + mCol + "'>" + mNum + "</font>";
            }
        }
    }

    TapHandler { 
        onTapped: { 
            micMuteCmd.running = false; micMuteCmd.running = true; 
            micProc.running = false; micProc.running = true;
        } 
    }

    Text { anchors.centerIn: parent; textFormat: Text.RichText; text: micBox.micDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: micProc.running = true }
}
