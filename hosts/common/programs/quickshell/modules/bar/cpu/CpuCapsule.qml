import QtQuick
import Quickshell.Io

Rectangle {
    id: cpuBox
    width: 140

    property color colorLabelGreen: "#00FF00"
    property color colorNormalText: "#FFFFFF"

    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(cpuBox);
        }
    }

    property string cpuDisplayText: "CPU: --"

    Process {
        id: cpuProc
        running: true
        command: ["sh", "-c", "awk '/cpu / {p=$2+$4; t=$2+$4+$5} {print (p-p0)*100/(t-t0)\"\"} {p0=p; t0=t}' /proc/stat | tail -n 1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var load = Math.round(parseFloat(data.trim()));
                cpuBox.cpuDisplayText = "<font color='" + cpuBox.colorLabelGreen + "'>CPU:</font> <font color='" + cpuBox.colorNormalText + "'>" + (isNaN(load) ? "--" : load + "%").padStart(4, ' ') + "</font>";
            }
        }
    }

    Text { anchors.centerIn: parent; textFormat: Text.RichText; text: cpuBox.cpuDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: cpuProc.running = true }
}
