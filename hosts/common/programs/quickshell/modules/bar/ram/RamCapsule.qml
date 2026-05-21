import QtQuick
import Quickshell.Io

Rectangle {
    id: ramBox
    width: 150

    property int ramAvailable: 0
    property int ramWarn: 16
    property int ramCrit: 8

    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(ramBox, ramText);
        }
    }

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
        anchors.margins: 10
        textFormat: Text.RichText
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        text: {
            if (!root.theme) {
                return "<font color='green'>RAM:</font>   -- GiB";
            }

            const greenColor    = root.theme.base0C.toString();
            const normalColor   = root.theme.base05.toString();
            const warningColor  = root.theme.base0A.toString();
            const criticalColor = root.theme.base08.toString();

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
