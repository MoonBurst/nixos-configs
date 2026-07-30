// GpuCapsule.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

Item {
    id: gpuBox
    property var barWindow: null
    property bool pinTooltip: false
    property string searchQuery: ""

    // Theme Fallbacks
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property color themeBase00: (shell && shell.theme && typeof shell.theme.base00 !== "undefined") ? shell.theme.base00 : "black"
    readonly property color themeBase02: (shell && shell.theme && typeof shell.theme.base02 !== "undefined") ? shell.theme.base02 : "#222222"
    readonly property color themeBase05: (shell && shell.theme && typeof shell.theme.base05 !== "undefined") ? shell.theme.base05 : "yellow"
    readonly property color themeBase08: (shell && shell.theme && typeof shell.theme.base08 !== "undefined") ? shell.theme.base08 : "red"
    readonly property color themeBase09: (shell && shell.theme && typeof shell.theme.base09 !== "undefined") ? shell.theme.base09 : "orange"
    readonly property color themeBase0C: (shell && shell.theme && typeof shell.theme.base0C !== "undefined") ? shell.theme.base0C : "green"
    // =========================================================================

    // =========================================================================
    // EDITABLE TOOLTIP CONFIGURATION
    // =========================================================================
    property int tooltipHeight: 420          // Vertical height of the expanded box
    property int tooltipCollapsedWidth: 134  // Sleek, thin width during the downward unroll
    property int tooltipExpandedWidth: 440   // Final horizontal width once fully open
    property int tooltipTopOffset: -2        // Micro-adjust vertical spacing (px)
    property int tooltipRightOffset: 21      // Micro-adjust horizontal alignment (px)
    // =========================================================================

    // Module slant configurations
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: gpuBox.themeSlantWidth

    property string gpuUsageRaw: "0"
    property string gpuTempRaw: "0"
    property string gpuPowerRaw: "0"
    property string gpuVramFreeRaw: "0"
    property string topGpuProcessesText: "Loading GPU processes..."
    property string textAccumulatorBuffer: ""

    readonly property var processLinesArray: topGpuProcessesText.split("\n").filter(line => line.trim() !== "")

    // Live Filtered Process List
    readonly property var filteredProcessLinesArray: {
        var lines = processLinesArray;
        if (searchQuery.trim() === "") return lines;
        var q = searchQuery.trim().toLowerCase();
        return lines.filter(function(line) {
            return line.toLowerCase().indexOf(q) !== -1;
        });
    }

    width: 175
    Layout.preferredWidth: 175
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: gpuBox.slantLeft
        slantRight: gpuBox.slantRight
        slantWidth: gpuBox.slantWidth
    }

    // GPU Data Collector (AMD/Nvidia)
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

    // Process Scanner (Outputs: PID|FormattedString)
    Process {
        id: gpuProcFetcher
        running: false
        command: [
            "sh", "-c",
            "if command -v nvidia-smi >/dev/null 2>&1; then out=$(nvidia-smi --query-compute-apps=pid,name,utilization.gpu --format=csv,noheader,nounits 2>/dev/null); if [ ! -z \"$out\" ]; then echo \"$out\" | awk -F', ' '{printf \"%s|%-10s %4s%%\\n\", $1, substr($2,1,10), $3}'; exit; fi; fi; card_dir=$(ls -d /sys/class/drm/card*/device 2>/dev/null | head -n 1); total_load=$(cat \"$card_dir/gpu_busy_percent\" 2>/dev/null || echo 0); out=$(ps -eo pid,comm,rss --sort=-rss | awk -v total_gpu=\"$total_load\" 'NR>1 { mib=int($3/1024); if(mib>150 && $2!=\"sh\" && $2!=\"bash\" && $2!=\"systemd\") { pids[NR]=$1; proc[NR]=$2; mem[NR]=mib; sum+=mib } } END { if(sum==0) sum=1; for(i in proc) { share=(mem[i]/sum)*total_gpu; if(share>0.0 || mem[i]>500) printf \"%s|%-10s %4.1f%%\\n\", pids[i], substr(proc[i],1,10), share } }' | sort -rn -k2,2 | head -n 10); if [ ! -z \"$out\" ]; then echo \"$out\"; else echo 'No active engine clients'; fi"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim() !== "") gpuBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: {
            gpuBox.topGpuProcessesText = gpuBox.textAccumulatorBuffer.trim() !== "" ? gpuBox.textAccumulatorBuffer.trim() : "No active engine clients";
        }
    }

    // Process Killer Helper
    Process {
        id: killProc
        function killPid(pid) {
            if (!pid) return;
            command = ["kill", "-9", pid.toString()];
            running = true;
        }
    }

    // Delayed refresh after killing a process
    Timer {
        id: killRefreshTimer
        interval: 300
        repeat: false
        onTriggered: {
            gpuBox.textAccumulatorBuffer = "";
            gpuProcFetcher.running = true;
        }
    }

    // Main Canvas Display Text
    Text {
        id: gpuText
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
            const currentTemp = parseInt(gpuBox.gpuTempRaw) || 0;
            const currentFreeVram = parseInt(gpuBox.gpuVramFreeRaw) || 0;

            let tempColor = themeBase05.toString();
            if (currentTemp >= 80) tempColor = themeBase08.toString();
            else if (currentTemp >= 70) tempColor = themeBase09.toString();

            let vramColor = themeBase05.toString();
            if (currentFreeVram <= 4) vramColor = themeBase08.toString();
            else if (currentFreeVram <= 12) vramColor = themeBase09.toString();

            function formatStat(rawVal, targetLength, activeColor) {
                let padCount = targetLength - rawVal.length;
                let zerosStr = padCount > 0 ? "<font color='" + themeBase00.toString() + "'>" + "0".repeat(padCount) + "</font>" : "";
                return zerosStr + "<font color='" + activeColor + "'>" + rawVal + "</font>";
            }

            return "<font color='" + themeBase0C.toString() + "'>GPU:</font> " +
            formatStat(gpuBox.gpuUsageRaw, 2, themeBase05.toString()) + "<font color='" + themeBase05.toString() + "'>%</font> " +
                formatStat(gpuBox.gpuTempRaw, 2, tempColor) + "<font color='" + tempColor + "'>°C</font> " +
                    formatStat(gpuBox.gpuPowerRaw, 3, themeBase05.toString()) + "<font color='" + themeBase05.toString() + "'>W</font> " +
                        formatStat(gpuBox.gpuVramFreeRaw, 2, vramColor) + "<font color='" + vramColor + "'>GiB</font>";
        }
    }

    HoverHandler {
        id: gpuHoverTracker
        onHoveredChanged: {
            if (hovered && !gpuTooltip.isHovered && !searchInput.activeFocus) {
                gpuBox.textAccumulatorBuffer = "";
                gpuProcFetcher.running = true;
            }
        }
    }

    // Click capsule to pin/unpin tooltip open
    TapHandler {
        onTapped: {
            gpuBox.pinTooltip = !gpuBox.pinTooltip;
            if (gpuBox.pinTooltip && !searchInput.activeFocus) {
                gpuBox.textAccumulatorBuffer = "";
                gpuProcFetcher.running = true;
            }
        }
    }

    // Tooltip Window
    SlantedTooltip {
        id: gpuTooltip
        moduleItem: gpuBox
        barWindow: gpuBox.barWindow
        tooltipActive: gpuHoverTracker.hovered
        pin: gpuBox.pinTooltip

        // Request keyboard input from Wayland compositor when search is focused/active
        WlrLayershell.keyboardFocus: (gpuBox.pinTooltip || searchInput.activeFocus) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        readonly property bool isHovered: tooltipHoverTracker.hovered

        tooltipHeight: gpuBox.tooltipHeight
        collapsedCoreWidth: gpuBox.tooltipCollapsedWidth
        expandedCoreWidth: gpuBox.tooltipExpandedWidth
        topOffset: gpuBox.tooltipTopOffset
        rightOffset: gpuBox.tooltipRightOffset

        slantLeft: gpuBox.slantLeft
        slantRight: gpuBox.slantRight

        Item {
            anchors.fill: parent
            HoverHandler {
                id: tooltipHoverTracker
            }
        }

        Text {
            text: "ACTIVE GPU CLIENTS:"
            font.family: themeFontFamily
            font.pixelSize: themeFontSize - 1
            font.bold: true
            color: themeBase05
            y: 24
            x: gpuTooltip.slantX(y) + 20
        }

        // Full-width Slanted Search/Filter Field
        Item {
            id: searchContainer
            y: 50
            x: gpuTooltip.slantX(y) + 20
            width: 345
            height: 26

            SlantedBox {
                anchors.fill: parent
                slantLeft: gpuBox.slantLeft
                slantRight: gpuBox.slantRight
                slantWidth: 12
            }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: gpuBox.themeBase05
                font.family: "monospace"
                font.pixelSize: gpuBox.themeFontSize - 1
                clip: true
                selectByMouse: true
                focus: true
                activeFocusOnPress: true

                onTextChanged: gpuBox.searchQuery = text

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search/Filter processes..."
                    color: gpuBox.themeBase05
                    opacity: 0.4
                    font.family: "monospace"
                    font.pixelSize: gpuBox.themeFontSize - 1
                    visible: searchInput.text === "" && !searchInput.activeFocus
                }
            }
        }

        Rectangle {
            height: 2
            color: themeBase02
            width: 345
            y: 86
            x: gpuTooltip.slantX(y) + 20
        }

        Repeater {
            model: gpuBox.filteredProcessLinesArray.length
            delegate: Item {
                id: processRow
                readonly property string rawLine: gpuBox.filteredProcessLinesArray[index]
                readonly property var parts: rawLine.split("|")
                readonly property string pid: parts.length > 1 ? parts[0] : ""
                readonly property string displayText: parts.length > 1 ? parts[1] : rawLine

                y: 102 + (index * 28)
                x: gpuTooltip.slantX(y) + 20
                width: 345
                height: 22

                HoverHandler {
                    id: rowHoverTracker
                }

                // Slanted Hover Box around entire process row
                SlantedBox {
                    anchors.fill: parent
                    anchors.topMargin: -2
                    anchors.bottomMargin: -2
                    anchors.leftMargin: -4
                    anchors.rightMargin: -2
                    slantLeft: gpuBox.slantLeft
                    slantRight: gpuBox.slantRight
                    slantWidth: 12
                    visible: rowHoverTracker.hovered
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.right: killBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: processRow.displayText
                    font.family: "monospace"
                    font.pixelSize: gpuBox.themeFontSize - 1
                    color: gpuBox.themeBase05
                    elide: Text.ElideRight
                }

                // Slanted Kill Process Button
                Item {
                    id: killBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 50
                    height: 18
                    visible: processRow.pid !== ""

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: gpuBox.slantLeft
                        slantRight: gpuBox.slantRight
                        slantWidth: 12
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: killBtnHover.hovered ? gpuBox.themeBase08 : gpuBox.themeBase08
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler {
                        id: killBtnHover
                    }

                    TapHandler {
                        onTapped: {
                            if (processRow.pid !== "") {
                                killProc.killPid(processRow.pid);
                                killRefreshTimer.start();
                            }
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
            if ((gpuHoverTracker.hovered || gpuBox.pinTooltip) && !gpuTooltip.isHovered && !searchInput.activeFocus) {
                gpuBox.textAccumulatorBuffer = "";
                gpuProcFetcher.running = true;
            }
        }
    }
}
