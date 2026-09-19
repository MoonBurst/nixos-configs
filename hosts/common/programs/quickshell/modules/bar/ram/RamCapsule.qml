// RamCapsule.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

Item {
    id: ramBox
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
    property int tooltipHeight: 450          // Vertical height of the expanded box
    property int tooltipCollapsedWidth: 134  // Sleek, thin width during the downward unroll
    property int tooltipExpandedWidth: 500   // Final horizontal width once fully open
    property int tooltipTopOffset: -2        // Micro-adjust vertical spacing (px)
    property int tooltipRightOffset: 21      // Micro-adjust horizontal alignment (px)
    // =========================================================================

    // Slant configurations
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: ramBox.themeSlantWidth

    // Memory Stats
    property real totalGiB: 0.0          // Physical Total
    property real availableGiB: 0.0      // Physical Available
    property real effectiveAvailGiB: 0.0 // True Reserve (Physical + ZRAM Free + SSD Swap Free)
    property real effectiveTotalGiB: 0.0 // True Total Capacity
    property real zramRatio: 1.0         // Compression Ratio (e.g. 2.1x)
    property real zramSavedGiB: 0.0      // Physical RAM saved by compression

    property string topProcessesText: "Loading system processes..."
    property string textAccumulatorBuffer: ""

    readonly property var processLinesArray: topProcessesText.split("\n").filter(line => line.trim() !== "")

    // Live Filtered Process List
    readonly property var filteredProcessLinesArray: {
        var lines = processLinesArray;
        if (searchQuery.trim() === "") return lines;
        var q = searchQuery.trim().toLowerCase();
        return lines.filter(function(line) {
            return line.toLowerCase().indexOf(q) !== -1;
        });
    }

    width: 185
    Layout.preferredWidth: 185
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: ramBox.slantLeft
        slantRight: ramBox.slantRight
        slantWidth: ramBox.slantWidth
    }

    // Compression-Aware Memory Data Collector
    Process {
        id: ramStatsProc
        running: true
        command: [
            "sh", "-c",
            "eval $(awk '/MemTotal:/ {print \"mt=\"$2} /MemAvailable:/ {print \"ma=\"$2} /SwapTotal:/ {print \"st=\"$2} /SwapFree:/ {print \"sf=\"$2}' /proc/meminfo); orig=0; compr=0; if [ -f /sys/block/zram0/mm_stat ]; then read orig compr _ < /sys/block/zram0/mm_stat; fi; printf \"%s:%s:%s:%s:%s:%s\\n\" \"$mt\" \"$ma\" \"$st\" \"$sf\" \"$orig\" \"$compr\""
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length === 6) {
                    var mt = parseInt(parts[0]);   // MemTotal KB
                    var ma = parseInt(parts[1]);   // MemAvailable KB
                    var st = parseInt(parts[2]);   // SwapTotal KB
                    var sf = parseInt(parts[3]);   // SwapFree KB
                    var orig = parseInt(parts[4]); // ZRAM Uncompressed Bytes
                    var compr = parseInt(parts[5]);// ZRAM Compressed Bytes

                    if (!isNaN(mt) && !isNaN(ma)) {
                        ramBox.totalGiB = mt / (1024 * 1024);
                        ramBox.availableGiB = ma / (1024 * 1024);

                        var swapFreeKb = isNaN(sf) ? 0 : sf;
                        var swapTotalKb = isNaN(st) ? 0 : st;

                        ramBox.effectiveAvailGiB = (ma + swapFreeKb) / (1024 * 1024);
                        ramBox.effectiveTotalGiB = (mt + swapTotalKb) / (1024 * 1024);

                        if (!isNaN(orig) && !isNaN(compr) && compr > 0) {
                            ramBox.zramRatio = orig / compr;
                            ramBox.zramSavedGiB = (orig - compr) / (1024 * 1024 * 1024);
                        } else {
                            ramBox.zramRatio = 1.0;
                            ramBox.zramSavedGiB = 0.0;
                        }
                    }
                }
            }
        }
    }

    // Process Scanner with Real-Time VmSwap Inspection (PID|IS_RAW_RAM|FormattedString)
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
            ramBox.textAccumulatorBuffer = "";
            topProcFetcher.running = true;
        }
    }

    Text {
        id: ramText
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

        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        elide: Text.ElideRight

        text: {
            const greenColor = themeBase0C.toString();

            // Uses Effective Available (Physical + ZRAM + SSD Swap)
            var displayAvail = ramBox.effectiveAvailGiB;
            var displayTotal = ramBox.effectiveTotalGiB;
            var usedGiB = displayTotal - displayAvail;
            var usageRatio = (displayTotal > 0) ? (usedGiB / displayTotal) : 0.0;

            var normalYellow = themeBase05.toString();
            var warnOrange = themeBase09.toString();
            var critRed = themeBase08.toString();

            var dataColor = normalYellow;
            if (usageRatio >= 0.85) dataColor = critRed;
            else if (usageRatio >= 0.50) dataColor = warnOrange;

            var valueStr = displayAvail === 0.0 ? " -- GiB" : (" " + displayAvail.toFixed(1) + " GiB");
            return "<font color='" + greenColor + "'>RAM:</font><font color='" + dataColor + "'>" + valueStr + "</font>";
        }
    }

    HoverHandler {
        id: ramHoverTracker
        onHoveredChanged: {
            if (hovered && !ramTooltip.isHovered && !searchInput.activeFocus) {
                ramBox.textAccumulatorBuffer = "";
                topProcFetcher.running = true;
            }
        }
    }

    // Click capsule to pin/unpin tooltip open
    TapHandler {
        onTapped: {
            ramBox.pinTooltip = !ramBox.pinTooltip;
            if (ramBox.pinTooltip && !searchInput.activeFocus) {
                ramBox.textAccumulatorBuffer = "";
                topProcFetcher.running = true;
            }
        }
    }

    // Tooltip Window
    SlantedTooltip {
        id: ramTooltip
        moduleItem: ramBox
        barWindow: ramBox.barWindow
        tooltipActive: ramHoverTracker.hovered
        pin: ramBox.pinTooltip

        // Request keyboard input from Wayland compositor when search is focused/active
        WlrLayershell.keyboardFocus: (ramBox.pinTooltip || searchInput.activeFocus) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        readonly property bool isHovered: tooltipHoverTracker.hovered

        tooltipHeight: ramBox.tooltipHeight
        collapsedCoreWidth: ramBox.tooltipCollapsedWidth
        expandedCoreWidth: ramBox.tooltipExpandedWidth
        topOffset: ramBox.tooltipTopOffset
        rightOffset: ramBox.tooltipRightOffset

        slantLeft: ramBox.slantLeft
        slantRight: ramBox.slantRight

        Item {
            anchors.fill: parent
            HoverHandler {
                id: tooltipHoverTracker
            }
        }

        // Header Title
        Text {
            text: "TOP RAM CONSUMERS:"
            font.family: themeFontFamily
            font.pixelSize: themeFontSize - 1
            font.bold: true
            color: themeBase05
            y: 18
            x: ramTooltip.slantX(y) + 20
        }

        // Compression / ZRAM Stats Row
        RowLayout {
            y: 38
            x: ramTooltip.slantX(y) + 20
            spacing: 10

            Text {
                text: "ZRAM: " + ramBox.zramRatio.toFixed(2) + "x"
                font.family: themeFontFamily
                font.pixelSize: themeFontSize - 2
                font.bold: true
                color: themeBase0C
            }
            Text {
                text: "SAVED: " + ramBox.zramSavedGiB.toFixed(1) + "G"
                font.family: themeFontFamily
                font.pixelSize: themeFontSize - 2
                color: themeBase09
            }
            Text {
                text: "PHYS: " + ramBox.availableGiB.toFixed(1) + "/" + ramBox.totalGiB.toFixed(0) + "G"
                font.family: themeFontFamily
                font.pixelSize: themeFontSize - 2
                color: themeBase05
                opacity: 0.7
            }
        }

        // Color Legend Row (Physical RAM vs Compressed/Swappable)
        RowLayout {
            y: 56
            x: ramTooltip.slantX(y) + 20
            spacing: 12

            Text {
                text: "⚡ 100% Physical RAM"
                font.family: themeFontFamily
                font.pixelSize: themeFontSize - 3
                font.bold: true
                color: themeBase0C
            }
            Text {
                text: "■ Compressed/Swappable"
                font.family: themeFontFamily
                font.pixelSize: themeFontSize - 3
                color: themeBase05
                opacity: 0.8
            }
        }

        // Full-width Slanted Search/Filter Field
        Item {
            id: searchContainer
            y: 78
            x: ramTooltip.slantX(y) + 20
            width: 400
            height: 26

            SlantedBox {
                anchors.fill: parent
                slantLeft: ramBox.slantLeft
                slantRight: ramBox.slantRight
                slantWidth: 12
            }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: ramBox.themeBase05
                font.family: "monospace"
                font.pixelSize: ramBox.themeFontSize - 1
                clip: true
                selectByMouse: true
                focus: true
                activeFocusOnPress: true

                onTextChanged: ramBox.searchQuery = text

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search/Filter processes..."
                    color: ramBox.themeBase05
                    opacity: 0.4
                    font.family: "monospace"
                    font.pixelSize: ramBox.themeFontSize - 1
                    visible: searchInput.text === "" && !searchInput.activeFocus
                }
            }
        }

        Rectangle {
            height: 2
            color: themeBase02
            width: 345
            y: 112
            x: ramTooltip.slantX(y) + 20
        }

        Repeater {
            model: ramBox.filteredProcessLinesArray.length
            delegate: Item {
                id: processRow
                readonly property string rawLine: ramBox.filteredProcessLinesArray[index]
                readonly property var parts: rawLine.split("|")
                readonly property string pid: parts.length > 2 ? parts[0] : ""
                readonly property bool isRawRam: parts.length > 2 ? (parts[1] === "1") : false
                readonly property string displayText: parts.length > 2 ? (parts[1] === "1" ? "⚡ " + parts[2] : parts[2]) : rawLine

                y: 124 + (index * 28)
                x: ramTooltip.slantX(y) + 20
                width: 400
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
                    slantLeft: ramBox.slantLeft
                    slantRight: ramBox.slantRight
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
                    font.pixelSize: ramBox.themeFontSize - 1

                    // BRIGHT CYAN/GREEN for 100% Physical RAM, YELLOW for Swappable/Compressed
                    color: processRow.isRawRam ? ramBox.themeBase0C : ramBox.themeBase05
                    font.bold: processRow.isRawRam
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
                        slantLeft: ramBox.slantLeft
                        slantRight: ramBox.slantRight
                        slantWidth: 12
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: killBtnHover.hovered ? ramBox.themeBase08 : ramBox.themeBase08
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
        id: statsRefreshTimer
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            ramStatsProc.running = true;
            if ((ramHoverTracker.hovered || ramBox.pinTooltip) && !ramTooltip.isHovered && !searchInput.activeFocus) {
                ramBox.textAccumulatorBuffer = "";
                topProcFetcher.running = true;
            }
        }
    }
}
