import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io
import "../../style"

Item {
    id: netBox

    width: 260
    height: parent.height

    property string downSpeedStr: "0B"
    property string upSpeedStr: "0B"
    property string pingStr: "??ms"
    property var barWindow: null

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: "Right"
        slantRight: "Right"
    }

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

        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: (shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12
        anchors.bottomMargin: (shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12

        textFormat: Text.RichText
        font.family: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"
        font.pixelSize: (shell && shell.theme) ? (shell.theme.globalFontSize || 14) : 14
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: {
            const greenColor = (shell && shell.theme) ? (shell.theme.base0C || "green").toString() : "green";
            const yellowColor = (shell && shell.theme) ? (shell.theme.base05 || "yellow").toString() : "yellow";
            const redColor = (shell && shell.theme && shell.theme.base08) ? shell.theme.base08.toString() : "#fb4934";
            const pingColor = netBox.pingStr === "OFFLINE" ? redColor : yellowColor;

            return "<font color='" + greenColor + "'>NET:</font> " +
            "<font color='" + yellowColor + "'>▼</font><font color='" + yellowColor + "'>" + netBox.downSpeedStr + "</font> " +
            "<font color='" + yellowColor + "'>▲</font><font color='" + yellowColor + "'>" + netBox.upSpeedStr + "</font> " +
            " <font color='" + pingColor + "'>" + netBox.pingStr + "</font>";
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        property int ticks: 0
        onTriggered: {
            netStatsProc.running = false;
            netStatsProc.running = true;

            ticks++;
            if (ticks >= 5) {
                ticks = 0;
                pingProc.running = false;
                pingProc.running = true;
            }
        }
    }
}
