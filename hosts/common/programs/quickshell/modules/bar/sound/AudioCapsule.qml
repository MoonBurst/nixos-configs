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

    Process {
        id: audioFetcher
        running: true
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var clean = data.trim();
                var isMuted = clean.indexOf("[MUTED]") !== -1;
                var match = clean.match(/Volume:\s+([0-9.]+)/);
                var vNum = "--%";
                if (match) vNum = Math.round(parseFloat(match[1]) * 100) + "%";
                var txtColor = isMuted ? audioBox.themeBase08.toString() : audioBox.themeBase05.toString();
                audioBox.audioDisplayText = "<font color='" + audioBox.themeBase05 + "'>Audio:</font> <font color='" + txtColor + "'>" + vNum + "</font>";
            }
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
            audioFetcher.running = false; audioFetcher.running = true;
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

    Process {
        id: deviceToggleProcess
        running: false
        command: [
            "sh", "-c",
            "SCR=\"$HOME/nix/hosts/common/scripts/sound_sink_switcher.sh\"; if [ -x \"$SCR\" ]; then \"$SCR\"; else next_sink=$(wpctl status 2>/dev/null | awk '/Sinks:/{flag=1; next} /Sources:/{flag=0} flag && /^[ \\t]+[0-9]+/ {print $1}' | tr -d '.' | grep -v '*' | head -n 1); [ -n \"$next_sink\" ] && wpctl set-default \"$next_sink\"; fi"
        ]
    }

    Process {
        id: muteToggleProcess
        running: false
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onExited: { audioFetcher.running = false; audioFetcher.running = true; }
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: { audioFetcher.running = false; audioFetcher.running = true; } }
}
