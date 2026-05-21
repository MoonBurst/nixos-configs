import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: cpuBox
    color: Theme.colorBaseBg
    radius: Theme.capsuleRadius
    border.width: Theme.capsuleBorderWidth
    border.color: Theme.colorOutline
    width: 150
    height: Theme.capsuleHeight

    property string cpuDisplayText: "CPU:  N/A  0%"

    Process {
        id: cpuProc
        running: true
        command: [
            "sh", "-c",
            "T=0; for f in /sys/class/hwmon/hwmon*/temp*_input; do " +
            "  [ -f \"$f\" ] || continue; n=$(cat \"$(dirname \"$f\")\"/name 2>/dev/null); " +
            "  if [ \"$n\" = \"k10temp\" ] || [ \"$n\" = \"coretemp\" ] || [ \"$n\" = \"zenpower\" ]; then " +
            "    T=$(( ($(cat \"$f\" 2>/dev/null) + 500) / 1000 )); break; " +
            "  fi; done; " +
            "[ \"$T\" -eq 0 ] && T=$(( ($(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null || echo 0) + 500) / 1000 )); " +
            "echo \"$T|$(top -bn1 | awk '/%Cpu/ {print int(100 - $8)}')\""
        ]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var raw = data.trim().split("|");
                if (raw.length < 2) return;

                var t = parseInt(raw[0]), u = parseInt(raw[1]);
                var tCol = (t === 0) ? "#ffa500" : (t >= 70 ? "#f53c3c" : (t >= 65 ? "#ffa500" : "#00FF00"));
                var uCol = u >= 80 ? "#f53c3c" : (u >= 50 ? "#ffa500" : "#00FF00");
                var lblCol = (t >= 70 || u >= 80) ? "#f53c3c" : ((t >= 65 || u >= 50 || t === 0) ? "#ffa500" : "#00FF00");
                
                var tStr = (t === 0) ? "N/A" : t + "°C";
                cpuBox.cpuDisplayText = "<font color='" + lblCol + "'>CPU:</font> " +
                                        "<font color='" + tCol + "'>" + tStr.padStart(5, ' ') + "</font> " +
                                        "<font color='" + uCol + "'>" + (u + "%").padStart(4, ' ') + "</font>";
            }
        }
    }

    Text { anchors.centerIn: parent; textFormat: Text.RichText; text: cpuBox.cpuDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: cpuProc.running = true }
}
