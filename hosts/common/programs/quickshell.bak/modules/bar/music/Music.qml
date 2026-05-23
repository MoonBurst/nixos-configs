import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Rectangle {
    id: musicBox

    // Widened slightly to 180px to safely fit the new playback status icons alongside track info strings
    width: 180
    height: 35
    radius: 10
    border.width: 3

    color: "black"
    border.color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"

    property string trackStr: "No Track"
    property string playStatusStr: "⏸"

    Process {
        id: musicProc
        running: true
        // FIXED: Combined track metadata checks and playing/paused status tracking queries inside a clean single-execution script sweep
        command: ["sh", "-c", "status=$(playerctl status 2>/dev/null || echo 'Paused'); meta=$(playerctl metadata --format '{{ artist }} - {{ title }}' 2>/dev/null || echo '000 MP3s n...'); echo \"$status:$meta\""]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var parts = data.trim().split(":");
                if (parts.length >= 2) {
                    var status = parts[0];
                    // Restores track information strings safely if they contain trailing colons
                    var meta = parts.slice(1).join(":");

                    musicBox.playStatusStr = (status === "Playing") ? "▶" : "⏸";
                    musicBox.trackStr = meta.trim().substring(0, 11);
                }
            }
        }
    }

    Text {
        id: musicText
        anchors.fill: parent
        anchors.margins: 5
        color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"
        
        // FIXED: Merged your new interactive play/pause track state parameters directly inside the monospace layout text string field
        text: musicBox.playStatusStr + " 🎵 " + musicBox.trackStr
        
        font.family: "monospace"
        font.pixelSize: 18
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    Timer {
        interval: 1500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            musicProc.running = false;
            musicProc.running = true;
        }
    }
}
