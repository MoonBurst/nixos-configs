import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Rectangle {
    id: ramBox

    width: 175
    height: 35
    radius: 10
    border.width: 3

    color: "black"
    border.color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"

    property real totalGiB: 0.0
    property real availableGiB: 0.0
    property string topProcessesText: "Loading system processes..."
    property string textAccumulatorBuffer: ""
    property var barWindow: null

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
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { ramBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: { if (ramBox.textAccumulatorBuffer.trim() !== "") ramBox.topProcessesText = ramBox.textAccumulatorBuffer.trim(); }
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
            const greenColor = (root && root.theme && root.theme.base0C !== undefined) ? root.theme.base0C.toString() : "#04f100";
            
            var usedGiB = ramBox.totalGiB - ramBox.availableGiB;
            var usageRatio = (ramBox.totalGiB > 0) ? (usedGiB / ramBox.totalGiB) : 0.0;
            
            var normalYellow = (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow";
            var warnOrange = (root && root.theme && root.theme.base09 !== undefined) ? root.theme.base09.toString() : "#FE8019";
            var critRed = (root && root.theme && root.theme.base08 !== undefined) ? root.theme.base08.toString() : "red";
            
            // FIXED: Dynamically matches thresholds: yellow under 50%, orange warning at 50%, and critical red danger above 85%!
            var dataColor = normalYellow;
            if (usageRatio >= 0.75) {
                dataColor = critRed;
            } else if (usageRatio >= 0.50) {
                dataColor = warnOrange;
            }

            var valueStr = ramBox.availableGiB === 0.0 ? " -- GiB" : (" " + ramBox.availableGiB.toFixed(1) + " GiB");
            return "<font color='" + greenColor + "'>RAM:</font><font color='" + dataColor + "'>" + valueStr + "</font>";
        }
    }

    HoverHandler {
        id: ramHoverTracker
        onHoveredChanged: { if (hovered) { ramBox.textAccumulatorBuffer = ""; topProcFetcher.running = false; topProcFetcher.running = true; } }
    }

    PanelWindow {
        id: fixedTooltipWindow
        screen: ramBox.barWindow ? ramBox.barWindow.screen : null
        visible: ramHoverTracker.hovered 
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.namespace: "quickshell-ram-tooltip"
        WlrLayershell.keyboardFocus: WlrLayershell.None
        anchors.top: true
        anchors.right: true
        WlrLayershell.margins.top: 55
        WlrLayershell.margins.right: 15
        implicitWidth: 460 
        implicitHeight: 380
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
                Text { text: "📊 TOP MEMORY CONSUMERS:"; font.family: "monospace"; font.pixelSize: 20; font.bold: true; color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow" }
                Rectangle { width: parent.width; height: 2; color: "#333333" }
                ScrollView {
                    width: parent.width; height: 300; clip: true
                    Text { width: parent.width; text: ramBox.topProcessesText; font.family: "monospace"; font.pixelSize: 20; color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"; lineHeight: 1.15 }
                }
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            ramStatsProc.running = false;
            ramStatsProc.running = true;
            if (ramHoverTracker.hovered) { ramBox.textAccumulatorBuffer = ""; topProcFetcher.running = false; topProcFetcher.running = true; }
        }
    }
}
