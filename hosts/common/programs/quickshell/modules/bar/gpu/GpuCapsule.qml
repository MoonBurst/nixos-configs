import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io

Rectangle {
    id: gpuBox

    Binding {
        target: gpuBox
        property: "Layout.preferredWidth"
        value: gpuText.implicitWidth + 30
    }

    Binding {
        target: gpuBox
        property: "width"
        value: gpuText.implicitWidth + 30
    }

    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth

    color: shell.theme.base00
    border.color: shell.theme.base05

    property string gpuUsageRaw: "0"
    property string gpuTempRaw: "0"
    property string gpuPowerRaw: "0"
    property string gpuVramFreeRaw: "0"
    property var barWindow: null

    Process {
        id: gpuStatsProc
        running: true
        command: [
            "sh", "-c",
            "card_dir=$(ls -d /sys/class/drm/card*/device 2>/dev/null | head -n 1); [ -z \"$card_dir\" ] && echo '0:0:0:0' && exit; usage=$(cat \"$card_dir/gpu_busy_percent\" 2>/dev/null || echo '0'); temp=$(awk '{print int($1/1000)}' \"$card_dir/hwmon\"/hwmon*/temp1_input 2>/dev/null | head -n 1 || echo '0'); power=$(awk '{print int($1/1000000)}' \"$card_dir/hwmon\"/hwmon*/power1_average 2>/dev/null | head -n 1 || echo '0'); total=$(cat \"$card_dir/mem_info_vram_total\" 2>/dev/null || echo '0'); used=$(cat \"$card_dir/mem_info_vram_used\" 2>/dev/null || echo '0'); free_vram=$(awk -v t=\"$total\" -v u=\"$used\" 'BEGIN {printf \"%.0f\", (t-u)/1073741824}'); echo \"$usage:$temp:$power:$free_vram\""
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length === 4) {
                    gpuBox.gpuUsageRaw = (parseInt(parts[0]) || 0).toString();
                    gpuBox.gpuTempRaw = (parseInt(parts[1]) || 0).toString();
                    gpuBox.gpuPowerRaw = (parseInt(parts[2]) || 0).toString();
                    gpuBox.gpuVramFreeRaw = (parseInt(parts[3]) || 0).toString();
                }
            }
        }
    }

    Text {
        id: gpuText
        anchors.centerIn: parent
        textFormat: Text.RichText
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: {
            const greenColor = shell.theme.base0C.toString();
            const yellowColor = shell.theme.base05.toString();
            const leading0s = shell.theme.base00.toString();

            const orangeAlert = shell.theme.base09.toString();
            const redAlert = shell.theme.base08.toString();

            const currentTemp = parseInt(gpuBox.gpuTempRaw) || 0;
            const currentFreeVram = parseInt(gpuBox.gpuVramFreeRaw) || 0;

            let tempColor = yellowColor;
            if (currentTemp >= 80) tempColor = redAlert;
            else if (currentTemp >= 70) tempColor = orangeAlert;

            let vramColor = yellowColor;
            if (currentFreeVram <= 4) vramColor = redAlert;
            else if (currentFreeVram <= 12) vramColor = orangeAlert;

            function formatStat(rawVal, targetLength, activeColor) {
                let padCount = targetLength - rawVal.length;
                let zerosStr = "";
                if (padCount > 0) {
                    zerosStr = "<font color='" + leading0s + "'>" + "0".repeat(padCount) + "</font>";
                }
                return zerosStr + "<font color='" + activeColor + "'>" + rawVal + "</font>";
            }

            return "<font color='" + greenColor + "'>GPU:</font> " +
            formatStat(gpuBox.gpuUsageRaw, 2, yellowColor) + "<font color='" + yellowColor + "'>%</font> " +
                formatStat(gpuBox.gpuTempRaw, 2, tempColor) + "<font color='" + tempColor + "'>°C</font> " +
                    formatStat(gpuBox.gpuPowerRaw, 3, yellowColor) + "<font color='" + yellowColor + "'>W</font> " +
                        formatStat(gpuBox.gpuVramFreeRaw, 2, vramColor) + "<font color='" + vramColor + "'>GiB</font>";
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
