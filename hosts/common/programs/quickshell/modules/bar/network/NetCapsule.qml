import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: netBox
    width: 230

    property string netDisplayText: "NET: --"

    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(netBox, netText);
        }
    }

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

                netBox.netDisplayText = "<font color='" + (root.theme ? root.theme.base0C : "green") + "'>NET:</font> " +
                "<font color='" + (root.theme ? root.theme.base05 : "white") + "'>▼" + rxStr.padStart(5, ' ') + "</font> " +
                "<font color='" + (root.theme ? root.theme.base05 : "white") + "'>▲" + txStr.padStart(5, ' ') + "</font>";
            }
        }
    }

    Text {
        id: netText
        anchors.centerIn: parent     // <---- changed
        anchors.margins: 10         // <---- still applies minimum margin from edge
        textFormat: Text.RichText;
        text: netBox.netDisplayText;
        font.family: "monospace";
        font.pixelSize: 20;
        font.bold: true
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: netProc.running = true }
}
