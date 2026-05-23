import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Rectangle {
    id: netBox

    // FIXED: Expanded capsule layout width to 200px to cleanly accommodate 3 digits + unit labels without boundary cropping
    width: 200
    height: 35
    radius: 10
    border.width: 3

    color: "black"
    border.color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"

    property string downSpeedStr: "0B"
    property string upSpeedStr: "0B"
    property var barWindow: null

    Process {
        id: netStatsProc
        running: true
        command: ["sh", "-c", "interface=$(ip route | awk '/default/ {print $5; exit}'); awk -v iface=\"$interface\" '$1 ~ iface {down=$2; up=$10; print down \":\" up}' /proc/net/dev"]
        
        property real lastDown: 0
        property real lastUp: 0
        property bool isFirstRun: true

        // FIXED: Automated multi-unit conversion engine scaling dynamically across B/s, K, M, and G metrics
        function formatSpeed(bytesDiff) {
            if (bytesDiff < 1024) return Math.round(bytesDiff) + "B";
            var kb = bytesDiff / 1024;
            if (kb < 1024) return Math.round(kb) + "K";
            var mb = kb / 1024;
            if (mb < 1024) return mb.toFixed(1) + "M";
            var gb = mb / 1024;
            return gb.toFixed(1) + "G";
        }

        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length === 2) {
                    var currentDown = parseFloat(parts[0]);
                    var currentUp = parseFloat(parts[1]);

                    if (!netStatsProc.isFirstRun) {
                        var diffDown = currentDown - netStatsProc.lastDown; 
                        var diffUp = currentUp - netStatsProc.lastUp; 

                        netBox.downSpeedStr = netStatsProc.formatSpeed(diffDown);
                        netBox.upSpeedStr = netStatsProc.formatSpeed(diffUp);
                    }

                    netStatsProc.lastDown = currentDown;
                    netStatsProc.lastUp = currentUp;
                    netStatsProc.isFirstRun = false;
                }
            }
        }
    }

    Text {
        id: netText
        anchors.fill: parent
        anchors.margins: 5
        textFormat: Text.RichText
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: {
            const greenColor = (root && root.theme && root.theme.base0C !== undefined) ? root.theme.base0C.toString() : "#04f100";
            const yellowColor = (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow";
            
            return "<font color='" + greenColor + "'>NET:</font> " +
                   "<font color='" + yellowColor + "'>▼</font><font color='" + yellowColor + "'>" + netBox.downSpeedStr + "</font> " +
                   "<font color='" + yellowColor + "'>▲</font><font color='" + yellowColor + "'>" + netBox.upSpeedStr + "</font>";
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            netStatsProc.running = false;
            netStatsProc.running = true;
        }
    }
}
