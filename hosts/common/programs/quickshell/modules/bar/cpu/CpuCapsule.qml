import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Theme

Rectangle {
    id: cpuBox

    // ============================================================================
    // ⚙️ CUSTOMIZABLE CONFIGURATION ZONE (EDIT THESE VALUES)
    // ============================================================================

    // TAG: Width of the tooltip window popup canvas box (in pixels)
    property int tooltipWidth: 320

    // TAG: Height of the tooltip window popup canvas box (in pixels)
    // FIXED: Expanded the default height scale boundary limits up to 400px
    property int tooltipHeight: 400

    // ============================================================================
    // 🧠 CORE ENGINE LAYERS (DO NOT TOUCH)
    // ============================================================================
    width: 175
    height: 35
    radius: 10
    border.width: 3

    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

    property string cpuUsageStr: "--%"
    property string cpuTempStr: "--°C"
    property string topProcessesText: "Loading CPU processes..."
    property string textAccumulatorBuffer: ""

    Process {
        id: cpuStatsProc
        running: true
        command: ["sh", "-c", "usage=$(awk '/cpu / {print int(($2+$4)*100/($2+$4+$5))}' /proc/stat); temp=$(sensors 2>/dev/null | awk '/Package id 0:/ {print $4}' | tr -d '+'); echo \"${usage:-0}%:${temp:-0°C}\""]
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
            onRead: data => {
                if (data && data.trim() !== "") {
                    cpuBox.textAccumulatorBuffer += data + "\n";
                }
            }
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
        anchors.margins: 5
        textFormat: Text.RichText
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: {
            const greenColor = (typeof Theme !== 'undefined' && Theme.base0C !== undefined) ? Theme.base0C.toString() : "green";
            const whiteColor = (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05.toString() : "white";

            return "<font color='" + greenColor + "'>CPU:</font> " +
            "<font color='" + whiteColor + "'>" + cpuBox.cpuUsageStr + " " + cpuBox.cpuTempStr + "</font>";
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
        screen: standardBarWindow.screen
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

            color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
            border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "📊 TOP PROCESSORS LOAD:"
                    font.family: "monospace"
                    font.pixelSize: 20
                    font.bold: true
                    color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"
                }

                Rectangle {
                    width: parent.width
                    height: 2
                    color: (typeof Theme !== 'undefined' && Theme.base03 !== undefined) ? Theme.base03 : "#333333"
                }

                Flickable {
                    width: parent.width
                    height: cpuBox.tooltipHeight - 70
                    contentWidth: processDisplayLines.paintedWidth
                    contentHeight: processDisplayLines.paintedHeight
                    clip: true

                    Text {
                        id: processDisplayLines
                        text: cpuBox.topProcessesText
                        font.family: "monospace"
                        // FIXED: Scaled up font tracking profile readouts to size 20
                        font.pixelSize: 20
                        color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "white"
                        lineHeight: 1.15
                        wrapMode: Text.NoWrap
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
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
