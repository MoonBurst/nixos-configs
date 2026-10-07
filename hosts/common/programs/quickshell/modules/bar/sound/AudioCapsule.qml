import QtQuick
import Quickshell
import Quickshell.Io
import "../../style"
import "../../common" as Common

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

    function applyVolumeData(data) {
        if (!data) return;
        var clean = data.trim();
        var parts = clean.split("|");
        if (parts.length >= 2) {
            var vNum = parts[0] + "%";
            var isMuted = parts[1] === "1";
            var txtColor = isMuted ? audioBox.themeBase08.toString() : audioBox.themeBase05.toString();
            audioBox.audioDisplayText = "<font color='" + audioBox.themeBase05 + "'>Audio:</font> <font color='" + txtColor + "'> " + vNum + "</font>";
        }
    }

    // Persistent real-time event listener: updates immediately on keyboard hotkeys
    Process {
        id: audioListener
        running: true
        command: Common.LuaRunner.cmd("modules/bar/sound/backend/AudioEngine.lua", "monitor-sink")
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => audioBox.applyVolumeData(data)
        }
    }

    // One-pass status query process
    Process {
        id: audioQueryTrigger
        running: true
        command: Common.LuaRunner.cmd("modules/bar/sound/backend/AudioEngine.lua", "get-sink")
        stdout: SplitParser {
            onRead: data => audioBox.applyVolumeData(data)
        }
    }

    // Synchronization heartbeat: guarantees hotkeys and external changes never stall
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            audioQueryTrigger.running = false;
            audioQueryTrigger.running = true;
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
            Quickshell.execDetached(Common.LuaRunner.cmd("modules/bar/sound/backend/AudioEngine.lua", "set-sink-volume", step));
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

    Process {
        id: deviceToggleProcess
        running: false
        command: Common.LuaRunner.cmd("modules/bar/sound/backend/AudioEngine.lua", "switch-sink")
        onExited: audioQueryTrigger.running = true
    }

    Process {
        id: muteToggleProcess
        running: false
        command: Common.LuaRunner.cmd("modules/bar/sound/backend/AudioEngine.lua", "toggle-sink-mute")
        onExited: audioQueryTrigger.running = true
    }
}
