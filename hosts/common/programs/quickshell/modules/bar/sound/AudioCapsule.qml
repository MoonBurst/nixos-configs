import QtQuick
import Quickshell
import Quickshell.Io
import "../../style"

Item {
    id: audioBox
    property var barWindow: null
    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: (shell && shell.theme && shell.theme.slantWidth) ? shell.theme.slantWidth : 12
    property string audioDisplayText: "Audio: --%"

    readonly property color themeBase05: (shell && shell.theme) ? shell.theme.base05 : "yellow"
    readonly property color themeBase08: (shell && shell.theme) ? shell.theme.base08 : "#ff0000"
    readonly property int themeFontSize: (shell && shell.theme) ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"

    implicitWidth: audioText.implicitWidth + bg.leftPadding + bg.rightPadding + 20
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        containmentMask: bg
        slantLeft: audioBox.slantLeft
        slantRight: audioBox.slantRight
        slantWidth: audioBox.slantWidth
    }

    // 1. HIGH-PERFORMANCE PERSISTENT AUDIO MONITOR
    // Stays alive permanently, reading volume changes from stdout without timer loops
    Process {
        id: audioListener
        running: true
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@; pw-mon -b | grep --line-buffered -E 'sinks|volume|mute'"]
        
        function parseWpctlLine(lineData) {
            if (!lineData) return;
            var clean = lineData.trim();
            var isMuted = clean.indexOf("[MUTED]") !== -1;
            var match = clean.match(/Volume:\s+([0-9.]+)/);
            var vNum = "--%";
            if (match) vNum = Math.round(parseFloat(match[1]) * 100) + "%";
            var txtColor = isMuted ? audioBox.themeBase08.toString() : audioBox.themeBase05.toString();
            audioBox.audioDisplayText = "<font color='" + audioBox.themeBase05 + "'>Audio:</font> <font color='" + txtColor + "'> " + vNum + "</font>";
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                // Whenever PipeWire emits a volume event, fetch the clean string value instantly
                audioQueryTrigger.running = false;
                audioQueryTrigger.running = true;
            }
        }
    }

    // Quick one-pass helper to parse real-time levels safely
    Process {
        id: audioQueryTrigger
        running: true
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => audioListener.parseWpctlLine(data)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) deviceToggleProcess.running = true;
            else if (mouse.button === Qt.RightButton) muteToggleProcess.running = true;
        }
        onWheel: (wheel) => {
            var step = wheel.angleDelta.y > 0 ? "5%+" : "5%-";
            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", step, "--limit", "1.0"]);
            audioQueryTrigger.running = true;
        }
    }

    Text {
        id: audioText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 4
        anchors.rightMargin: bg.rightPadding + 4
        anchors.topMargin: 2; anchors.bottomMargin: 2
        text: audioBox.audioDisplayText
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        textFormat: Text.RichText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        clip: true
    }

    // Optimized On-Demand Device Switching Task
    Process {
        id: deviceToggleProcess
        running: false
        command: [
            "sh", "-c",
            "SCR=\"$HOME/nix/hosts/common/scripts/sound_sink_switcher.sh\"; if [ -x \"$SCR\" ]; then \"$SCR\"; else next_sink=$(wpctl status | awk '/Sinks:/{flag=1; next} /Sources:/{flag=0} flag && /^[ \\t]+[0-9]+/ {print $1}' | tr -d '.' | grep -v '*' | head -n 1); [ -n \"$next_sink\" ] && wpctl set-default \"$next_sink\"; fi"
        ]
        onExited: audioQueryTrigger.running = true
    }

    Process {
        id: muteToggleProcess
        running: false
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onExited: audioQueryTrigger.running = true
    }
}
