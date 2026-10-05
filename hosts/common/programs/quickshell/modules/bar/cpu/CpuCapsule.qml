import QtQuick
import Quickshell
import Quickshell.Io
import "../../style"
import "../common"
import "../../common" as Common

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

    property string cpuTempPath: "/sys/class/thermal/thermal_zone0/temp"

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

    // Direct invocation without shell overhead
    Process {
        id: hwmonFinder
        running: true
        command: Common.LuaRunner.cmd("/modules/bar/cpu/backend/CpuEngine.lua", "find-hwmon")
        stdout: SplitParser {
            onRead: data => {
                var clean = data.trim();
                if (clean.length > 0) {
                    cpuBox.cpuTempPath = clean;
                    cpuTempFile.path = "file://" + clean;
                }
            }
        }
    }

    FileView {
        id: cpuStatFile
        path: "file:///proc/stat"
        blockLoading: true
        onTextChanged: {
            var raw = text();
            if (!raw) return;
            var firstLine = raw.split("\n")[0];
            var tokens = firstLine.split(/\s+/).filter(t => t !== "");
            if (tokens.length > 5) {
                var busy = parseFloat(tokens[1]) + parseFloat(tokens[2]) + parseFloat(tokens[3]) + parseFloat(tokens[6]) + parseFloat(tokens[7]);
                var total = busy + parseFloat(tokens[4]) + parseFloat(tokens[5]);

                if (!cpuBox.isFirstRun) {
                    var diffBusy = Math.max(0, busy - cpuBox.lastBusy);
                    var diffTotal = Math.max(1, total - cpuBox.lastTotal);
                    var pct = Math.round((diffBusy * 100) / diffTotal);
                    cpuBox.cpuUsageStr = Math.min(100, Math.max(0, pct)) + "%";
                }
                cpuBox.lastBusy = busy;
                cpuBox.lastTotal = total;
                cpuBox.isFirstRun = false;
            }
        }
    }

    FileView {
        id: cpuTempFile
        path: cpuBox.cpuTempPath === "/sys/class/thermal/thermal_zone0/temp" ? "" : "file://" + cpuBox.cpuTempPath
        blockLoading: true
        onTextChanged: {
            var raw = text().trim();
            if (raw && !isNaN(parseInt(raw))) {
                cpuBox.cpuTempStr = Math.round(parseInt(raw) / 1000) + "°C";
            }
        }
    }

    // Direct invocation without shell overhead
    Process {
        id: topProcFetcher
        running: false
        command: Common.LuaRunner.cmd("/modules/bar/cpu/backend/CpuEngine.lua", "top-procs")
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
            startY: 100
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
            cpuStatFile.reload();
            cpuTempFile.reload();

            if ((cpuHoverTracker.hovered || cpuBox.pinTooltip) && !cpuTooltip.isHovered) {
                cpuBox.textAccumulatorBuffer = "";
                topProcFetcher.running = true;
            }
        }
    }
}
