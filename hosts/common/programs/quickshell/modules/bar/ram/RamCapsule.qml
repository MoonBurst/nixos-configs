import QtQuick
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import "../../style"
import "../common"

Item {
    id: ramBox
    property var barWindow: null
    property string moduleName: "ram"
    property bool pinTooltip: false
    property string searchQuery: ""

    property int tooltipHeight: 460
    property int tooltipCollapsedWidth: 134
    property int tooltipExpandedWidth: 600
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: (shell && shell.theme) ? shell.theme.slantWidth : 12

    // Native Memory & ZRAM Allocation Registers
    property real totalGiB: 0.0
    property real availableGiB: 0.0
    property real effectiveAvailGiB: 0.0
    property real effectiveTotalGiB: 0.0
    property real zramRatio: 1.0
    property real zramSavedGiB: 0.0

    property string topProcessesText: "Loading system processes..."
    property string textAccumulatorBuffer: ""
    readonly property var processLinesArray: topProcessesText.split("\n").filter(line => line.trim() !== "")

    readonly property var filteredProcessLinesArray: {
        if (searchQuery.trim() === "") return processLinesArray;
        var q = searchQuery.trim().toLowerCase();
        return processLinesArray.filter(line => line.toLowerCase().indexOf(q) !== -1);
    }

    implicitWidth: ramText.implicitWidth + bg.leftPadding + bg.rightPadding + 20
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: ramBox.slantLeft
        slantRight: ramBox.slantRight
        slantWidth: ramBox.slantWidth
    }

    // 1. NATIVE FILE VIEW: TRACKS KERNEL STATS WITH ZERO PROCESS FORKS
    FileView {
        id: meminfoFile
        path: "file:///proc/meminfo"
        blockLoading: true
        onTextChanged: {
            var raw = text();
            if (!raw) return;

            var mt = 0, ma = 0, st = 0, sf = 0;
            var lines = raw.split("\n");
            
            // Clean native micro-lexer replaces your old background awk parser block
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];
                if (line.startsWith("MemTotal:")) mt = parseFloat(line.replace(/[^0-9]/g, ""));
                else if (line.startsWith("MemAvailable:")) ma = parseFloat(line.replace(/[^0-9]/g, ""));
                else if (line.startsWith("SwapTotal:")) st = parseFloat(line.replace(/[^0-9]/g, ""));
                else if (line.startsWith("SwapFree:")) sf = parseFloat(line.replace(/[^0-9]/g, ""));
            }

            if (mt > 0 && ma > 0) {
                ramBox.totalGiB = mt / (1024 * 1024);
                ramBox.availableGiB = ma / (1024 * 1024);
                ramBox.effectiveAvailGiB = (ma + sf) / (1024 * 1024);
                ramBox.effectiveTotalGiB = (mt + st) / (1024 * 1024);
            }
        }
    }

    // 2. NATIVE FILE VIEW: COMPUTES VIRTUAL ZRAM COMPRESSION METRICS
    FileView {
        id: zramFile
        path: "file:///sys/block/zram0/mm_stat"
        blockLoading: true
        onTextChanged: {
            var raw = text().trim();
            if (!raw) return;
            
            var tokens = raw.split(/\s+/).filter(t => t !== "");
            if (tokens.length >= 2) {
                var orig = parseFloat(tokens[0]); // Uncompressed data size
                var compr = parseFloat(tokens[1]); // Compressed size footprint
                
                if (compr > 0) {
                    ramBox.zramRatio = orig / compr;
                    ramBox.zramSavedGiB = (orig - compr) / (1024 * 1024 * 1024);
                }
            }
        }
    }

    // 3. LAZY-LOADED TOP MEMORY CONSUMERS PROBE
    // Stays completely asleep (running: false) until the user opens the tooltip panel
    Process {
        id: topProcFetcher
        running: false
        command: [
            "sh", "-c",
            "total_mem=$(awk '/MemTotal/ {print $2/1024}' /proc/meminfo); ps -eo pid,comm,%mem --sort=-%mem | awk -v total=\"$total_mem\" 'NR>1 { pid=$1; cmd=$2; pct=$3; mem_mb = (pct / 100) * total; if (mem_mb > 0) { is_raw = 1; sf = \"/proc/\" pid \"/status\"; while ((getline line < sf) > 0) { if (line ~ /^VmSwap:/) { split(line, a, \"[ \\t]+\"); if (a[2] > 0) is_raw = 0; break; } } close(sf); if (mem_mb >= 1024) { size_str = sprintf(\"%.1fG\", mem_mb/1024) } else { size_str = sprintf(\"%dM\", mem_mb) }; printf \"%s|%d|%-10s %5s %4.1f%%\\n\", pid, is_raw, substr(cmd, 1, 10), size_str, pct; count++ } if (count >= 10) exit }'"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim() !== "") ramBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: {
            ramBox.topProcessesText = ramBox.textAccumulatorBuffer.trim() !== "" ? ramBox.textAccumulatorBuffer.trim() : "No active engine clients";
        }
    }

    Timer {
        id: killRefreshTimer
        interval: 300
        repeat: false
        onTriggered: {
            ramBox.textAccumulatorBuffer = "";
            topProcFetcher.running = true;
        }
    }

    Text {
        id: ramText
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

        text: {
            const greenColor = ((shell && shell.theme) ? shell.theme.base0C : "#04f100").toString();
            var displayAvail = ramBox.effectiveAvailGiB;
            var displayTotal = ramBox.effectiveTotalGiB;
            var usedGiB = displayTotal - displayAvail;
            var usageRatio = (displayTotal > 0) ? (usedGiB / displayTotal) : 0.0;

            var dataColor = ((shell && shell.theme) ? shell.theme.base05 : "yellow").toString();
            if (usageRatio >= 0.85) dataColor = ((shell && shell.theme) ? shell.theme.base08 : "#ff0000").toString();
            else if (usageRatio >= 0.50) dataColor = ((shell && shell.theme) ? shell.theme.base09 : "#fe8019").toString();

            var valueStr = displayAvail === 0.0 ? " -- GiB" : (" " + displayAvail.toFixed(1) + " GiB");
            return "<font color='" + greenColor + "'>RAM:</font><font color='" + dataColor + "'>" + valueStr + "</font>";
        }
    }

    HoverHandler {
        id: ramHoverTracker
        onHoveredChanged: {
            if (hovered && !ramTooltip.isHovered) {
                ramBox.textAccumulatorBuffer = "";
                topProcFetcher.running = true;
            }
        }
    }

    TapHandler {
        onTapped: {
            ramBox.pinTooltip = !ramBox.pinTooltip;
            if (ramBox.pinTooltip) {
                ramBox.textAccumulatorBuffer = "";
                topProcFetcher.running = true;
            }
        }
    }

    SlantedTooltip {
        id: ramTooltip
        moduleItem: ramBox
        barWindow: ramBox.barWindow
        tooltipActive: ramHoverTracker.hovered
        pin: ramBox.pinTooltip

        tooltipHeight: ramBox.tooltipHeight
        collapsedCoreWidth: ramBox.tooltipCollapsedWidth
        expandedCoreWidth: ramBox.tooltipExpandedWidth
        topOffset: ramBox.tooltipTopOffset
        rightOffset: ramBox.tooltipRightOffset
        slantLeft: ramBox.slantLeft
        slantRight: ramBox.slantRight

        Text {
            text: "TOP RAM CONSUMERS:"
            font.family: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"
            font.pixelSize: ((shell && shell.theme) ? shell.theme.globalFontSize : 14) - 1
            font.bold: true
            color: (shell && shell.theme) ? shell.theme.base05 : "yellow"
            y: 18
            x: ramTooltip.slantX(y) + 20
        }

        RowLayout {
            y: 38
            x: ramTooltip.slantX(y) + 20
            spacing: 10

            Text { text: "ZRAM: " + ramBox.zramRatio.toFixed(2) + "x"; font.family: "monospace"; font.pixelSize: 12; font.bold: true; color: (shell && shell.theme) ? shell.theme.base0C : "#04f100" }
            Text { text: "SAVED: " + ramBox.zramSavedGiB.toFixed(1) + "G"; font.family: "monospace"; font.pixelSize: 12; color: (shell && shell.theme) ? shell.theme.base09 : "#fe8019" }
            Text { text: "PHYS: " + ramBox.availableGiB.toFixed(1) + "/" + ramBox.totalGiB.toFixed(0) + "G"; font.family: "monospace"; font.pixelSize: 12; color: (shell && shell.theme) ? shell.theme.base05 : "yellow"; opacity: 0.7 }
        }

        RowLayout {
            y: 56
            x: ramTooltip.slantX(y) + 20
            spacing: 12

            Text { text: "⚡ 100% Physical RAM"; font.family: "monospace"; font.pixelSize: 11; font.bold: true; color: (shell && shell.theme) ? shell.theme.base0C : "#04f100" }
            Text { text: "■ Compressed/Swappable"; font.family: "monospace"; font.pixelSize: 11; color: (shell && shell.theme) ? shell.theme.base05 : "yellow"; opacity: 0.8 }
        }

        ProcessMonitorList {
            tooltip: ramTooltip
            startY: 128
            listWidth: 400
            lines: ramBox.filteredProcessLinesArray
            slantLeft: ramBox.slantLeft
            slantRight: ramBox.slantRight
            onSearchModified: (q) => ramBox.searchQuery = q
            onKillRequested: killRefreshTimer.start()
            onCloseRequested: {
                ramBox.pinTooltip = false;
                ramTooltip.closeTooltip();
            }
        }
    }

// Static Polling Clock: Synchronizes hardware buffers directly inside memory layout
Timer {
id: statsRefreshTimer
interval: (shell && shell.settingsManager && shell.settingsManager.hardwarePollInterval > 0) ? shell.settingsManager.hardwarePollInterval : 2000
running: true; repeat: true; triggeredOnStart: true
onTriggered: {
meminfoFile.reload();
zramFile.reload();
if ((ramHoverTracker.hovered || ramBox.pinTooltip) && !ramTooltip.isHovered) {
ramBox.textAccumulatorBuffer = "";
topProcFetcher.running = true;
}
}
}
}
