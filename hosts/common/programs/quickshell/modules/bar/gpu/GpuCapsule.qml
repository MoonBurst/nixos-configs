import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"
import "../common"

Item {
    id: gpuBox
    property var barWindow: null
    property string moduleName: "gpu"
    property bool pinTooltip: false
    property string searchQuery: ""

    property var detectedGpus: (shell && shell.settingsManager && shell.settingsManager.availableGpuCards && shell.settingsManager.availableGpuCards.length > 0)
        ? shell.settingsManager.availableGpuCards
        : [{ id: "card0", vendor: "", name: "GPU 0", render: "renderD128", nv_index: "0" }, { id: "card1", vendor: "", name: "GPU 1", render: "renderD129", nv_index: "0" }]

    property int selectedGpuIndex: 0

    function cycleGpu() {
        if (detectedGpus.length <= 1) return;
        selectedGpuIndex = (selectedGpuIndex + 1) % detectedGpus.length;
        if (shell && shell.settingsManager) {
            shell.settingsManager.activeGpuCard = detectedGpus[selectedGpuIndex].id;
        }
        textAccumulatorBuffer = "";
        gpuStatsProc.running = false; gpuStatsProc.running = true;
        gpuProcFetcher.running = false; gpuProcFetcher.running = true;
    }

    Connections {
        target: shell ? shell.settingsManager : null
        function onActiveGpuCardChanged() {
            if (!shell || !shell.settingsManager) return;
            var target = shell.settingsManager.activeGpuCard;
            for (var i = 0; i < gpuBox.detectedGpus.length; i++) {
                if (gpuBox.detectedGpus[i].id === target) {
                    gpuBox.selectedGpuIndex = i;
                    break;
                }
            }
        }
    }

    readonly property var currentGpu: (detectedGpus && detectedGpus.length > selectedGpuIndex) ? detectedGpus[selectedGpuIndex] : null
    readonly property bool isNvidia: (currentGpu && currentGpu.vendor === "10de") || (currentGpu && currentGpu.name && currentGpu.name.toLowerCase().indexOf("nvidia") !== -1)
    readonly property string nvTargetIndex: (currentGpu && currentGpu.nv_index !== undefined) ? currentGpu.nv_index : "0"

    property int tooltipHeight: 440
    property int tooltipCollapsedWidth: 140
    property int tooltipExpandedWidth: 520
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    property string slantLeft: (shell && shell.settingsManager) ? (shell.settingsManager.getModuleSlant(gpuBox.moduleName, "right") === "right" ? "Right" : "Left") : "Right"
    property string slantRight: (shell && shell.settingsManager) ? (shell.settingsManager.getModuleSlant(gpuBox.moduleName, "right") === "right" ? "Right" : "Left") : "Right"
    property int slantWidth: (shell && shell.theme) ? shell.theme.slantWidth : 12

    property string gpuUsageRaw: "0"
    property string gpuTempRaw: "0"
    property string gpuPowerRaw: "0"
    property string gpuVramFreeRaw: "0"
    property string topGpuProcessesText: "Loading GPU processes..."
    property string textAccumulatorBuffer: ""

    readonly property var processLinesArray: topGpuProcessesText.split("\n").filter(line => line.trim() !== "")
    readonly property var filteredProcessLinesArray: {
        if (searchQuery.trim() === "") return processLinesArray;
        var q = searchQuery.trim().toLowerCase();
        return processLinesArray.filter(line => line.toLowerCase().indexOf(q) !== -1);
    }

    implicitWidth: Math.max(200, gpuText.implicitWidth + bg.leftPadding + bg.rightPadding + 28)
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: gpuBox.slantLeft
        slantRight: gpuBox.slantRight
        slantWidth: gpuBox.slantWidth
    }

    Process {
        id: gpuStatsProc
        running: true
        command: [
            "lua",
            Quickshell.shellDir + "/modules/bar/gpu/backend/GpuEngine.lua",
            "stats",
            gpuBox.currentGpu ? gpuBox.currentGpu.id : "card0",
            gpuBox.currentGpu ? (gpuBox.currentGpu.vendor || "") : "",
            gpuBox.isNvidia ? "1" : "0",
            gpuBox.nvTargetIndex
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length === 4) {
                    gpuBox.gpuUsageRaw = parts[0].trim();
                    gpuBox.gpuTempRaw = parts[1].trim();
                    gpuBox.gpuPowerRaw = parts[2].trim();
                    gpuBox.gpuVramFreeRaw = parts[3].trim();
                }
            }
        }
    }

    Process {
        id: gpuProcFetcher
        running: false
        command: [
            "lua",
            Quickshell.shellDir + "/modules/bar/gpu/backend/GpuEngine.lua",
            gpuBox.currentGpu ? gpuBox.currentGpu.id : "card0",
            gpuBox.currentGpu ? (gpuBox.currentGpu.vendor || "") : "",
            gpuBox.isNvidia ? "1" : "0",
            gpuBox.nvTargetIndex
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim() !== "") gpuBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: {
            gpuBox.topGpuProcessesText = gpuBox.textAccumulatorBuffer.trim() !== "" ? gpuBox.textAccumulatorBuffer.trim() : "No active clients on this GPU";
        }
    }

    Timer {
        id: killRefreshTimer
        interval: 300; repeat: false
        onTriggered: {
            gpuBox.textAccumulatorBuffer = "";
            gpuProcFetcher.running = true;
        }
    }

    Text {
        id: gpuText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 6
        anchors.rightMargin: bg.rightPadding + 6
        anchors.topMargin: 2; anchors.bottomMargin: 2

        textFormat: Text.RichText
        font.family: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"
        font.pixelSize: (shell && shell.theme) ? shell.theme.globalFontSize : 14
        font.bold: true
        color: (shell && shell.theme) ? shell.theme.base05 : "yellow"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        clip: true

        text: {
            const usageVal = parseInt(gpuBox.gpuUsageRaw) || 0;
            const currentTemp = parseInt(gpuBox.gpuTempRaw) || 0;
            const currentPower = parseInt(gpuBox.gpuPowerRaw) || 0;
            const currentFreeVram = parseInt(gpuBox.gpuVramFreeRaw) || 0;
            const cardId = gpuBox.currentGpu ? gpuBox.currentGpu.id : "card0";

            const tDanger = (shell && shell.settingsManager) ? shell.settingsManager.getGpuTempDanger(cardId) : 80;
            const tWarn = (shell && shell.settingsManager) ? shell.settingsManager.getGpuTempWarn(cardId) : 70;
            const vDanger = (shell && shell.settingsManager) ? shell.settingsManager.getGpuVramDanger(cardId) : 2;
            const vWarn = (shell && shell.settingsManager) ? shell.settingsManager.getGpuVramWarn(cardId) : 4;

            let tempColor = ((shell && shell.theme) ? shell.theme.base05 : "yellow").toString();
            if (currentTemp >= tDanger) tempColor = ((shell && shell.theme) ? shell.theme.base08 : "#ff0000").toString();
            else if (currentTemp >= tWarn) tempColor = ((shell && shell.theme) ? shell.theme.base09 : "#fe8019").toString();

            let vramColor = ((shell && shell.theme) ? shell.theme.base05 : "yellow").toString();
            if (currentFreeVram <= vDanger) vramColor = ((shell && shell.theme) ? shell.theme.base08 : "#ff0000").toString();
            else if (currentFreeVram <= vWarn) vramColor = ((shell && shell.theme) ? shell.theme.base09 : "#fe8019").toString();

            // Fully dynamic label from detected hardware: no hardcoded strings
            const label = (gpuBox.currentGpu && gpuBox.currentGpu.name) ? gpuBox.currentGpu.name : "GPU";
            const prefix = label + ":";

            return "<font color='" + ((shell && shell.theme) ? shell.theme.base0C : "#04f100") + "'>" + prefix + "</font> " +
                "<font color='" + ((shell && shell.theme) ? shell.theme.base05 : "yellow") + "'>" + usageVal + "%</font> " +
                "<font color='" + tempColor + "'>" + currentTemp + "°C</font> " +
                "<font color='" + ((shell && shell.theme) ? shell.theme.base05 : "yellow") + "'>" + currentPower + "W</font> " +
                "<font color='" + vramColor + "'>" + currentFreeVram + "GiB</font>";
        }
    }

    HoverHandler {
        id: gpuHoverTracker
        onHoveredChanged: {
            if (hovered && !gpuTooltip.isHovered) {
                gpuBox.textAccumulatorBuffer = "";
                gpuProcFetcher.running = true;
            }
        }
    }

    TapHandler {
        onTapped: {
            gpuBox.pinTooltip = !gpuBox.pinTooltip;
            if (gpuBox.pinTooltip) {
                gpuBox.textAccumulatorBuffer = "";
                gpuProcFetcher.running = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: gpuBox.detectedGpus.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton && gpuBox.detectedGpus.length > 1) {
                gpuBox.cycleGpu();
            }
        }
    }

    SlantedTooltip {
        id: gpuTooltip
        moduleItem: gpuBox
        barWindow: gpuBox.barWindow
        tooltipActive: gpuHoverTracker.hovered
        pin: gpuBox.pinTooltip

        tooltipHeight: gpuBox.tooltipHeight
        collapsedCoreWidth: gpuBox.tooltipCollapsedWidth
        expandedCoreWidth: gpuBox.tooltipExpandedWidth
        topOffset: gpuBox.tooltipTopOffset
        rightOffset: gpuBox.tooltipRightOffset
        slantLeft: gpuBox.slantLeft
        slantRight: gpuBox.slantRight

        RowLayout {
            y: 16
            x: gpuTooltip.slantX(y) + 20
            spacing: 8

            Text {
                text: "GPU:"
                font.family: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"
                font.pixelSize: ((shell && shell.theme) ? shell.theme.globalFontSize : 14) - 1
                font.bold: true
                color: (shell && shell.theme) ? shell.theme.base05 : "yellow"
            }

            Repeater {
                model: gpuBox.detectedGpus
                delegate: SlantedBox {
                    id: gpuBtnItem
                    width: gpuBtnText.implicitWidth + 24; height: 24
                    slantLeft: gpuBox.slantLeft
                    slantRight: gpuBox.slantRight
                    slantWidth: height * (gpuBox.slantWidth / gpuBox.height)
                    color: gpuBox.selectedGpuIndex === index ? ((shell && shell.theme) ? shell.theme.base05 : "yellow") : ((shell && shell.theme) ? shell.theme.base02 : "#222222")
                    borderColor: (shell && shell.theme) ? shell.theme.base05 : "yellow"
                    borderWidth: 1

                    Text {
                        id: gpuBtnText
                        anchors.centerIn: parent
                        text: modelData.name || modelData.id
                        font.family: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"
                        font.pixelSize: 11; font.bold: true
                        color: gpuBox.selectedGpuIndex === index ? ((shell && shell.theme) ? shell.theme.base00 : "black") : ((shell && shell.theme) ? shell.theme.base05 : "yellow")
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            gpuBox.selectedGpuIndex = index;
                            if (shell && shell.settingsManager) {
                                shell.settingsManager.activeGpuCard = modelData.id;
                            }
                            gpuBox.textAccumulatorBuffer = "";
                            gpuStatsProc.running = false; gpuStatsProc.running = true;
                            gpuProcFetcher.running = false; gpuProcFetcher.running = true;
                        }
                    }
                }
            }
        }

        ProcessMonitorList {
            tooltip: gpuTooltip
            startY: 100
            listWidth: Math.min(360, gpuTooltip.effectiveCoreWidth - 64)
            lines: gpuBox.filteredProcessLinesArray
            slantLeft: gpuBox.slantLeft; slantRight: gpuBox.slantRight
            onSearchModified: (q) => gpuBox.searchQuery = q
            onKillRequested: killRefreshTimer.start()
            onCloseRequested: {
                gpuBox.pinTooltip = false;
                gpuTooltip.closeTooltip();
            }
        }
    }

    Timer {
        interval: (shell && shell.settingsManager && shell.settingsManager.hardwarePollInterval > 0) ? shell.settingsManager.hardwarePollInterval : 2000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            gpuStatsProc.running = false; gpuStatsProc.running = true;
            if ((gpuHoverTracker.hovered || gpuBox.pinTooltip) && !gpuTooltip.isHovered) {
                gpuBox.textAccumulatorBuffer = "";
                gpuProcFetcher.running = true;
            }
        }
    }
}
