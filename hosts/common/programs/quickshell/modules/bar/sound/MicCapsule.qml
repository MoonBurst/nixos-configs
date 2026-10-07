import QtQuick
import Quickshell
import Quickshell.Io
import "../../style"
import "../../common" as Common

Item {
    id: micBox
    property var barWindow: null
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: (shell && shell.theme && shell.theme.slantWidth) ? shell.theme.slantWidth : 12
    property string micDisplayText: "Mic: --"
    property bool muted: false

    readonly property color themeBase05: (shell && shell.theme) ? shell.theme.base05 : "yellow"
    readonly property color themeBase08: (shell && shell.theme) ? shell.theme.base08 : "#ff0000"
    readonly property color themeBase0C: (shell && shell.theme) ? shell.theme.base0C : "#04f100"
    readonly property int themeFontSize: (shell && shell.theme) ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"

    implicitWidth: micText.implicitWidth + bg.leftPadding + bg.rightPadding + 20
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        containmentMask: bg
        slantLeft: micBox.slantLeft
        slantRight: micBox.slantRight
        slantWidth: micBox.slantWidth
        borderColor: micBox.muted ? micBox.themeBase08 : micBox.themeBase05
    }

    function applyMicData(data) {
        if (!data) return;
        var clean = data.trim();
        var parts = clean.split("|");
        if (parts.length >= 2) {
            var volVal = parseInt(parts[0]) || 0;
            var isMuted = parts[1] === "1";
            micBox.muted = isMuted;

            var mNum = isMuted ? "MUTED" : (volVal + "%");
            var statusColor = isMuted ? micBox.themeBase08.toString() : micBox.themeBase05.toString();
            micBox.micDisplayText = "<font color='" + micBox.themeBase0C + "'>Mic:</font> <font color='" + statusColor + "'>" + mNum + "</font>";

            if (shell && shell.settingsManager) {
                shell.settingsManager.updateMicFromSystem(isMuted, volVal);
            }
        }
    }

    // Persistent PipeWire event listener for microphone source changes
    Process {
        id: micListener
        running: true
        command: Common.LuaRunner.cmd("modules/bar/sound/backend/AudioEngine.lua", "monitor-source")
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => micBox.applyMicData(data)
        }
    }

    Process {
        id: micQueryProc
        running: true
        command: Common.LuaRunner.cmd("modules/bar/sound/backend/AudioEngine.lua", "get-source")
        stdout: SplitParser {
            onRead: data => micBox.applyMicData(data)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            micQueryProc.running = false;
            micQueryProc.running = true;
        }
    }

    Process {
        id: micMuteCmd
        command: Common.LuaRunner.cmd("modules/bar/sound/backend/AudioEngine.lua", "toggle-source-mute")
        onExited: {
            micQueryProc.running = false;
            micQueryProc.running = true;
        }
    }

    TapHandler {
        onTapped: {
            micMuteCmd.running = false;
            micMuteCmd.running = true;
        }
    }

    Text {
        id: micText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 4
        anchors.rightMargin: bg.rightPadding + 4
        anchors.topMargin: 2; anchors.bottomMargin: 2
        textFormat: Text.RichText
        text: micBox.micDisplayText
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        clip: true
    }
}
