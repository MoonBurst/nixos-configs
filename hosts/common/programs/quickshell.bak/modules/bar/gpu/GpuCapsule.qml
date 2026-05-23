import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Rectangle {
    id: gpuBox

    width: 210
    height: 35
    radius: 10
    border.width: 3

    color: "black"
    border.color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"

    property string gpuUsageStr: "0%"
    property string gpuTempStr: "0°C"
    property string gpuPowerStr: "0W"
    property var barWindow: null

    Process {
        id: gpuStatsProc
        running: true
        // FIXED: Expanded sysfs searches across card0 and card1 locations to match NixOS AMDGPU hardware paths perfectly
        command: ["sh", "-c", "usage=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -n 1 || echo '0'); temp=$(awk '{print int($1/1000)}' /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -n 1 || echo '0'); power=$(awk '{print int($1/1000000)}' /sys/class/drm/card*/device/hwmon/hwmon*/power1_average 2>/dev/null | head -n 1 || echo '0'); echo \"$usage:$temp°C:${power}W\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length === 3) {
                    gpuBox.gpuUsageStr = parts[0] + "%";
                    gpuBox.gpuTempStr = parts[1];
                    gpuBox.gpuPowerStr = parts[2];
                }
            }
        }
    }

    Text {
        id: gpuText
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
            
            return "<font color='" + greenColor + "'>GPU:</font> " +
                   "<font color='" + yellowColor + "'>" + gpuBox.gpuUsageStr + " " + gpuBox.gpuTempStr + " " + gpuBox.gpuPowerStr + "</font>";
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            gpuStatsProc.running = false;
            gpuStatsProc.running = true;
        }
    }
}
