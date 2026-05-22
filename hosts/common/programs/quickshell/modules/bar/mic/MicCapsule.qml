import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

import Theme

Rectangle {
    id: micBox
    width: 140
    height: 35
    radius: 10
    border.width: 3

    // Decoupled color hooks mapped to your Nix Store module constants
    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

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

                // Secure color formatting variables safely bound to your global layout theme
                var micLabelColor = (typeof Theme !== 'undefined' && Theme.base0C !== undefined) ? Theme.base0C : "green";
                var micStatusColor = "yellow";
                if (typeof Theme !== 'undefined' && Theme.base08 !== undefined && Theme.base05 !== undefined) {
                    micStatusColor = isMuted ? Theme.base08 : Theme.base05;
                } else {
                    micStatusColor = isMuted ? "red" : "yellow";
                }

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
        font.family: "monospace";
        font.pixelSize: 20;
        font.bold: true
        // Sync base fallback string configuration parameters dynamically
        color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "white"
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: micProc.running = true }
}
