import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Import your custom style module relative to this widget's location
import "../../style"

Item {
    id: micBox

    // ============================================================================
    // PROPERTIES & LAYOUT BINDINGS
    // ============================================================================
    property var barWindow: null
    property string micDisplayText: "Mic: --"

    // Clean state property to track the mute status
    property bool muted: false

    width: 140
    height: parent.height

    // Use your reusable RightStyle component as the background
    RightStyle {
        id: bg
        anchors.fill: parent

        color: shell.theme.base00

        // Safe, null-protected binding that dynamically handles mute outline coloring
        borderColor: (shell.theme && shell.theme.base05) ? (micBox.muted ? shell.theme.base08 : shell.theme.base05) : "transparent"
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

                // Safely update the root state property
                micBox.muted = isMuted;

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
        id: micText
        anchors.fill: parent

        // Dynamic margins clear the slanted edges when MUTED is displayed
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: shell.theme.globalPadding
        anchors.bottomMargin: shell.theme.globalPadding

        textFormat: Text.RichText
        text: micBox.micDisplayText
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: micProc.running = true }
}
