import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

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
