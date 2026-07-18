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

    // =========================================================================
    //  EDITABLE TOOLTIP CONFIGURATION
    // =========================================================================
    property int tooltipHeight: 400          // Vertical height of the expanded box
    property int tooltipCollapsedWidth: 136  // Sleek, thin width during the downward unroll
    property int tooltipExpandedWidth: 437  // Final horizontal width once fully open
    property int tooltipTopOffset: 0         // Micro-adjust vertical spacing (px)
    property int tooltipRightOffset: 21      // Micro-adjust horizontal alignment (px)
    // =========================================================================

    // slant config
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: shell.theme.slantWidth

    property real totalGiB: 0.0
    property real availableGiB: 0.0
    property string topProcessesText: "Loading system processes..."
    property string textAccumulatorBuffer: ""

    readonly property var processLinesArray: topProcessesText.split("\n").filter(line => line.trim() !== "")

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

    // Process Scanner
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

    TapHandler {
        onTapped: {
            ramBox.textAccumulatorBuffer = "";
            topProcFetcher.running = true;
        }
    }

    Loader {
        id: tooltipLoader
        active: ramHoverTracker.hovered || ramBox.pinTooltip || (tooltipLoader.item && tooltipLoader.item.animHeight > 0)

        sourceComponent: Component {
            SlantedTooltip {
                id: ramTooltip
                moduleItem: ramBox
                barWindow: ramBox.barWindow
                tooltipActive: ramHoverTracker.hovered
                pin: ramBox.pinTooltip

                // Maps variables defined at the top of the file
                tooltipHeight: ramBox.tooltipHeight
                collapsedCoreWidth: ramBox.tooltipCollapsedWidth
                expandedCoreWidth: ramBox.tooltipExpandedWidth
                topOffset: ramBox.tooltipTopOffset
                rightOffset: ramBox.tooltipRightOffset

                slantLeft: ramBox.slantLeft
                slantRight: ramBox.slantRight

                Text {
                    text: "TOP RAM CONSUMERS:"
                    font.family: shell.theme.fontFamily
                    font.pixelSize: shell.theme.globalFontSize - 1
                    font.bold: true
                    color: shell.theme.base05
                    y: 35
                    x: ramTooltip.slantX(y) + 24
                }

                Rectangle {
                    height: 2
                    color: shell.theme.base02
                    width: 360
                    y: 65
                    x: ramTooltip.slantX(y) + 24
                }

                Repeater {
                    model: ramBox.processLinesArray.length
                    Text {
                        text: ramBox.processLinesArray[index]
                        font.family: "monospace"
                        font.pixelSize: shell.theme.globalFontSize - 1
                        color: shell.theme.base05
                        y: 95 + (index * 28)
                        x: ramTooltip.slantX(y) + 24
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
            if (ramHoverTracker.hovered || ramBox.pinTooltip) {
                ramBox.textAccumulatorBuffer = "";
                topProcFetcher.running = true;
            }
        }
    }
}
