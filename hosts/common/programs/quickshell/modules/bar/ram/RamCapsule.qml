import QtQuick
import Quickshell.Io

import Theme

Rectangle {
    id: ramBox

    // Sovereign sizing rules restore visual visibility matching your bar grid
    width: 150
    height: 35
    radius: 10
    border.width: 3

    // Direct memory lookups pointing straight to your immutable compiled Nix-Store colors
    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

    property int ramAvailable: 0
    property int ramWarn: 16
    property int ramCrit: 8

    Process {
        id: ramStatsProc
        running: true
        command: ["sh", "-c", "ram=$(free -g | awk '/Mem/ {print $7}'); echo ${ram:-0}"]
        stdout: SplitParser {
            onRead: data => {
                var ram = parseInt(data.trim());
                if (!isNaN(ram)) {
                    ramBox.ramAvailable = ram;
                }
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
            // Secure nested checks guarantee silent initialization logs
            const greenColor    = (typeof Theme !== 'undefined' && Theme.base0C !== undefined) ? Theme.base0C.toString() : "green";
            const normalColor   = (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05.toString() : "yellow";
            const warningColor  = (typeof Theme !== 'undefined' && Theme.base0A !== undefined) ? Theme.base0A.toString() : "orange";
            const criticalColor = (typeof Theme !== 'undefined' && Theme.base08 !== undefined) ? Theme.base08.toString() : "red";

            var ram_color = (ramBox.ramAvailable < ramBox.ramCrit) ? criticalColor
            : (ramBox.ramAvailable < ramBox.ramWarn) ? warningColor
            : normalColor;

            var valueStr = ramBox.ramAvailable === 0
            ? " -- GiB"
            : (" " + ramBox.ramAvailable + " GiB").padStart(8, ' ');

            return "<font color='" + greenColor + "'>RAM:</font>" +
            "<font color='" + ram_color + "'>" + valueStr + "</font>";
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            ramStatsProc.running = true;
        }
    }
}
