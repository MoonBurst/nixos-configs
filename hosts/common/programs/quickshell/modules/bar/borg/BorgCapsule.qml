import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Rectangle {
    id: borgBox

    property
    var barWindow: null
    property string borgProgress: "Idle"

    width: 140
    height: parent.height

    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth
    color: shell.theme.base00
    border.color: shell.theme.base05

    /*
     * POLL BORG DATA PAYLOAD EVERY SECOND
     */
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            borgPoller.running = true
        }
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
                        // Strip trailing "D", spaces, and control characters
                        let cleanSize = statusObj.uploaded_size.replace(/[D\s]+$/, "").trim()

                        // Drop the decimal places (e.g., "49.42 MB" -> "49 MB")
                        cleanSize = cleanSize.replace(/\.[0-9]+/, "")

                        // Compress the unit spacing
                        cleanSize = cleanSize.replace(/[\s]*MB/, "M").replace(/[\s]*GB/, "G")

                        // Output format: "0% (49M)"
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
        anchors.margins: shell.theme.globalPadding

        // Clear, adaptive text formatting to fit your 140px panel width
        text: {
            if (borgBox.borgProgress === "Idx...") {
                return "<font color='" + shell.theme.base05.toString() + "'>Indexing</font>";
            } else if (borgBox.borgProgress === "Idle" || borgBox.borgProgress === "Sync...") {
                return "<font color='" + shell.theme.base05.toString() + "'>Borg:</font> " +
                "<font color='" + shell.theme.base05.toString() + "'>" + borgBox.borgProgress + "</font>";
            } else {
                // Active backup phase: Show only data metrics like "0% (49M)"
                return "<font color='" + shell.theme.base05.toString() + "'>" + borgBox.borgProgress + "</font>";
            }
        }

        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        textFormat: Text.RichText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
