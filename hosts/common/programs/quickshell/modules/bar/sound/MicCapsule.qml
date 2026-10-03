import QtQuick
import Quickshell
import Quickshell.Io
import "../../style"

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

    Process { id: micMuteCmd; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"] }

    // Persistent PipeWire event listener (Zero timer polling)
    Process {
        id: micListener
        running: true
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@; pw-mon -b | grep --line-buffered -E 'sources|source|volume|mute'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                micQueryProc.running = false;
                micQueryProc.running = true;
            }
        }
    }

    Process {
        id: micQueryProc
        running: true
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || echo 'Volume: 0.00'"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var raw = data.trim();
                var isMuted = raw.indexOf("[MUTED]") !== -1;
                micBox.muted = isMuted;
                var mNum = "0%";
                var volVal = 0;
                if (!isMuted) {
                    var mMatch = raw.match(/[0-9.]+/);
                    if (mMatch) {
                        volVal = Math.round(parseFloat(mMatch[0]) * 100);
                        mNum = volVal + "%";
                    }
                } else {
                    mNum = "MUTED";
                    var mMatch2 = raw.match(/[0-9.]+/);
                    if (mMatch2) volVal = Math.round(parseFloat(mMatch2[0]) * 100);
                }
                var statusColor = isMuted ? micBox.themeBase08.toString() : micBox.themeBase05.toString();
                micBox.micDisplayText = "<font color='" + micBox.themeBase0C + "'>Mic:</font> <font color='" + statusColor + "'>" + mNum + "</font>";

                if (shell && shell.settingsManager) {
                    shell.settingsManager.updateMicFromSystem(isMuted, volVal);
                }
            }
        }
    }

    TapHandler {
        onTapped: {
            micMuteCmd.running = false; micMuteCmd.running = true;
            micQueryProc.running = false; micQueryProc.running = true;
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
