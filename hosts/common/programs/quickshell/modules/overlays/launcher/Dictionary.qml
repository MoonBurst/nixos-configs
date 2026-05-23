
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
                let trimmedData = data.trim()
                root.currentDefinition = trimmedData ? trimmedData : "No definition found."
            }
        }
    }

    function fetch(word) {
        if (!word || word.length === 0) {
            root.currentDefinition = "Please enter a word to define."
            return
        }

        root.currentDefinition = `Loading definition for '${word}'...`
        dictionaryProcess.running = false
        dictionaryProcess.command = [
            "sh",
            "-c",
            `dict "${word}"`
        ]
        dictionaryProcess.running = true
    }
}
