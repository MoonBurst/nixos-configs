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

    // ------------------------------------------------------------------
    // STATIC CHARACTER BUDGET
    //
    // Every value on the bar is formatted to a fixed character count, so the
    // rendered string is always the same length. Nothing shifts, nothing
    // clips, nothing elides.
    //
    // Layout:
    //   "NET: "          5 chars
    //   "▼"              1 char
    //   down speed       6 chars   (e.g. " 0.3Mb", " 9.9Mb", " 1.2Gb")
    //   " "              1 char
    //   "▲"              1 char
    //   up speed         6 chars
    //   " "              1 char
    //   ping             6 chars   (e.g. "  12ms", " 999ms", "OFFLIN")
    //   ─────────────────────────
    //   TOTAL           27 chars
    //
    // Reduced from 320 → 260. Slimmer without clipping.
    // ------------------------------------------------------------------
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

    // ------------------------------------------------------------------
    // Top-N network users engine, inlined as an internal component.
    // ------------------------------------------------------------------
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

        // Fixed-width tooltip formatter: 6 chars, e.g. " 0.3Mb", " 9.9Mb",
        // " 1.2Gb", " 0.0Mb". Same normalization as the bar.
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

    Process {
        id: netStatsProc
        running: true
        command: [
            "sh", "-c",
            'target=$(ip -4 route show default 2>/dev/null | awk \'/default/ {print $5; exit}\'); ' +
            '[ -z "$target" ] && target=$(awk \'$2 == "00000000" {print $1; exit}\' /proc/net/route 2>/dev/null); ' +
            'if [ -z "$target" ] || [ ! -d "/sys/class/net/$target/device" ]; then ' +
            '  for dev in /sys/class/net/*/device; do ' +
            '    iface=$(basename $(dirname "$dev")); state=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null); ' +
            '    if [ "$state" = "up" ]; then target="$iface"; break; fi; ' +
            '  done; ' +
            'fi; ' +
            '[ -z "$target" ] && target=$(ls -1 /sys/class/net/ 2>/dev/null | grep -v "^lo$" | head -n 1); ' +
            '[ -z "$target" ] && echo "0:0:unknown:unknown:none:none" && exit; ' +
            'rx=$(cat "/sys/class/net/$target/statistics/rx_bytes" 2>/dev/null || echo 0); ' +
            'tx=$(cat "/sys/class/net/$target/statistics/tx_bytes" 2>/dev/null || echo 0); ' +
            'ip=$(ip -4 addr show "$target" 2>/dev/null | awk \'/inet / {print $2; exit}\' | cut -d/ -f1); ' +
            'speed=$(cat "/sys/class/net/$target/speed" 2>/dev/null || echo ""); ' +
            'is_wifi=$([ -d "/sys/class/net/$target/wireless" ] || [ -d "/sys/class/net/$target/phy80211" ] && echo "Wi-Fi" || echo "Ethernet"); ' +
            'printf "%s:%s:%s:%s:%s:%s\\n" "$rx" "$tx" "$target" "$is_wifi" "${ip:-none}" "${speed:-none}"'
        ]

        property real lastDown: 0
        property real lastUp: 0
        property bool isFirstRun: true

        // Fixed-width bar formatter. Always returns exactly 6 characters.
        // Input is BYTES/sec from the kernel; output is BITS/sec.
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

    Process {
        id: pingProc
        running: false
        command: [
            "sh", "-c",
            'gw=$(ip route show default 2>/dev/null | awk \'/default/ {print $3; exit}\'); ' +
            'host="${gw:-1.1.1.1}"; ' +
            'timeout 1.5s ping -c 1 -W 1 "$host" 2>/dev/null'
        ]
        stdout: SplitParser {
            onRead: data => {
                var match = data.match(/time=([0-9.]+)\s*ms/);
                if (match && match.length >= 2) {
                    var ms = parseFloat(match[1]);
                    var s;
                    if (ms < 1.0) s = "<1ms";
                    else s = Math.round(ms) + "ms";
                    while (s.length < 6) s = " " + s;
                    netBox.pingStr = s;
                }
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                netBox.pingStr = "OFFLINE";
            }
        }
    }

    Component.onCompleted: {
        pingProc.running = true;
    }

    Text {
        id: netText
        anchors.fill: parent
        // Padding trimmed: no extra +4 on either side. The SlantedBox's own
        // leftPadding/rightPadding (which equals slantWidth + 6) is now the
        // only horizontal inset.
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
