import QtQuick
import Quickshell.Io

Rectangle {
    id: gpuBox
    width: 140

    property color colorLabelGreen: "#00FF00"
    property color colorNormalText: "#FFFFFF"

    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(gpuBox);
        }
    }

    property string gpuDisplayText: "GPU: --"

    Process {
        id: gpuProc
        running: true
        command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var load = Math.round(parseFloat(data.trim()));
                gpuBox.gpuDisplayText = "<font color='" + gpuBox.colorLabelGreen + "'>GPU:</font> <font color='" + gpuBox.colorNormalText + "'>" + (isNaN(load) ? "--" : load + "%").padStart(4, ' ') + "</font>";
            }
        }
    }

    Text { anchors.centerIn: parent; textFormat: Text.RichText; text: gpuBox.gpuDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: gpuProc.running = true }
}
