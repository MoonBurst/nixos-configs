import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Rectangle {
    id: ramBox

    // FIXED: Layout geometry and strokes match global design definitions natively
    width: 175
    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth

    color: shell.theme.base00
    border.color: shell.theme.base05

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
        anchors.margins: shell.theme.globalPadding
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
            if (usageRatio >= 0.85) {
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
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-ram-tooltip"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors.top: true
        anchors.right: true

        // FIXED: Dropdown alignment offsets pull natively from global layout padding profiles
        WlrLayershell.margins.top: shell.theme.globalPadding + 55
        WlrLayershell.margins.right: shell.theme.globalPadding + 15

        implicitWidth: 460
        implicitHeight: 380
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
                Text { text: "📊 TOP MEMORY CONSUMERS:"; font.family: shell.theme.fontFamily; font.pixelSize: shell.theme.globalFontSize; font.bold: true; color: shell.theme.base05 }
                Rectangle { width: parent.width; height: 2; color: shell.theme.base02 }
                ScrollView {
                    width: parent.width; height: 300; clip: true
                    Text { width: parent.width; text: ramBox.topProcessesText; font.family: shell.theme.fontFamily; font.pixelSize: shell.theme.globalFontSize; color: shell.theme.base05; lineHeight: 1.15 }
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
