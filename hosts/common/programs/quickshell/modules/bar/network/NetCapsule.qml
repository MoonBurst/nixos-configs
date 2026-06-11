import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Rectangle {
    id: netBox

    // Layout frames and outlines natively scale to match your global design rule profiles
    width: 300 // Expanded width to accommodate both throughput and latency meters cleanly
    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth

    color: shell.theme.base00
    border.color: shell.theme.base05

    property string downSpeedStr: "0B"
    property string upSpeedStr: "0B"
    property string pingStr: "??ms"
    property var barWindow: null

    // Bandwidth Throughput Statistics Process
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

    // Active Network Latency (Ping) Process
    Process {
        id: pingProc
        running: false
        command: ["ping", "-c", "1", "-W", "1", "1.1.1.1"]

        stdout: SplitParser {
            onRead: data => {
                // Regex matches and extracts round-trip time in milliseconds (e.g. "time=14.2 ms")
                var match = data.match(/time=([0-9.]+)\s*ms/);
                if (match && match.length >= 2) {
                    var ms = parseFloat(match[1]);
                    netBox.pingStr = Math.round(ms) + "ms";
                }
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                netBox.pingStr = "OFFLINE";
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
            const redColor = (typeof shell !== 'undefined' && shell.theme && shell.theme.base08) ? shell.theme.base08.toString() : "#fb4934";

            // If the connection drops, color the "OFFLINE" warning in high-contrast red
            const pingColor = netBox.pingStr === "OFFLINE" ? redColor : yellowColor;

            return "<font color='" + greenColor + "'>NET:</font> " +
            "<font color='" + yellowColor + "'>▼</font><font color='" + yellowColor + "'>" + netBox.downSpeedStr + "</font> " +
            "<font color='" + yellowColor + "'>▲</font><font color='" + yellowColor + "'>" + netBox.upSpeedStr + "</font> " +
            " <font color='" + pingColor + "'>" + netBox.pingStr + "</font>";
        }
    }

    // Centralized Timer handles both processes synchronously to save system resources
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        property int ticks: 0
        onTriggered: {
            // Cycle throughput statistics every 1 second
            netStatsProc.running = false;
            netStatsProc.running = true;

            // Cycle ping network latency every 5 seconds to prevent log bloat
            ticks++;
            if (ticks >= 5) {
                ticks = 0;
                pingProc.running = false;
                pingProc.running = true;
            }
        }
    }
}
