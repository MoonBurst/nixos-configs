import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Theme

Rectangle {
    id: ramBox

    // ============================================================================
    // ⚙️ CUSTOMIZABLE CONFIGURATION ZONE (EDIT THESE RATIO PROFILES)
    // ============================================================================
    property real ramWarnRatio: 0.20
    property real ramCritRatio: 0.10

    // ============================================================================
    // 🧠 CORE ENGINE LAYERS (DO NOT TOUCH)
    // ============================================================================
    width: 175
    height: 35
    radius: 10
    border.width: 3

    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

    property real totalGiB: 0.0
    property real availableGiB: 0.0
    property string topProcessesText: "Loading system processes..."

    // Accumulator string buffer to store multi-line terminal outputs safely
    property string textAccumulatorBuffer: ""

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

    Process {
        id: topProcFetcher
        running: false
        command: ["sh", "-c", "total_mem=$(awk '/MemTotal/ {print $2/1024}' /proc/meminfo); ps -eo comm,%mem --sort=-%mem | head -n 11 | awk -v total=\"$total_mem\" 'NR>1 { mem_mb = ($2 / 100) * total; if (mem_mb >= 1024) { size_str = sprintf(\"%.1fG\", mem_mb/1024) } else { size_str = sprintf(\"%dM\", mem_mb) }; printf \"%-15s %6s (%s%%)\\n\", substr($1, 1, 15), size_str, $2 }'"]

        // FIXED: Using standard SplitParser with an explicit multi-line append handler string loop
        stdout: SplitParser {
            onRead: data => {
                ramBox.textAccumulatorBuffer += data + "\n";
            }
        }

        // Triggers as soon as the bash script terminates completely to copy the full list on screen
        onExited: {
            if (ramBox.textAccumulatorBuffer.trim() !== "") {
                ramBox.topProcessesText = ramBox.textAccumulatorBuffer.trim();
            }
        }
    }

    Text {
        id: ramText
        anchors.fill: parent
        anchors.margins: 5
        textFormat: Text.RichText
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: {
            const greenColor    = (typeof Theme !== 'undefined' && Theme.base0C !== undefined) ? Theme.base0C.toString() : "green";
            const normalColor   = (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05.toString() : "yellow";
            const warningColor  = (typeof Theme !== 'undefined' && Theme.base0A !== undefined) ? Theme.base0A.toString() : "orange";
            const criticalColor = (typeof Theme !== 'undefined' && Theme.base08 !== undefined) ? Theme.base08.toString() : "red";

            var ram_color = (ramBox.availableGiB < (ramBox.totalGiB * ramBox.ramCritRatio)) ? criticalColor
            : (ramBox.availableGiB < (ramBox.totalGiB * ramBox.ramWarnRatio)) ? warningColor
            : normalColor;

            var valueStr = ramBox.availableGiB === 0.0
            ? " -- GiB"
            : (" " + ramBox.availableGiB.toFixed(1) + " GiB");

            return "<font color='" + greenColor + "'>RAM:</font>" +
            "<font color='" + ram_color + "'>" + valueStr + "</font>";
        }
    }

    HoverHandler {
        id: ramHoverTracker
        onHoveredChanged: {
            if (hovered) {
                // Clear the string buffer container right before launching the new scan sweep pass
                ramBox.textAccumulatorBuffer = "";
                topProcFetcher.running = false;
                topProcFetcher.running = true;
            }
        }
    }

    PanelWindow {
        id: fixedTooltipWindow
        screen: standardBarWindow.screen
        visible: ramHoverTracker.hovered

        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.namespace: "quickshell-ram-tooltip"
        WlrLayershell.keyboardFocus: WlrLayershell.None

        anchors.top: true
        anchors.right: true

        WlrLayershell.margins.top: 55
        WlrLayershell.margins.right: 15

        implicitWidth: 375
        implicitHeight: 375
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
                    text: "📊 TOP MEMORY CONSUMERS:"
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

                ScrollView {
                    width: parent.width
                    height: 300
                    clip: true

                    Text {
                        width: parent.width
                        text: ramBox.topProcessesText
                        font.family: "monospace"
                        font.pixelSize: 20
                        color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "white"
                        lineHeight: 1.25
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
            ramStatsProc.running = false;
            ramStatsProc.running = true;

            if (ramHoverTracker.hovered) {
                ramBox.textAccumulatorBuffer = "";
                topProcFetcher.running = false;
                topProcFetcher.running = true;
            }
        }
    }
}
