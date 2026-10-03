import "../../common/Utils.js" as Utils
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import "../../style"

Item {
    id: netBox

    property var barWindow: null
    property string moduleName: "net"
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: netBox.themeSlantWidth

    property int staticWidth: 260

    readonly property int themePadding: shell?.theme?.globalPadding ?? 12
    readonly property int themeFontSize: shell?.theme?.globalFontSize ?? 14
    readonly property string themeFontFamily: shell?.theme?.fontFamily ?? "monospace"
    readonly property int themeSlantWidth: shell?.theme?.slantWidth ?? 12
    readonly property var themeBase00: shell?.theme?.base00 ?? "black"
    readonly property var themeBase02: shell?.theme?.base02 ?? "gray"
    readonly property var themeBase05: shell?.theme?.base05 ?? "yellow"
    readonly property var themeBase08: shell?.theme?.base08 ?? "#fb4934"
    readonly property var themeBase0C: shell?.theme?.base0C ?? "#04f100"

    property string activeInterface: ""
    property string activeHwType: "Ethernet"
    property string activeIp: ""
    property string activeSpeed: ""

    property string downSpeedStr: " 0.0Mb"
    property string upSpeedStr: " 0.0Mb"
    property string pingStr: "    --"

    property int tooltipHeight: 380
    property int tooltipCollapsedWidth: 260
    property int tooltipExpandedWidth: 500
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    implicitWidth: staticWidth
    width: staticWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: netBox.slantLeft
        slantRight: netBox.slantRight
        slantWidth: netBox.slantWidth
    }

    Item {
        id: netTop

        property int pollIntervalMs: (shell && shell.settingsManager && shell.settingsManager.hardwarePollInterval > 0)
        ? shell.settingsManager.hardwarePollInterval
        : 2000
        property int topN: 10
        property var topUsers: []

        property var _prev: ({})
        property var _curr: ({})
        property double _lastPollMs: 0
        property int _pendingSent: -1
        property int _pendingRecv: -1

        Process {
            id: ssProc
            running: false
            command: ["ss", "-tinp", "state", "established"]

            stdout: SplitParser {
                splitMarker: "\n"
                onRead: data => netTop._ingestLine(data)
            }

            onExited: netTop._finalize()
        }

        function _ingestLine(line) {
            if (!line || line.length === 0) return;

            if (line.indexOf("bytes_sent:") !== -1) {
                var s = _extractInt(line, "bytes_sent:");
                if (s >= 0) netTop._pendingSent = s;
            }
            if (line.indexOf("bytes_received:") !== -1) {
                var r = _extractInt(line, "bytes_received:");
                if (r >= 0) netTop._pendingRecv = r;
            }
            if (line.indexOf("users:") !== -1) {
                var pidMatch = line.match(/pid=(\d+)/);
                var nameMatch = line.match(/users:\(\("([^"]+)"/);
                if (pidMatch) {
                    var pid = pidMatch[1];
                    var name = nameMatch ? nameMatch[1] : "?";
                    var rec = netTop._curr[pid];
                    if (!rec) {
                        rec = { down: 0, up: 0, name: name, conns: 0 };
                        netTop._curr[pid] = rec;
                    }
                    if (netTop._pendingRecv > 0) rec.down += netTop._pendingRecv;
                    if (netTop._pendingSent > 0) rec.up += netTop._pendingSent;
                    rec.conns += 1;
                }
                netTop._pendingSent = -1;
                netTop._pendingRecv = -1;
            }
        }

        function _extractInt(line, key) {
            var i = line.indexOf(key);
            if (i === -1) return -1;
            var j = i + key.length;
            var n = 0;
            var any = false;
            while (j < line.length) {
                var c = line.charCodeAt(j);
                if (c < 48 || c > 57) break;
                n = n * 10 + (c - 48);
                any = true;
                j++;
            }
            return any ? n : -1;
        }

        function _finalize() {
            var now = Date.now();
            var elapsedSec = netTop._lastPollMs > 0
            ? Math.max(0.1, (now - netTop._lastPollMs) / 1000.0)
            : (netTop.pollIntervalMs / 1000.0);
            netTop._lastPollMs = now;

            var out = [];
            var curr = netTop._curr;
            var prev = netTop._prev;

            for (var pid in curr) {
                var c = curr[pid];
                var p = prev[pid];
                var dDown = 0;
                var dUp = 0;
                if (p) {
                    dDown = Math.max(0, c.down - p.down);
                    dUp = Math.max(0, c.up - p.up);
                }
                var downBps = dDown / elapsedSec;
                var upBps = dUp / elapsedSec;
                out.push({
                    pid: pid,
                    name: c.name || "?",
                    down: downBps,
                    up: upBps,
                    total: downBps + upBps,
                    conns: c.conns
                });
            }

            out.sort(function(a, b) { return b.total - a.total; });

            netTop._prev = curr;
            netTop._curr = ({});
            netTop.topUsers = out.slice(0, netTop.topN);
        }

        Timer {
            interval: netTop.pollIntervalMs > 0 ? netTop.pollIntervalMs : 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                netTop._curr = ({});
                netTop._pendingSent = -1;
                netTop._pendingRecv = -1;
                ssProc.running = false;
                ssProc.running = true;
            }
        }

        function formatBps(bps) {
            if (!bps || bps < 1) return " 0.0Mb";
            var bits = bps * 8;
            if (bits >= 1024 * 1024 * 1024) {
                var g = (bits / (1024 * 1024 * 1024)).toFixed(1);
                if (g === "10.0") g = "9.9";
                return " " + g + "Gb";
            }
            if (bits >= 1024 * 1024) {
                var m = (bits / (1024 * 1024)).toFixed(1);
                if (m === "10.0") m = "9.9";
                return " " + m + "Mb";
            }
            var k = (bits / 1024).toFixed(1);
            if (k === "10.0") k = "9.9";
            return " " + k + "Kb";
        }

        function formatRow(u) {
            var name = (u.name || "?").substring(0, 12);
            while (name.length < 12) name += " ";
            var pidStr = String(u.pid);
            while (pidStr.length < 6) pidStr = " " + pidStr;
            return pidStr + " " + name + " ▼" + netTop.formatBps(u.down) + " ▲" + netTop.formatBps(u.up);
        }
    }

    // Direct invocation without shell overhead
    Process {
        id: netStatsProc
        running: true
        command: ["lua", Quickshell.shellDir + "/modules/bar/network/backend/NetEngine.lua", "stats"]

        property real lastDown: 0
        property real lastUp: 0
        property bool isFirstRun: true

        function formatSpeed(bytesPerSec) {
            if (!bytesPerSec || bytesPerSec < 1) return " 0.0Mb";
            var bits = bytesPerSec * 8;
            if (bits >= 1024 * 1024 * 1024) {
                var g = (bits / (1024 * 1024 * 1024)).toFixed(1);
                if (g === "10.0") g = "9.9";
                return " " + g + "Gb";
            }
            if (bits >= 1024 * 1024) {
                var m = (bits / (1024 * 1024)).toFixed(1);
                if (m === "10.0") m = "9.9";
                return " " + m + "Mb";
            }
            var k = (bits / 1024).toFixed(1);
            if (k === "10.0") k = "9.9";
            return " " + k + "Kb";
        }

        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length >= 6) {
                    var currentDown = parseFloat(parts[0]);
                    var currentUp = parseFloat(parts[1]);

                    netBox.activeInterface = parts[2].trim();
                    netBox.activeHwType = parts[3].trim();
                    netBox.activeIp = parts[4].trim() === "none" ? "" : parts[4].trim();
                    netBox.activeSpeed = (parts[5].trim() === "none" || parts[5].trim() === "") ? "" : (parts[5].trim() + " Mbps");

                    if (!netStatsProc.isFirstRun) {
                        var diffDown = Math.max(0, (currentDown - netStatsProc.lastDown) / 2.0);
                        var diffUp = Math.max(0, (currentUp - netStatsProc.lastUp) / 2.0);
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

    // Direct invocation without shell overhead
    Process {
        id: pingProc
        running: false
        command: ["lua", Quickshell.shellDir + "/modules/bar/network/backend/NetEngine.lua", "ping"]
        stdout: SplitParser {
            onRead: data => {
                var clean = data.trim();
                if (clean.startsWith("OK:")) {
                    var ms = parseFloat(clean.substring(3));
                    var s = (ms < 1.0) ? "<1ms" : Math.round(ms) + "ms";
                    while (s.length < 6) s = " " + s;
                    netBox.pingStr = s;
                } else {
                    netBox.pingStr = "OFFLINE";
                }
            }
        }
    }

    Component.onCompleted: {
        pingProc.running = true;
    }

    Text {
        id: netText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: 2
        anchors.bottomMargin: 2

        textFormat: Text.RichText
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        clip: true

        text: {
            const greenColor = themeBase0C.toString();
            const yellowColor = themeBase05.toString();
            const redColor = themeBase08.toString();
            const pingColor = netBox.pingStr.indexOf("OFFLIN") !== -1 ? redColor : yellowColor;

            return "<font color='" + greenColor + "'>NET: </font>" +
            "<font color='" + yellowColor + "'>▼" + netBox.downSpeedStr + "</font>" +
            " <font color='" + yellowColor + "'>▲" + netBox.upSpeedStr + "</font>" +
            " <font color='" + pingColor + "'>" + netBox.pingStr + "</font>";
        }
    }

    HoverHandler {
        id: netHoverTracker
    }

    SlantedTooltip {
        id: netTooltip
        moduleItem: netBox
        barWindow: netBox.barWindow
        tooltipActive: netHoverTracker.hovered
        pin: false

        tooltipHeight: netBox.tooltipHeight
        collapsedCoreWidth: netBox.tooltipCollapsedWidth
        expandedCoreWidth: netBox.tooltipExpandedWidth
        topOffset: netBox.tooltipTopOffset
        rightOffset: netBox.tooltipRightOffset
        slantLeft: netBox.slantLeft
        slantRight: netBox.slantRight

        Text {
            y: 20
            x: netTooltip.slantX(y) + 24
            width: Math.max(160, netTooltip.effectiveCoreWidth - 60)
            text: "DEFAULT NETWORK DEVICE:"
            font.family: themeFontFamily
            font.pixelSize: Math.max(12, themeFontSize - 1)
            font.bold: true
            color: themeBase05
            elide: Text.ElideRight
        }

        Row {
            y: 46
            x: netTooltip.slantX(y) + 24
            width: Math.max(160, netTooltip.effectiveCoreWidth - 60)
            spacing: 8

            Text {
                text: "● " + netBox.activeHwType + " (" + (netBox.activeInterface || "none") + ")"
                font.family: "monospace"
                font.pixelSize: Math.max(11, themeFontSize - 2)
                font.bold: true
                color: themeBase0C
            }

            Text {
                visible: netBox.activeSpeed !== ""
                text: "• " + netBox.activeSpeed
                font.family: "monospace"
                font.pixelSize: Math.max(11, themeFontSize - 2)
                color: themeBase05
                opacity: 0.8
            }
        }

        Row {
            y: 70
            x: netTooltip.slantX(y) + 24
            width: Math.max(160, netTooltip.effectiveCoreWidth - 60)
            spacing: 12

            Text {
                visible: netBox.activeIp !== ""
                text: "IP: " + netBox.activeIp
                font.family: "monospace"
                font.pixelSize: Math.max(11, themeFontSize - 2)
                color: themeBase05
                opacity: 0.85
            }

            Text {
                text: "Ping: " + netBox.pingStr.trim()
                font.family: "monospace"
                font.pixelSize: Math.max(11, themeFontSize - 2)
                color: netBox.pingStr.indexOf("OFFLIN") !== -1 ? themeBase08 : themeBase05
                opacity: 0.85
            }
        }

        Text {
            y: 98
            x: netTooltip.slantX(y) + 24
            width: Math.max(160, netTooltip.effectiveCoreWidth - 60)
            text: "TOP NETWORK USERS (BITS/SEC):"
            font.family: themeFontFamily
            font.pixelSize: Math.max(12, themeFontSize - 1)
            font.bold: true
            color: themeBase05
            elide: Text.ElideRight
        }

        Repeater {
            model: netTop.topUsers
            Text {
                y: 122 + (index * 19)
                x: netTooltip.slantX(y) + 24
                width: Math.max(160, netTooltip.effectiveCoreWidth - 60)
                text: netTop.formatRow(modelData)
                font.family: "monospace"
                font.pixelSize: Math.max(10, themeFontSize - 4)
                color: themeBase05
                elide: Text.ElideRight
            }
        }
    }

    Timer {
        interval: (shell && shell.settingsManager && shell.settingsManager.hardwarePollInterval > 0) ? shell.settingsManager.hardwarePollInterval : 2000
        running: true; repeat: true; triggeredOnStart: true
        property int ticks: 0

        onTriggered: {
            netStatsProc.running = false;
            netStatsProc.running = true;
            ticks++;
            if (ticks >= 15) {
                ticks = 0;
                pingProc.running = false;
                pingProc.running = true;
            }
        }
    }
}
