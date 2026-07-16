import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

Item {
    id: cpuBox

    // Standardized Tooltip Sizing
    property int tooltipHeight: 420
    property var barWindow: null

    // Slant config

    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: shell.theme.slantWidth

    // Tooltip slant
    readonly property real tooltipSlantWidth: (cpuBox.height > 0)
    ? (tooltipHeight * (slantWidth / cpuBox.height))
    : 15

    // Standardized Tooltip Sizing
    property int tooltipWidth: 380 + (tooltipSlantWidth * 2)

    property string cpuUsageStr: "0%"
    property string cpuTempStr: "0°C"
    property string topProcessesText: "Loading CPU processes..."
    property string textAccumulatorBuffer: ""
    readonly property var processLinesArray: topProcessesText.split("\n").filter(line => line.trim() !== "")

    // Toggle to pin the tooltip open for screenshots (Click the CPU capsule to toggle)
    property bool pinTooltip: false

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: cpuBox.slantLeft
        slantRight: cpuBox.slantRight
        slantWidth: cpuBox.slantWidth
    }

    width: 175
    height: parent.height

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

        // Automatically scale text down to fit inside the boundaries
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

    // Click to toggle/pin the tooltip
    TapHandler {
        onTapped: {
            cpuBox.textAccumulatorBuffer = "";
            topProcFetcher.running = false;
            topProcFetcher.running = true;
       //     cpuBox.pinTooltip = !cpuBox.pinTooltip;
        }
    }

    // Dynamic Panel Renderer
    Loader {
        active: cpuHoverTracker.hovered || cpuBox.pinTooltip

        sourceComponent: Component {
            PanelWindow {
                screen: cpuBox.barWindow ? cpuBox.barWindow.screen : null
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-cpu-tooltip"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                anchors.top: true
                anchors.right: true

                WlrLayershell.margins.top: shell.theme.globalPadding + 55
                WlrLayershell.margins.right: cpuBox.barWindow ? Math.max(10 + shell.theme.globalPadding, cpuBox.barWindow.width - cpuBox.mapToItem(null, 0, 0).x - (cpuBox.width / 2) - (cpuBox.tooltipWidth / 2)) : 10

                implicitWidth: cpuBox.tooltipWidth
                implicitHeight: cpuBox.tooltipHeight
                color: "transparent"

                // Tooltip background using SlantedBox
                SlantedBox {
                    id: tooltipBg
                    anchors.fill: parent
                    slantLeft: cpuBox.slantLeft
                    slantRight: cpuBox.slantRight
                    slantWidth: cpuBox.tooltipSlantWidth

                    readonly property real slantRatio: (height > 0) ? (slantWidth / height) : 0.35
                }

                Item {
                    anchors.fill: parent

                    // Header (Staggers right-to-left based on reversed y math)
                    Text {
                        text: "ACTIVE CPU CLIENTS:"
                        font.family: shell.theme.fontFamily
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
                        model: cpuBox.processLinesArray.length

                        Text {
                            text: cpuBox.processLinesArray[index]
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
