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
    property int tooltipHeight: 420          // Vertical height of the expanded box
    property int tooltipCollapsedWidth: 134  // Sleek, thin width during the downward unroll
    property int tooltipExpandedWidth: 440   // Final horizontal width once fully open
    property int tooltipTopOffset: -2        // Micro-adjust vertical spacing (px)
    property int tooltipRightOffset: 21      // Micro-adjust horizontal alignment (px)
    // =========================================================================

    // Slant configurations
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: ramBox.themeSlantWidth

    property real totalGiB: 0.0
    property real availableGiB: 0.0
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

    width: 175
    Layout.preferredWidth: 175
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: ramBox.slantLeft
        slantRight: ramBox.slantRight
        slantWidth: ramBox.slantWidth
    }

    // Data Collector
    Process {
        id: ramStatsProc
        running: true
        command: ["sh", "-c", "awk '/MemTotal/ {total=$2} /MemAvailable/ {avail=$2} END {print total \":\" avail}' /proc/meminfo"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length === 2) {
                    var totalKb = parseInt(parts[0]);
                    var availKb = parseInt(parts[1]);
                    if (!isNaN(totalKb) && !isNaN(availKb) && totalKb > 0) {
                        ramBox.totalGiB = totalKb / (1024 * 1024);
                        ramBox.availableGiB = availKb / (1024 * 1024);
                    }
                }
            }
        }
    }

    // Process Scanner (Outputs: PID|FormattedString)
    Process {
        id: topProcFetcher
        running: false
        command: ["sh", "-c", "total_mem=$(awk '/MemTotal/ {print $2/1024}' /proc/meminfo); ps -eo pid,comm,%mem --sort=-%mem | awk -v total=\"$total_mem\" 'NR>1 { mem_mb = ($3 / 100) * total; if (mem_mb > 0) { if (mem_mb >= 1024) { size_str = sprintf(\"%.1fG\", mem_mb/1024) } else { size_str = sprintf(\"%dM\", mem_mb) }; printf \"%s|%-10s %5s %4.1f%%\\n\", $1, substr($2, 1, 10), size_str, $3; count++ } if (count >= 10) exit }'"]
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
            var usedGiB = ramBox.totalGiB - ramBox.availableGiB;
            var usageRatio = (ramBox.totalGiB > 0) ? (usedGiB / ramBox.totalGiB) : 0.0;

            var normalYellow = themeBase05.toString();
            var warnOrange = themeBase09.toString();
            var critRed = themeBase08.toString();

            var dataColor = normalYellow;
            if (usageRatio >= 0.85) dataColor = critRed;
            else if (usageRatio >= 0.50) dataColor = warnOrange;

            var valueStr = ramBox.availableGiB === 0.0 ? " -- GiB" : (" " + ramBox.availableGiB.toFixed(1) + " GiB");
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

        Text {
            text: "TOP RAM CONSUMERS:"
            font.family: themeFontFamily
            font.pixelSize: themeFontSize - 1
            font.bold: true
            color: themeBase05
            y: 24
            x: ramTooltip.slantX(y) + 20
        }

        // Full-width Slanted Search/Filter Field
        Item {
            id: searchContainer
            y: 50
            x: ramTooltip.slantX(y) + 20
            width: 345
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
            y: 86
            x: ramTooltip.slantX(y) + 20
        }

        Repeater {
            model: ramBox.filteredProcessLinesArray.length
            delegate: Item {
                id: processRow
                readonly property string rawLine: ramBox.filteredProcessLinesArray[index]
                readonly property var parts: rawLine.split("|")
                readonly property string pid: parts.length > 1 ? parts[0] : ""
                readonly property string displayText: parts.length > 1 ? parts[1] : rawLine

                y: 102 + (index * 28)
                x: ramTooltip.slantX(y) + 20
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
                    color: ramBox.themeBase05
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
