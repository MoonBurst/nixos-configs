import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: ramBox
    color: Theme.colorBaseBg
    radius: Theme.capsuleRadius
    border.width: Theme.capsuleBorderWidth
    border.color: Theme.colorOutline
    width: 120
    height: Theme.capsuleHeight

    property string ramDisplayText: "RAM: -- GiB"
    property string ramTooltipText: ""

    Process {
        id: ramProc
        running: true
        command: [
            "sh", "-c", 
            "A=$(free -g | awk '/Mem/ {print $7}'); " +
            "T=$(ps -eo rss,comm --no-headers | awk '{mag[$2]+=$1} END {for (i in mag) print mag[i], i}' | sort -rn | awk 'NR<=10 {printf \"%%7d MB  %%s\\n\", $1/1024, $2}' | tr '\\n' ';'); " +
            "echo \"$A|$T\""
        ]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var bits = data.trim().split("|");
                if (bits.length < 2) return;

                var avail = parseInt(bits[0]);
                ramBox.ramTooltipText = bits[1].replace(/;/g, "\n");
                var col = avail < 8 ? '#FF0000' : (avail < 16 ? '#FFA500' : '#00FF00');
                
                ramBox.ramDisplayText = "<font color='" + col + "'>RAM: " + String(avail).padStart(2, ' ') + " GiB</font>";
            }
        }
    }

    HoverHandler { id: ramHover }

    ToolTip {
        visible: ramHover.hovered; delay: 100 
        contentItem: Text { text: ramBox.ramTooltipText; color: Theme.colorNormalText; font.family: "monospace"; font.pixelSize: 13 }
        background: Rectangle { color: Theme.colorBaseBg; border.color: "#003399"; border.width: Theme.capsuleBorderWidth; radius: 6 }
    }

    Text { anchors.centerIn: parent; textFormat: Text.RichText; text: ramBox.ramDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: ramProc.running = true }
}
