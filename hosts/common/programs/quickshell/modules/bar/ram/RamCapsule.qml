import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Import your custom style module relative to this widget's location
import "../../style"

Item {
    id: ramBox

    property int tooltipWidth: 415
    property int tooltipHeight: 400
    property var barWindow: null

    property real totalGiB: 0.0
    property real availableGiB: 0.0
    property string topProcessesText: "Loading system processes..."
    property string textAccumulatorBuffer: ""

    // Use your reusable RightStyle component as the background
    RightStyle {
        id: bg
        anchors.fill: parent
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

        // Dynamically clear the slant margins using RightStyle's properties
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

    // Dynamic Panel Renderer (Kept standard/rectangular for proper alignment)
    Loader {
        active: ramHoverTracker.hovered
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

                Rectangle {
                    anchors.fill: parent
                    radius: shell.theme.defaultCardRadius
                    border.width: shell.theme.globalBorderWidth
                    color: shell.theme.base00
                    border.color: shell.theme.base05

                    Column {
                        anchors.fill: parent
                        anchors.margins: shell.theme.globalPadding
                        spacing: 10

                        Text {
                            text: "TOP RAM CONSUMERS:"
                            font.family: shell.theme.fontFamily
                            font.pixelSize: shell.theme.globalFontSize
                            font.bold: true
                            color: shell.theme.base05
                        }

                        Rectangle { width: parent.width; height: 2; color: shell.theme.base02 }

                        Flickable {
                            width: parent.width; height: ramBox.tooltipHeight - 70
                            contentWidth: processDisplayLines.paintedWidth
                            contentHeight: parent.height
                            clip: true

                            Text {
                                id: processDisplayLines
                                textFormat: Text.RichText
                                text: "<pre style='margin: 0; font-family: monospace;'>" + ramBox.topProcessesText + "</pre>"
                                font.pixelSize: shell.theme.globalFontSize
                                color: shell.theme.base05
                                lineHeight: 1.15
                                wrapMode: Text.NoWrap
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
            ramStatsProc.running = true;
            if (ramHoverTracker.hovered) { ramBox.textAccumulatorBuffer = ""; topProcFetcher.running = true; }
        }
    }
}
