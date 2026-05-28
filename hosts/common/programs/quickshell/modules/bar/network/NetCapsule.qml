import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Rectangle {
    id: netBox

    // FIXED: Layout frames and outlines natively scale to match your global design rule profiles
    width: 200
    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth

    color: shell.theme.base00
    border.color: shell.theme.base05

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
        anchors.margins: shell.theme.globalPadding
        textFormat: Text.RichText
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: {
            const greenColor = shell.theme.base0C.toString();
            const yellowColor = shell.theme.base05.toString();

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
