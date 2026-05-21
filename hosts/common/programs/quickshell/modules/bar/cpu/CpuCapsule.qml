import QtQuick
import Quickshell.Io

Rectangle {
    id: cpuBox
    width: 200

    // --- Data Properties ---
    property int cpuUsage: 0
    property int cpuTemp: 0

    // --- Thresholds ---
    property int tempWarn: 65
    property int tempCrit: 70
    property int usageWarn: 50
    property int usageCrit: 80

    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(cpuBox, cpuText);
        }
    }

    // --- Data Fetching Process ---
    Process {
        id: cpuStatsProc
        running: true
        command: ["sh", "-c", "temp_raw=$(cat /sys/class/hwmon/hwmon2/temp1_input 2>/dev/null); temp=$(($temp_raw/1000)); usage=$(top -bn2 | grep '^%Cpu' | tail -1 | awk '{print int(100-$8)}'); echo \"${temp:-0} ${usage:-0}\""]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.includes(' ')) {
                    var stats = data.trim().split(' ');
                    if (stats.length === 2) {
                        var temp = parseInt(stats[0]);
                        var usage = parseInt(stats[1]);
                        if (!isNaN(temp)) {
                            cpuBox.cpuTemp = temp;
                        }
                        if (!isNaN(usage)) {
                            cpuBox.cpuUsage = usage;
                        }
                    }
                } else {
                    cpuBox.cpuTemp = 0;
                    cpuBox.cpuUsage = 0;
                }
            }
        }
    }

    Text {
        id: cpuText
        anchors.centerIn: parent
        textFormat: Text.RichText
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true

        text: {
            if (!root.theme) {
                return "<font color='green'>CPU:</font>   --%   --°C";
            }

            const greenColor    = root.theme.base0C.toString();
            const normalColor   = root.theme.base05.toString(); // yellow
            const warningColor  = root.theme.base0A.toString(); // orange
            const criticalColor = root.theme.base08.toString(); // red

            var temp_color = (cpuBox.cpuTemp >= cpuBox.tempCrit) ? criticalColor : (cpuBox.cpuTemp >= cpuBox.tempWarn) ? warningColor : normalColor;
            var usage_color = (cpuBox.cpuUsage >= cpuBox.usageCrit) ? criticalColor : (cpuBox.cpuUsage >= cpuBox.usageWarn) ? warningColor : normalColor;

            const usageStr = cpuBox.cpuUsage === 0 ? " --%" : (cpuBox.cpuUsage + "%").padStart(4, ' ');
            const tempStr  = cpuBox.cpuTemp === 0 ? " --°C" : (cpuBox.cpuTemp + "°C").padStart(4, ' ');

            return "<font color='" + greenColor + "'>CPU:</font>&nbsp;" +
            "<font color='" + usage_color + "'>" + usageStr + "</font>" + "&nbsp;&nbsp;" +
            "<font color='" + temp_color + "'>" + tempStr + "</font>";
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuStatsProc.running = true;
        }
    }
}
