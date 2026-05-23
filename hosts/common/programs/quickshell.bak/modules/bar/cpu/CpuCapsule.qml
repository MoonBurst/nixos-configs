import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Rectangle {
    id: cpuBox

    property int tooltipWidth: 320
    property int tooltipHeight: 400

    width: 175
    height: 35
    radius: 10
    border.width: 3

    color: "black"
    border.color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"

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
        command: ["sh", "-c", "ps -eo comm,%cpu --sort=-%cpu | head -n 11 | awk 'NR>1 {printf \"%-13s %6s%%\\n\", substr($1,1,13), $2}'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim() !== "") cpuBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: { if (cpuBox.textAccumulatorBuffer.trim() !== "") cpuBox.topProcessesText = cpuBox.textAccumulatorBuffer.trim(); }
    }

    Text {
        id: cpuText
        anchors.fill: parent
        anchors.margins: 5
        textFormat: Text.RichText
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: {
            const greenColor = (root && root.theme && root.theme.base0C !== undefined) ? root.theme.base0C.toString() : "#04f100";
            const yellowColor = (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow";
            return "<font color='" + greenColor + "'>CPU:</font> " +
                   "<font color='" + yellowColor + "'>" + cpuBox.cpuUsageStr + " " + cpuBox.cpuTempStr + "</font>";
        }
    }

    HoverHandler {
        id: cpuHoverTracker
        onHoveredChanged: { if (hovered) { cpuBox.textAccumulatorBuffer = ""; topProcFetcher.running = false; topProcFetcher.running = true; } }
    }

    PanelWindow {
        id: fixedTooltipWindow
        screen: cpuBox.barWindow ? cpuBox.barWindow.screen : null
        visible: cpuHoverTracker.hovered 

        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.namespace: "quickshell-cpu-tooltip"
        WlrLayershell.keyboardFocus: WlrLayershell.None

        anchors.top: true
        anchors.right: true
        WlrLayershell.margins.top: 55
        WlrLayershell.margins.right: Math.max(10, standardBarWindow.width - cpuBox.mapToItem(null, 0, 0).x - (cpuBox.width / 2) - (cpuBox.tooltipWidth / 2))

        implicitWidth: cpuBox.tooltipWidth
        implicitHeight: cpuBox.tooltipHeight
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 8
            border.width: 3
            color: "black"
            border.color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // FIXED: Stripped out the duplicate font assignment properties from the Column node definition tree
                Text {
                    text: "📊 TOP PROCESSORS LOAD:"
                    font.family: "monospace"
                    font.pixelSize: 20
                    font.bold: true
                    color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"
                }

                Rectangle { width: parent.width; height: 2; color: "#333333" }

                Flickable {
                    width: parent.width; height: cpuBox.tooltipHeight - 70
                    contentWidth: processDisplayLines.paintedWidth
                    contentHeight: processDisplayLines.paintedHeight
                    clip: true

                    Text {
                        id: processDisplayLines
                        text: cpuBox.topProcessesText
                        font.family: "monospace"
                        font.pixelSize: 20
                        color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"
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
            if (cpuHoverTracker.hovered) { cpuBox.textAccumulatorBuffer = ""; topProcFetcher.running = false; topProcFetcher.running = true; }
        }
    }
}
