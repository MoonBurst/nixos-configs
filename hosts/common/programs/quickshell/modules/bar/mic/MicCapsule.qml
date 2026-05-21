import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: micBox

    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(micBox, micText);
        }
        updateDisplayText("0.0", false); // Initial display
    }

    property string micDisplayText: "Mic: --"

    function updateDisplayText(raw, isMuted) {
        if (!root.theme) {
            micText.text = "<font color='green'>Mic:</font> --%";
            return;
        }

        const greenColor = root.theme.base0C.toString();
        const yellowColor = root.theme.base05.toString();
        const redColor = root.theme.base08.toString();

        var mNum = "0%";
        if (!isMuted) {
            var mMatch = raw.match(/[0-9.]+/);
            if (mMatch) mNum = Math.round(parseFloat(mMatch[0]) * 100) + "%";
        } else {
            mNum = "MUTED";
        }

        var mCol = isMuted ? redColor : yellowColor;
        micDisplayText = "<font color='" + greenColor + "'>Mic:</font> <font color='" + mCol + "'>" + mNum + "</font>";
    }

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
                updateDisplayText(raw, isMuted);
            }
        }
    }

    TapHandler {
        onTapped: {
            micMuteCmd.running = false; micMuteCmd.running = true;
            micProc.running = false; micProc.running = true;
        }
    }

    Text {
        id: micText
        anchors.centerIn: parent
        textFormat: Text.RichText
        text: micDisplayText
        font.family: "monospace"
        font.pixelSize: 15
        font.bold: true
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: micProc.running = true }
}
