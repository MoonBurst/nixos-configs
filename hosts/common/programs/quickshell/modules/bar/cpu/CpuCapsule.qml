// CpuCapsule.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

Item {
    id: cpuBox
    property var barWindow: null
    property bool pinTooltip: false

    // =========================================================================
    //  EDITABLE TOOLTIP CONFIGURATION
    // =========================================================================
    property int tooltipHeight: 400          // Vertical height of the expanded box
    property int tooltipCollapsedWidth: 130  // Sleek, thin width during the downward unroll
    property int tooltipExpandedWidth: 325   // Final horizontal width once fully open
    property int tooltipTopOffset: 0         // Micro-adjust vertical spacing (px)
    property int tooltipRightOffset: 18      // Micro-adjust horizontal alignment (px)
    // =========================================================================

    // Module slant configurations
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: shell.theme.slantWidth

    property string cpuUsageStr: "0%"
    property string cpuTempStr: "0°C"
    property string topProcessesText: "Loading CPU processes..."
    property string textAccumulatorBuffer: ""
    readonly property var processLinesArray: topProcessesText.split("\n").filter(line => line.trim() !== "")


    width: 175
    Layout.preferredWidth: 175
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: cpuBox.slantLeft
        slantRight: cpuBox.slantRight
        slantWidth: cpuBox.slantWidth
    }

    // Metric Data Collector
    Process {
        id: cpuStatsProc
        running: true
        command: ["sh", "-c", "usage=$(awk '/cpu / {print int(($2+$4)*100/($2+$4+$5))}' /proc/stat); temp=$(cat /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null | head -n 1 || echo '0'); if [ \"$temp\" -gt 0 ]; then temp=$(echo \"scale=0; $temp/1000\" | bc); fi; echo \"$usage%:${temp}°C\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length === 2) {
                    cpuBox.cpuUsageStr = parts[0];
                    cpuBox.cpuTempStr = parts[1];
                }
            }
        }
    }

    // Client Process Scanner
    Process {
        id: topProcFetcher
        running: false
        command: ["sh", "-c", "ps -eo comm,%cpu --sort=-%cpu | head -n 11 | awk 'NR>1 {printf \"%-15s %6s%%\\n\", substr($1,1,15), $2}'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim() !== "") cpuBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: {
            if (cpuBox.textAccumulatorBuffer.trim() !== "") {
                cpuBox.topProcessesText = cpuBox.textAccumulatorBuffer.trim();
            }
        }
    }

    // Main Canvas Display Text
    Text {
        id: cpuText
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
            const yellowColor = shell.theme.base05.toString();
            return "<font color='" + greenColor + "'>CPU:</font> " +
            "<font color='" + yellowColor + "'>" + cpuBox.cpuUsageStr + " " + cpuBox.cpuTempStr + "</font>";
        }
    }

    HoverHandler {
        id: cpuHoverTracker
        onHoveredChanged: {
            if (hovered) {
                cpuBox.textAccumulatorBuffer = "";
                topProcFetcher.running = false;
                topProcFetcher.running = true;
            }
        }
    }

    TapHandler {
        onTapped: {
            cpuBox.textAccumulatorBuffer = "";
            topProcFetcher.running = false;
            topProcFetcher.running = true;
        }
    }

    // Panel Window Pop-up Renderer
    Loader {
        id: tooltipLoader
        active: cpuHoverTracker.hovered || cpuBox.pinTooltip || (tooltipLoader.item && tooltipLoader.item.animHeight > 0)

        sourceComponent: Component {
            SlantedTooltip {
                id: cpuTooltip
                moduleItem: cpuBox
                barWindow: cpuBox.barWindow
                tooltipActive: cpuHoverTracker.hovered
                pin: cpuBox.pinTooltip

                // Maps variables defined at the top of the file
                tooltipHeight: cpuBox.tooltipHeight
                collapsedCoreWidth: cpuBox.tooltipCollapsedWidth
                expandedCoreWidth: cpuBox.tooltipExpandedWidth
                topOffset: cpuBox.tooltipTopOffset
                rightOffset: cpuBox.tooltipRightOffset

                // pass capsule slants to keep the window parallel
                slantLeft: cpuBox.slantLeft
                slantRight: cpuBox.slantRight

                // Slanted Text Content Layout inside the tooltip children scope
                Text {
                    text: "ACTIVE CPU CLIENTS:"
                    font.family: shell.theme.fontFamily
                    font.pixelSize: shell.theme.globalFontSize - 1
                    font.bold: true
                    color: shell.theme.base05
                    y: 35
                    x: cpuTooltip.slantX(y) + 24
                }

                // Slanted Divider Line (Staggers right-to-left)
                Rectangle {
                    height: 2
                    color: shell.theme.base02
                    width: 360
                    y: 65
                    x: cpuTooltip.slantX(y) + 24
                }

                Repeater {
                    model: cpuBox.processLinesArray.length
                    Text {
                        text: cpuBox.processLinesArray[index]
                        font.family: "monospace"
                        font.pixelSize: shell.theme.globalFontSize - 1
                        color: shell.theme.base05
                        y: 95 + (index * 28)
                        x: cpuTooltip.slantX(y) + 24
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            cpuStatsProc.running = false;
            cpuStatsProc.running = true;
            if (cpuHoverTracker.hovered || cpuBox.pinTooltip) {
                cpuBox.textAccumulatorBuffer = "";
                topProcFetcher.running = false;
                topProcFetcher.running = true;
            }
        }
    }
}
