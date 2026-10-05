import QtQuick
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import "../../style"
import "../common"
import "../../common" as Common

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

    FileView {
        id: meminfoFile
        path: "file:///proc/meminfo"
        blockLoading: true
        onTextChanged: {
            var raw = text();
            if (!raw) return;

            var mt = 0, ma = 0, st = 0, sf = 0;
            var lines = raw.split("\n");
            
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

    FileView {
        id: zramFile
        path: "file:///sys/block/zram0/mm_stat"
        blockLoading: true
        onTextChanged: {
            var raw = text().trim();
            if (!raw) return;
            
            var tokens = raw.split(/\s+/).filter(t => t !== "");
            if (tokens.length >= 2) {
                var orig = parseFloat(tokens[0]);
                var compr = parseFloat(tokens[1]);
                
                if (compr > 0) {
                    ramBox.zramRatio = orig / compr;
                    ramBox.zramSavedGiB = (orig - compr) / (1024 * 1024 * 1024);
                }
            }
        }
    }

    // Direct invocation without shell overhead
    Process {
        id: topProcFetcher
        running: false
        command: Common.LuaRunner.cmd("/modules/bar/ram/backend/RamEngine.lua")
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
