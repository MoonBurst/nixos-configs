import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string currentDefinition: ""

    Process {
        id: dictionaryProcess

        stdout: SplitParser {
            onRead: data => {
                root.currentDefinition = data
            }
        }
    }

    function fetch(rootObject, word) {

        if (!word || word.length === 0) {
            rootObject.mathResultString = "No word provided."
            return
        }

        rootObject.isMathMode = true

        dictionaryProcess.running = false

        dictionaryProcess.command = [
            "sh",
            "-c",
            `dict "${word}" 2>/dev/null || echo "No definition found."`
        ]

        dictionaryProcess.running = true

        Qt.callLater(function() {
            rootObject.mathResultString =
            root.currentDefinition || "Loading..."
        })
    }
}
