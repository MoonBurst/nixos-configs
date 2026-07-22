// NetCapsule.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import "../../style"

Item {
    id: netBox

    width: 260
    height: parent ? parent.height : 40

    // =========================================================================
    // SAFE STRONGLY-TYPED THEME FALLBACKS (Resolves startup warnings)
    // =========================================================================
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property var themeBase00: (shell && shell.theme && shell.theme.base00 !== undefined) ? shell.theme.base00 : "black"
    readonly property var themeBase02: (shell && shell.theme && shell.theme.base02 !== undefined) ? shell.theme.base02 : "gray"
    readonly property var themeBase05: (shell && shell.theme && shell.theme.base05 !== undefined) ? shell.theme.base05 : "yellow"
    readonly property var themeBase08: (shell && shell.theme && shell.theme.base08 !== undefined) ? shell.theme.base08 : "#fb4934"
    readonly property var themeBase0C: (shell && shell.theme && shell.theme.base0C !== undefined) ? shell.theme.base0C : "green"
    // =========================================================================

    property string downSpeedStr: "0B"
    property string upSpeedStr: "0B"
    property string pingStr: "??ms"
    property var barWindow: null

    // =========================================================================
    //  EDITABLE TOOLTIP CONFIGURATION
    // =========================================================================
    property int tooltipHeight: 400          // Vertical height of the expanded box
    property int tooltipCollapsedWidth: 240  // Sleek, thin width during unroll
    property int tooltipExpandedWidth: 437  // Final horizontal width once fully open
    property int tooltipTopOffset: -2       // Vertical spacing (px)
    property int tooltipRightOffset: 21      // Horizontal alignment (px)
    // =========================================================================

    // Slant configuration matching your SlantedBox setup
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: netBox.themeSlantWidth

    property string topProcessesText: "Loading network processes..."
    property string textAccumulatorBuffer: ""
    readonly property var processLinesArray: topProcessesText.split("\n").filter(line => line.trim() !== "")

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: netBox.slantLeft
        slantRight: netBox.slantRight
        slantWidth: netBox.slantWidth
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

    // NixOS-Aware Real-time Process Bandwidth Sniffer
    Process {
        id: topNetProcFetcher
        running: false
        command: [
            "sh",
            "-c",
            "nethogs_bin=$(command -v /run/wrappers/bin/nethogs || command -v nethogs); interface=$(ip route | awk '/default/ {print $5; exit}'); $nethogs_bin -t -c 2 \"$interface\" 2>/dev/null | awk '/Refreshing:/ {cycle++} cycle==2 && $1 != \"Refreshing:\" && $1 != \"PID\" && $1 != \"\" {if (NF == 3) {prog_full = $1; sub(/\\/[^\\/]+\\/[^\\/]+$/, \"\", prog_full); split(prog_full, path, \"/\"); prog = path[length(path)]; if (prog == \"\") prog = prog_full; sent = $2; recv = $3;} else {split($3, path, \"/\"); prog = path[length(path)]; if (prog == \"\") prog = $3; sent = $5; recv = $6;} total = sent + recv; if (prog ~ /^[0-9]+\\.[0-9]+/ || prog ~ /:/) {prog = \"[system/raw]\"} if (prog != \"\") {speeds[prog] += total}} END {for (p in speeds) {tot = speeds[p]; if (tot > 0.01) {speedStr = (tot < 1024.0) ? sprintf(\"%.1f KB/s\", tot) : sprintf(\"%.1f MB/s\", tot/1024.0); printf \"%.2f %-15s   %11s\\n\", tot, substr(p, 1, 15), speedStr}}}' | sort -rn | head -n 10 | cut -d' ' -f2-"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data && data.trim() !== "") {
                    netBox.textAccumulatorBuffer += data + "\n"
                }
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                netBox.topProcessesText = "Failed to run packet sniffer.\n\nVerify that the NixOS security wrapper is set:\n\nsecurity.wrappers.nethogs = {\n  source = \"\${pkgs.nethogs}/bin/nethogs\";\n  capabilities = \"cap_net_admin,cap_net_raw+ep\";\n  owner = \"root\";\n  group = \"root\";\n};"
            } else if (netBox.textAccumulatorBuffer.trim() === "") {
                netBox.topProcessesText = "No active network traffic.\n(Waiting for transfers...)"
            } else {
                netBox.topProcessesText = netBox.textAccumulatorBuffer.trim()
            }
        }
    }

    Text {
        id: netText
        anchors.fill: parent

        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: themePadding
        anchors.bottomMargin: themePadding

        textFormat: Text.RichText
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: {
            const greenColor = themeBase0C.toString();
            const yellowColor = themeBase05.toString();
            const redColor = themeBase08.toString();
            const pingColor = netBox.pingStr === "OFFLINE" ? redColor : yellowColor;

            return "<font color='" + greenColor + "'>NET:</font> " +
            "<font color='" + yellowColor + "'>▼</font><font color='" + yellowColor + "'>" + netBox.downSpeedStr + "</font> " +
            "<font color='" + yellowColor + "'>▲</font><font color='" + yellowColor + "'>" + netBox.upSpeedStr + "</font> " +
            " <font color='" + pingColor + "'>" + netBox.pingStr + "</font>";
        }
    }

    HoverHandler {
        id: netHoverTracker
        onHoveredChanged: {
            if (hovered && !topNetProcFetcher.running) {
                netBox.textAccumulatorBuffer = ""
                topNetProcFetcher.running = true
            }
        }
    }

    // Tooltip Window (Directly Instantiated for smooth reverse collapse)
    SlantedTooltip {
        id: netTooltip
        moduleItem: netBox
        barWindow: netBox.barWindow
        tooltipActive: netHoverTracker.hovered
        pin: false

        // Maps configuration variables defined at the top
        tooltipHeight: netBox.tooltipHeight
        collapsedCoreWidth: netBox.tooltipCollapsedWidth
        expandedCoreWidth: netBox.tooltipExpandedWidth
        topOffset: netBox.tooltipTopOffset
        rightOffset: netBox.tooltipRightOffset

        slantLeft: netBox.slantLeft
        slantRight: netBox.slantRight

        Text {
            text: "TOP NET CONSUMERS (SPEED):"
            font.family: themeFontFamily
            font.pixelSize: themeFontSize - 1
            font.bold: true
            color: themeBase05
            y: 35
            x: netTooltip.slantX(y) + 24
        }

        Rectangle {
            height: 2
            color: themeBase02
            width: 360
            y: 65
            x: netTooltip.slantX(y) + 24
        }

        Repeater {
            model: netBox.processLinesArray.length
            Text {
                text: netBox.processLinesArray[index]
                font.family: "monospace"
                font.pixelSize: themeFontSize - 1
                color: themeBase05
                y: 95 + (index * 28)
                x: netTooltip.slantX(y) + 24
            }
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

            if (netHoverTracker.hovered && !topNetProcFetcher.running) {
                netBox.textAccumulatorBuffer = ""
                topNetProcFetcher.running = true
            }
        }
    }
}
