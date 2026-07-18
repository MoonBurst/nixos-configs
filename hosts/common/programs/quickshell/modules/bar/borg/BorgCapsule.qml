import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io
import "../../style"

Item {
    id: borgBox

    property var barWindow: null
    property string borgProgress: "Idle"

    width: 140
    height: parent.height

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: "Left"
        slantRight: "Left"
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: borgPoller.running = true
    }

    Process {
        id: borgPoller
        command: ["cat", "/dev/shm/borg-offsite-status.json"]

        stdout: SplitParser {
            onRead: data => {
                const rawLine = data.trim()
                if (!rawLine.length) {
                    borgBox.borgProgress = "Idle"
                    return
                }
                try {
                    const statusObj = JSON.parse(rawLine)
                    if (statusObj.status === "idle") {
                        borgBox.borgProgress = "Idle"
                    } else if (statusObj.status === "indexing") {
                        borgBox.borgProgress = "Idx..."
                    } else if (statusObj.status === "running") {
                        let cleanSize = statusObj.uploaded_size.replace(/[D\s]+$/, "").trim()
                        cleanSize = cleanSize.replace(/\.[0-9]+/, "")
                        cleanSize = cleanSize.replace(/[\s]*MB/, "M").replace(/[\s]*GB/, "G")
                        borgBox.borgProgress = statusObj.percent + "% (" + cleanSize + ")"
                    }
                } catch (e) {
                    borgBox.borgProgress = "Sync..."
                }
            }
        }
    }

    Text {
        id: borgText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: (shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12
        anchors.bottomMargin: (shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12

        text: {
            const fontColor = (shell && shell.theme) ? (shell.theme.base05 || "yellow").toString() : "yellow";
            if (borgBox.borgProgress === "Idx...") {
                return "<font color='" + fontColor + "'>Indexing</font>";
            } else if (borgBox.borgProgress === "Idle" || borgBox.borgProgress === "Sync...") {
                return "<font color='" + fontColor + "'>Borg:</font> <font color='" + fontColor + "'>" + borgBox.borgProgress + "</font>";
            } else {
                return "<font color='" + fontColor + "'>" + borgBox.borgProgress + "</font>";
            }
        }

        font.family: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"
        font.pixelSize: (shell && shell.theme) ? (shell.theme.globalFontSize || 14) : 14
        font.bold: true
        textFormat: Text.RichText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
