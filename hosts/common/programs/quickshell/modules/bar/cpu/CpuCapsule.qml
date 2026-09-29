import QtQuick
import Quickshell
import Quickshell.Io
import "../../style"
import "../common"

Item {
    id: cpuBox
    property var barWindow: null
    property string moduleName: "cpu"
    property bool pinTooltip: false
    property string searchQuery: ""

    property int tooltipHeight: 460
    property int tooltipCollapsedWidth: 150
    property int tooltipExpandedWidth: 520
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: (shell && shell.theme) ? shell.theme.slantWidth : 12

    property real lastBusy: 0
    property real lastTotal: 0
    property bool isFirstRun: true
    property string cpuUsageStr: "0%"
    property string cpuTempStr: "0°C"
    property string topProcessesText: "Loading CPU processes..."
    property string textAccumulatorBuffer: ""
    readonly property var processLinesArray: topProcessesText.split("\n").filter(line => line.trim() !== "")

    readonly property var filteredProcessLinesArray: {
        if (searchQuery.trim() === "") return processLinesArray;
        var q = searchQuery.trim().toLowerCase();
        return processLinesArray.filter(line => line.toLowerCase().indexOf(q) !== -1);
    }

    implicitWidth: cpuText.implicitWidth + bg.leftPadding + bg.rightPadding + 20
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: cpuBox.slantLeft
        slantRight: cpuBox.slantRight
        slantWidth: cpuBox.slantWidth
    }

    Process {
        id: cpuStatsProc
        running: true
        command: [
            "sh", "-c",
            "awk '/^cpu / {print $2+$3+$4, $2+$3+$4+$5+$6+$7+$8; exit}' /proc/stat; " +
            "awk '{print int($1/1000); exit}' /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null || echo 0"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var raw = (data || "").trim();
                if (!raw) return;
                var parts = raw.split(" ");
                if (parts.length === 2) {
                    var busy = parseFloat(parts[0]);
                    var total = parseFloat(parts[1]);
                    if (!cpuBox.isFirstRun) {
                        var diffBusy = Math.max(0, busy - cpuBox.lastBusy);
                        var diffTotal = Math.max(1, total - cpuBox.lastTotal);
                        var pct = Math.round((diffBusy * 100) / diffTotal);
                        cpuBox.cpuUsageStr = Math.min(100, Math.max(0, pct)) + "%";
                    }
                    cpuBox.lastBusy = busy;
                    cpuBox.lastTotal = total;
                    cpuBox.isFirstRun = false;
                } else if (parts.length === 1 && !isNaN(parseInt(raw))) {
                    cpuBox.cpuTempStr = raw + "°C";
                }
            }
        }
    }

    Process {
        id: topProcFetcher
        running: false
        command: ["sh", "-c", "ncpu=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1); ps -eo pid,comm,%cpu --sort=-%cpu | head -n 11 | awk -v ncpu=\"$ncpu\" 'NR>1 { cpu_tot = $3 / ncpu; printf \"%s|%-10s %4.1f%%\\n\", $1, substr($2,1,10), cpu_tot }'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim() !== "") cpuBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: {
            if (cpuBox.textAccumulatorBuffer.trim() !== "") {
                cpuBox.topProcessesText = cpuBox.textAccumulatorBuffer.trim();
            }
        }
    }

    Timer {
        id: killRefreshTimer
        interval: 300
        repeat: false
        onTriggered: {
            cpuBox.textAccumulatorBuffer = "";
            topProcFetcher.running = true;
        }
    }

    Text {
        id: cpuText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 4
        anchors.rightMargin: bg.rightPadding + 4
        anchors.topMargin: 2
        anchors.bottomMargin: 2

        textFormat: Text.RichText
        font.family: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"
        font.pixelSize: (shell && shell.theme) ? shell.theme.globalFontSize : 14
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        clip: true

        text: "<font color='" + ((shell && shell.theme) ? shell.theme.base0C : "#04f100") + "'>CPU:</font> " +
              "<font color='" + ((shell && shell.theme) ? shell.theme.base05 : "yellow") + "'>" + cpuBox.cpuUsageStr + " " + cpuBox.cpuTempStr + "</font>"
    }

    HoverHandler {
        id: cpuHoverTracker
        onHoveredChanged: {
            if (hovered && !cpuTooltip.isHovered) {
                cpuBox.textAccumulatorBuffer = "";
                topProcFetcher.running = true;
            }
        }
    }

    TapHandler {
        onTapped: {
            cpuBox.pinTooltip = !cpuBox.pinTooltip;
            if (cpuBox.pinTooltip) {
                cpuBox.textAccumulatorBuffer = "";
                topProcFetcher.running = true;
            }
        }
    }

    SlantedTooltip {
        id: cpuTooltip
        moduleItem: cpuBox
        barWindow: cpuBox.barWindow
        tooltipActive: cpuHoverTracker.hovered
        pin: cpuBox.pinTooltip

        tooltipHeight: cpuBox.tooltipHeight
        collapsedCoreWidth: cpuBox.tooltipCollapsedWidth
        expandedCoreWidth: cpuBox.tooltipExpandedWidth
        topOffset: cpuBox.tooltipTopOffset
        rightOffset: cpuBox.tooltipRightOffset
        slantLeft: cpuBox.slantLeft
        slantRight: cpuBox.slantRight

        Text {
            text: "ACTIVE CPU CLIENTS:"
            font.family: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"
            font.pixelSize: ((shell && shell.theme) ? shell.theme.globalFontSize : 14) - 1
            font.bold: true
            color: (shell && shell.theme) ? shell.theme.base05 : "yellow"
            y: 24
            x: cpuTooltip.slantX(y) + 20
        }

        ProcessMonitorList {
            tooltip: cpuTooltip
            startY: 102
            listWidth: 345
            lines: cpuBox.filteredProcessLinesArray
            slantLeft: cpuBox.slantLeft
            slantRight: cpuBox.slantRight
            onSearchModified: (q) => cpuBox.searchQuery = q
            onKillRequested: killRefreshTimer.start()
            onCloseRequested: {
                cpuBox.pinTooltip = false;
                cpuTooltip.closeTooltip();
            }
        }
    }

    Timer {
        interval: (shell && shell.settingsManager && shell.settingsManager.hardwarePollInterval > 0) ? shell.settingsManager.hardwarePollInterval : 2000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            cpuStatsProc.running = false;
            cpuStatsProc.running = true;
            if ((cpuHoverTracker.hovered || cpuBox.pinTooltip) && !cpuTooltip.isHovered) {
                cpuBox.textAccumulatorBuffer = "";
                topProcFetcher.running = true;
            }
        }
    }
}
