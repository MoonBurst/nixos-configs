import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

Item {
    id: ramBox
    property int tooltipHeight: 420
    property var barWindow: null

    // Slant config
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: shell.theme.slantWidth

    // Tooltip slant
    readonly property real tooltipSlantWidth: (ramBox.height > 0)
    ? (tooltipHeight * (slantWidth / ramBox.height))
    : 15

    // Standardized Tooltip Sizing
    property int tooltipWidth: 380 + (tooltipSlantWidth * 2)

    property real totalGiB: 0.0
    property real availableGiB: 0.0
    property string topProcessesText: "Loading system processes..."
    property string textAccumulatorBuffer: ""

    // Split the raw processes output into a clean array of lines
    readonly property var processLinesArray: topProcessesText.split("\n").filter(line => line.trim() !== "")

    // Toggle to pin the tooltip open for screenshots (Click the RAM capsule to toggle)
    property bool pinTooltip: false

    // Centralized SlantedBox Background
    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: ramBox.slantLeft
        slantRight: ramBox.slantRight
        slantWidth: ramBox.slantWidth
    }

    // Unified Layout Constraints
    Binding { target: ramBox; property: "Layout.preferredWidth"; value: 175 }
    Binding { target: ramBox; property: "width"; value: 175 }

    height: parent.height

    // Metric Data Collector
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

    // Client Process Scanner
    Process {
        id: topProcFetcher
        running: false
        command: ["sh", "-c", "total_mem=$(awk '/MemTotal/ {print $2/1024}' /proc/meminfo); ps -eo comm,%mem --sort=-%mem | awk -v total=\"$total_mem\" 'NR>1 { mem_mb = ($2 / 100) * total; if (mem_mb > 0) { if (mem_mb >= 1024) { size_str = sprintf(\"%.1fG\", mem_mb/1024) } else { size_str = sprintf(\"%dM\", mem_mb) }; printf \"%-15s %6s (%5s%%)\\n\", substr($1, 1, 15), size_str, $2; count++ } if (count >= 10) exit }'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim() !== "") ramBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: {
            ramBox.topProcessesText = ramBox.textAccumulatorBuffer.trim() !== "" ? ramBox.textAccumulatorBuffer.trim() : "No active engine clients";
        }
    }

    // Main Canvas Display Text
    Text {
        id: ramText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: shell.theme.globalPadding
        anchors.bottomMargin: shell.theme.globalPadding

        textFormat: Text.RichText
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        // Automatically scale text down to fit inside the boundaries
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        elide: Text.ElideRight

        text: {
            const greenColor = shell.theme.base0C.toString();
            var usedGiB = ramBox.totalGiB - ramBox.availableGiB;
            var usageRatio = (ramBox.totalGiB > 0) ? (usedGiB / ramBox.totalGiB) : 0.0;

            var normalYellow = shell.theme.base05.toString();
            var warnOrange = shell.theme.base09.toString();
            var critRed = shell.theme.base08.toString();

            var dataColor = normalYellow;
            if (usageRatio >= 0.85) dataColor = critRed;
            else if (usageRatio >= 0.50) dataColor = warnOrange;

            var valueStr = ramBox.availableGiB === 0.0 ? " -- GiB" : (" " + ramBox.availableGiB.toFixed(1) + " GiB");
            return "<font color='" + greenColor + "'>RAM:</font><font color='" + dataColor + "'>" + valueStr + "</font>";
        }
    }

    HoverHandler {
        id: ramHoverTracker
        onHoveredChanged: if (hovered) { ramBox.textAccumulatorBuffer = ""; topProcFetcher.running = true; }
    }

    // Click to toggle/pin the tooltip
    TapHandler {
        onTapped: {
            ramBox.textAccumulatorBuffer = "";
            topProcFetcher.running = true;
        //    ramBox.pinTooltip = !ramBox.pinTooltip;
        }
    }

    // Panel Window Pop-up Renderer
    Loader {
        active: ramHoverTracker.hovered || ramBox.pinTooltip

        sourceComponent: Component {
            PanelWindow {
                screen: ramBox.barWindow ? ramBox.barWindow.screen : null
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-ram-tooltip"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                anchors.top: true
                anchors.right: true

                WlrLayershell.margins.top: shell.theme.globalPadding + 55
                WlrLayershell.margins.right: ramBox.barWindow ? Math.max(10 + shell.theme.globalPadding, ramBox.barWindow.width - ramBox.mapToItem(null, 0, 0).x - (ramBox.width / 2) - (ramBox.tooltipWidth / 2)) : 10

                implicitWidth: ramBox.tooltipWidth
                implicitHeight: ramBox.tooltipHeight
                color: "transparent"

                // Tooltip background using SlantedBox
                SlantedBox {
                    id: tooltipBg
                    anchors.fill: parent
                    slantLeft: ramBox.slantLeft
                    slantRight: ramBox.slantRight
                    slantWidth: ramBox.tooltipSlantWidth
                }

                //  Text content layout
                Item {
                    anchors.fill: parent

                    // Header
                    Text {
                        text: "TOP RAM CONSUMERS:"
                        font.family: shell.theme.fontFamily
                        font.pixelSize: shell.theme.globalFontSize
                        font.bold: true
                        color: shell.theme.base05

                        y: 35
                        x: ((tooltipBg.height - y) * tooltipBg.slantRatio) + 24
                    }

                    // Slanted Divider Line
                    Rectangle {
                        height: 2
                        color: shell.theme.base02
                        width: 310

                        y: 65
                        x: ((tooltipBg.height - y) * tooltipBg.slantRatio) + 24
                    }

                    // Monospace Process List
                    Repeater {
                        model: ramBox.processLinesArray.length

                        Text {
                            text: ramBox.processLinesArray[index]
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
            ramStatsProc.running = true;
            if (ramHoverTracker.hovered || ramBox.pinTooltip) {
                ramBox.textAccumulatorBuffer = "";
                topProcFetcher.running = true;
            }
        }
    }
}
