import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

Item {
    id: gpuBox

    // Standardized Tooltip Sizing
    property int tooltipHeight: 420
    property var barWindow: null
    //Slant config
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: shell.theme.slantWidth

    readonly property real tooltipSlantWidth: (gpuBox.height > 0)
    ? (tooltipHeight * (slantWidth / gpuBox.height))
    : 15

    // Standardized Tooltip Sizing
    property int tooltipWidth: 380 + (tooltipSlantWidth * 2)

    property string gpuUsageRaw: "0"
    property string gpuTempRaw: "0"
    property string gpuPowerRaw: "0"
    property string gpuVramFreeRaw: "0"
    property string topGpuProcessesText: "Loading GPU processes..."
    property string textAccumulatorBuffer: ""

    readonly property var processLinesArray: topGpuProcessesText.split("\n").filter(line => line.trim() !== "")

    // Toggle to pin the tooltip open for screenshots (Click the GPU capsule to toggle)
    property bool pinTooltip: false

    // Centralized SlantedBox Background
    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: gpuBox.slantLeft
        slantRight: gpuBox.slantRight
        slantWidth: gpuBox.slantWidth
    }

    Binding { target: gpuBox; property: "Layout.preferredWidth"; value: gpuText.implicitWidth + gpuBox.leftPadding + gpuBox.rightPadding }
    Binding { target: gpuBox; property: "width"; value: gpuText.implicitWidth + gpuBox.leftPadding + gpuBox.rightPadding }

    height: parent.height

    // Metric Data Collector (AMD/Nvidia)
    Process {
        id: gpuStatsProc
        running: true
        command: [
            "sh", "-c",
            "if command -v nvidia-smi >/dev/null 2>&1; then stats=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw,memory.free --format=csv,noheader,nounits 2>/dev/null); if [ ! -z \"$stats\" ]; then usage=$(echo \"$stats\" | awk -F', ' '{print $1}'); temp=$(echo \"$stats\" | awk -F', ' '{print $2}'); power=$(echo \"$stats\" | awk -F', ' '{print int($3)}'); free_vram=$(echo \"$stats\" | awk -F', ' '{printf \"%.0f\", $4/1024}'); echo \"$usage:$temp:$power:$free_vram\"; exit; fi; fi; card_dir=$(ls -d /sys/class/drm/card*/device 2>/dev/null | head -n 1); [ -z \"$card_dir\" ] && echo '0:0:0:0' && exit; usage=$(cat \"$card_dir/gpu_busy_percent\" 2>/dev/null || echo '0'); temp=$(awk '{print int($1/1000)}' \"$card_dir/hwmon\"/hwmon*/temp1_input 2>/dev/null | head -n 1 || echo '0'); power=$(awk '{print int($1/1000000)}' \"$card_dir/hwmon\"/hwmon*/power1_average 2>/dev/null | head -n 1 || echo '0'); total=$(cat \"$card_dir/mem_info_vram_total\" 2>/dev/null || echo '0'); used=$(cat \"$card_dir/mem_info_vram_used\" 2>/dev/null || echo '0'); free_vram=$(awk -v t=\"$total\" -v u=\"$used\" 'BEGIN {printf \"%.0f\", (t-u)/1073741824}'); echo \"$usage:$temp:$power:$free_vram\""
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length === 4) {
                    gpuBox.gpuUsageRaw = parts[0];
                    gpuBox.gpuTempRaw = parts[1];
                    gpuBox.gpuPowerRaw = parts[2];
                    gpuBox.gpuVramFreeRaw = parts[3];
                }
            }
        }
    }

    // Process Scanner
    Process {
        id: gpuProcFetcher
        running: false
        command: [
            "sh", "-c",
            "if command -v nvidia-smi >/dev/null 2>&1; then out=$(nvidia-smi --query-compute-apps=name,utilization.gpu --format=csv,noheader,nounits 2>/dev/null); if [ ! -z \"$out\" ]; then echo \"$out\" | awk -F', ' '{printf \"%-15s %4s%%\\n\", substr($1,1,15), $2}'; exit; fi; fi; card_dir=$(ls -d /sys/class/drm/card*/device 2>/dev/null | head -n 1); total_load=$(cat \"$card_dir/gpu_busy_percent\" 2>/dev/null || echo 0); out=$(ps -eo comm,rss --sort=-rss | awk -v total_gpu=\"$total_load\" 'NR>1 { mib=int($2/1024); if(mib>150 && $1!=\"sh\" && $1!=\"bash\" && $1!=\"systemd\") { proc[NR]=$1; mem[NR]=mib; sum+=mib } } END { if(sum==0) sum=1; for(i in proc) { share=(mem[i]/sum)*total_gpu; if(share>0.0 || mem[i]>500) printf \"%-15s %4.1f%%\\n\", substr(proc[i],1,15), share } }' | sort -rn -k2,2 | head -n 10); if [ ! -z \"$out\" ]; then echo \"$out\"; else echo 'No active engine clients'; fi"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim() !== "") gpuBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: {
            gpuBox.topGpuProcessesText = gpuBox.textAccumulatorBuffer.trim() !== "" ? gpuBox.textAccumulatorBuffer.trim() : "No active engine clients";
        }
    }

    // Main Canvas Display Text
    Text {
        id: gpuText
        anchors.fill: parent

        anchors.leftMargin: gpuBox.leftPadding
        anchors.rightMargin: gpuBox.rightPadding
        anchors.topMargin: shell.theme.globalPadding
        anchors.bottomMargin: shell.theme.globalPadding

        textFormat: Text.RichText
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: {
            const currentTemp = parseInt(gpuBox.gpuTempRaw) || 0;
            const currentFreeVram = parseInt(gpuBox.gpuVramFreeRaw) || 0;

            let tempColor = shell.theme.base05.toString();
            if (currentTemp >= 80) tempColor = shell.theme.base08.toString();
            else if (currentTemp >= 70) tempColor = shell.theme.base09.toString();

            let vramColor = shell.theme.base05.toString();
            if (currentFreeVram <= 4) vramColor = shell.theme.base08.toString();
            else if (currentFreeVram <= 12) vramColor = shell.theme.base09.toString();

            function formatStat(rawVal, targetLength, activeColor) {
                let padCount = targetLength - rawVal.length;
                let zerosStr = padCount > 0 ? "<font color='" + shell.theme.base00.toString() + "'>" + "0".repeat(padCount) + "</font>" : "";
                return zerosStr + "<font color='" + activeColor + "'>" + rawVal + "</font>";
            }

            return "<font color='" + shell.theme.base0C.toString() + "'>GPU:</font> " +
            formatStat(gpuBox.gpuUsageRaw, 2, shell.theme.base05.toString()) + "<font color='" + shell.theme.base05.toString() + "'>%</font> " +
                formatStat(gpuBox.gpuTempRaw, 2, tempColor) + "<font color='" + tempColor + "'>°C</font> " +
                    formatStat(gpuBox.gpuPowerRaw, 3, shell.theme.base05.toString()) + "<font color='" + shell.theme.base05.toString() + "'>W</font> " +
                        formatStat(gpuBox.gpuVramFreeRaw, 2, vramColor) + "<font color='" + vramColor + "'>GiB</font>";
        }
    }

    HoverHandler {
        id: gpuHoverTracker
        onHoveredChanged: if (hovered) { gpuBox.textAccumulatorBuffer = ""; gpuProcFetcher.running = true; }
    }

    // Click to toggle/pin the tooltip
    TapHandler {
        onTapped: {
            gpuBox.textAccumulatorBuffer = "";
            gpuProcFetcher.running = true;
        //    gpuBox.pinTooltip = !gpuBox.pinTooltip;
        }
    }

    // Panel Window Loader
    Loader {
        active: gpuHoverTracker.hovered || gpuBox.pinTooltip

        sourceComponent: Component {
            PanelWindow {
                screen: gpuBox.barWindow ? gpuBox.barWindow.screen : null
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-gpu-tooltip"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                anchors.top: true
                anchors.right: true

                WlrLayershell.margins.top: shell.theme.globalPadding + 55
                WlrLayershell.margins.right: gpuBox.barWindow ? Math.max(10 + shell.theme.globalPadding, gpuBox.barWindow.width - gpuBox.mapToItem(null, 0, 0).x - (gpuBox.width / 2) - (gpuBox.tooltipWidth / 2)) : 10

                implicitWidth: gpuBox.tooltipWidth
                implicitHeight: gpuBox.tooltipHeight
                color: "transparent"

                // Tooltip background using SlantedBox
                SlantedBox {
                    id: tooltipBg
                    anchors.fill: parent
                    slantLeft: gpuBox.slantLeft
                    slantRight: gpuBox.slantRight
                    slantWidth: gpuBox.tooltipSlantWidth

                    // Local math handles staggering safely
                    readonly property real slantRatio: (height > 0) ? (slantWidth / height) : 0.35
                }

                // --- SLANTED TEXT CONTENT LAYOUT ---
                Item {
                    anchors.fill: parent

                        Text {
                        text: "ACTIVE GPU CLIENTS:"
                        font.family: tooltipBg.fontFamily
                        font.pixelSize: shell.theme.globalFontSize
                        font.bold: true
                        color: shell.theme.base05

                        y: 35
                        x: ((tooltipBg.height - y) * tooltipBg.slantRatio) + 24
                    }

                    // Slanted Divider Line (Staggers right-to-left)
                    Rectangle {
                        height: 2
                        color: shell.theme.base02
                        width: 310

                        y: 65
                        x: ((tooltipBg.height - y) * tooltipBg.slantRatio) + 24
                    }

                    Repeater {
                        model: gpuBox.processLinesArray.length

                        Text {
                            text: gpuBox.processLinesArray[index]
                            font.family: "monospace"
                            font.pixelSize: shell.theme.globalFontSize
                            color: shell.theme.base05

                            y: 95 + (index * 28)
                            x: ((tooltipBg.height - y) * tooltipBg.slantRatio) + 24
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            gpuStatsProc.running = false;
            gpuStatsProc.running = true;
            if (gpuHoverTracker.hovered || gpuBox.pinTooltip) { gpuBox.textAccumulatorBuffer = ""; gpuProcFetcher.running = true; }
        }
    }
}
