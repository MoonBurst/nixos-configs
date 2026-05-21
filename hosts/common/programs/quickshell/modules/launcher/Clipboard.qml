import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // === THEME VARIABLES: GROUPED AT TOP ===
    property int fontSize: 20
    property color mainColor: "#F7F700"
    property color backgroundColor: "#1a1a1a"
    property color borderColor: "#F7F700"
    property int borderRadius: 8
    property int borderWidth: 2

    function loadClipboard(rootObject) {
        console.log("Clipboard module loaded")
    }

    function copyItem(clipId) {
        copyProcess.running = false

        copyProcess.command = [
            "sh",
            "-c",
            `cliphist decode ${clipId} | wl-copy`
        ]

        copyProcess.running = true
    }

    Process {
        id: copyProcess
    }

    Process {
        id: clipboardIndexer

        stdout: SplitParser {
            onRead: data => {
                console.log(data)
            }
        }
    }
}
