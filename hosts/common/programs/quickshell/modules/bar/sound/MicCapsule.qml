import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io
import "../../style"

Item {
    id: micBox

    property var barWindow: null
    property string micDisplayText: "Mic: --"
    property bool muted: false

    width: 140
    height: parent.height

    // Centralized SlantedBox Background (Handles mute outlines dynamically)
    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: "Right"
        slantRight: "Right"

        borderColor: {
            if (shell && shell.theme) {
                return micBox.muted ? (shell.theme.base08 || "red") : (shell.theme.base05 || "yellow");
            }
            return "yellow";
        }
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

                micBox.muted = isMuted;

                var mNum = "0%";
                if (!isMuted) {
                    var mMatch = raw.match(/[0-9.]+/);
                    if (mMatch) mNum = Math.round(parseFloat(mMatch[0]) * 100) + "%";
                } else {
                    mNum = "MUTED";
                }

                var micLabelColor = (shell && shell.theme) ? (shell.theme.base0C || "green").toString() : "green";
                var micStatusColor = isMuted ? ((shell && shell.theme) ? shell.theme.base08.toString() : "red") : ((shell && shell.theme) ? shell.theme.base05.toString() : "yellow");

                micBox.micDisplayText = "<font color='" + micLabelColor + "'>Mic:</font> <font color='" + micStatusColor + "'>" + mNum + "</font>";
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
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: (shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12
        anchors.bottomMargin: (shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12

        textFormat: Text.RichText
        text: micBox.micDisplayText
        font.family: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"
        font.pixelSize: (shell && shell.theme) ? (shell.theme.globalFontSize || 14) : 14
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: micProc.running = true }
}
