import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

import Theme

Rectangle {
    id: netBox

    // Sovereign sizing rules restore visual visibility matching your bar grid
    width: 230
    height: 35
    radius: 10
    border.width: 3

    // Direct lookups pointing straight to your immutable compiled Nix-Store colors
    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

    property string netDisplayText: "NET: --"

    Process {
        id: netProc
        running: true
        command: [
            "sh", "-c",
            "I=$(ip route | awk '/default/ {print $5; exit}'); [ -z \"$I\" ] && echo \"0|0\" && exit 0; " +
            "R1=$(awk -v i=\"$I\" '$1 ~ i {print $2}' /proc/net/dev); T1=$(awk -v i=\"$I\" '$1 ~ i {print $10}' /proc/net/dev); sleep 1; " +
            "R2=$(awk -v i=\"$I\" '$1 ~ i {print $2}' /proc/net/dev); T2=$(awk -v i=\"$I\" '$1 ~ i {print $10}' /proc/net/dev); " +
            "echo \"$((R2 - R1))|$((T2 - T1))\""
        ]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var speed = data.trim().split("|");
                if (speed.length < 2) return;

                var rx = parseInt(speed[0]), tx = parseInt(speed[1]);
                var rxStr = rx > 1048576 ? (rx / 1048576).toFixed(1) + "M" : Math.round(rx / 1024) + "K";
                var txStr = tx > 1048576 ? (tx / 1048576).toFixed(1) + "M" : Math.round(tx / 1024) + "K";

                // Secure color formatting strings safely bound to your global layout theme
                var netLabelColor = (typeof Theme !== 'undefined' && Theme.base0C !== undefined) ? Theme.base0C : "green";
                var netStatusColor = (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "white";

                netBox.netDisplayText = "<font color='" + netLabelColor + "'>NET:</font> " +
                "<font color='" + netStatusColor + "'>▼" + rxStr.padStart(5, ' ') + "</font> " +
                "<font color='" + netStatusColor + "'>▲" + txStr.padStart(5, ' ') + "</font>";
            }
        }
    }

    Text {
        id: netText
        anchors.centerIn: parent
        textFormat: Text.RichText
        text: netBox.netDisplayText
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        // Set dynamic base fallback color tracking
        color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "white"
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: netProc.running = true }
}
