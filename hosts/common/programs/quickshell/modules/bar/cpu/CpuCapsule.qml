import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Import your custom style module relative to this widget's location
import "../../style"

Item {
    id: cpuBox

    property int tooltipWidth: 320
    property int tooltipHeight: 400

    width: 175
    height: parent.height

    // Use your reusable RightStyle component as the background
    RightStyle {
        id: bg
        anchors.fill: parent
    }

    property string cpuUsageStr: "0%"
    property string cpuTempStr: "0°C"
    property string topProcessesText: "Loading CPU processes..."
    property string textAccumulatorBuffer: ""
    property var barWindow: null

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

    Text {
        id: cpuText
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

    PanelWindow {
        id: fixedTooltipWindow
        screen: cpuBox.barWindow ? cpuBox.barWindow.screen : null
        visible: cpuHoverTracker.hovered

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

        // Tooltip container (Kept standard/rectangular for proper alignment)
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
                    text: "ACTIVE CPU CLIENTS"
                    font.family: shell.theme.fontFamily
                    font.pixelSize: shell.theme.globalFontSize
                    font.bold: true
                    color: shell.theme.base05
                }

                Rectangle { width: parent.width; height: 2; color: shell.theme.base02 }

                Flickable {
                    width: parent.width; height: cpuBox.tooltipHeight - 70
                    contentWidth: processDisplayLines.paintedWidth
                    contentHeight: processDisplayLines.paintedHeight
                    clip: true

                    Text {
                        id: processDisplayLines
                        textFormat: Text.RichText
                        text: "<pre style='margin: 0; font-family: monospace;'>" + cpuBox.topProcessesText + "</pre>"
                        font.pixelSize: shell.theme.globalFontSize
                        color: shell.theme.base05
                        lineHeight: 1.15
                        wrapMode: Text.NoWrap
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
            if (cpuHoverTracker.hovered) {
                cpuBox.textAccumulatorBuffer = "";
                topProcFetcher.running = false;
                topProcFetcher.running = true;
            }
        }
    }
}
