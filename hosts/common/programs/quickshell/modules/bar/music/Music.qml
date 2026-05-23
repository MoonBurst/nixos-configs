import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Rectangle {
    id: musicBox

    // FIXED: Added property target definition so shell.qml mapping context works flawlessly
    property var barWindow: null
    property string trackStr: "No Track"

    // Layout parameters and frames scale dynamically to match your global design rule profiles
    width: 200
    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth

    color: shell.theme.base00
    border.color: shell.theme.base05

    Process {
        id: musicProc
        running: true
        command: ["sh", "-c", "playerctl metadata --format '{{ artist }} - {{ title }}' 2>/dev/null || echo '000 MP3s n...'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim() !== "") {
                    musicBox.trackStr = data.trim().substring(0, 15);
                }
            }
        }
    }

    Text {
        id: musicText
        anchors.fill: parent
        anchors.margins: 5

        color: shell.theme.base05
        text: "🎵 " + musicBox.trackStr

        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize - 2
        font.bold: true
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: {
            musicProc.running = false;
            musicProc.running = true;
        }
    }
}
