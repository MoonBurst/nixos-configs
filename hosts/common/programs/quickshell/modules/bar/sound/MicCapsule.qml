import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: micBox

    // ============================================================================
    // PROPERTIES & LAYOUT BINDINGS
    // ============================================================================
    property var barWindow: null
    property string micDisplayText: "Mic: --"

    width: 140
    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth

    color: shell.theme.base00
    border.color: shell.theme.base05

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

                var micLabelColor = shell.theme.base0C;
                var micStatusColor = isMuted ? shell.theme.base08 : shell.theme.base05;

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
        id: micText;
        anchors.centerIn: parent;
        textFormat: Text.RichText;
        text: micBox.micDisplayText;
        font.family: shell.theme.fontFamily;
        font.pixelSize: shell.theme.globalFontSize;
        font.bold: true
        color: shell.theme.base05
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: micProc.running = true }
}
