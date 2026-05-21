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

    // --- OUTPUT PROPERTIES ---
    property string currentDefinition: ""
    property string currentSynonyms: ""
    property string currentAntonyms: ""
    property string currentSpelling: ""

    // --- PROCESSES ---
    Process {
        id: dictionaryProcess
        stdout: SplitParser {
            onRead: data => {
                root.currentDefinition = data.trim()
            }
        }
    }

    Process {
        id: thesaurusProcess
        stdout: SplitParser {
            onRead: data => {
                root.currentSynonyms = data.trim()
            }
        }
    }

    Process {
        id: antonymProcess
        stdout: SplitParser {
            onRead: data => {
                root.currentAntonyms = data.trim()
            }
        }
    }

    Process {
        id: spellProcess
        stdout: SplitParser {
            onRead: data => {
                // For aspell pipe mode, correct word is on a line starting with '*'
                // If not found, suggest alternatives
                let lines = data.trim().split('\n');
                if (lines.length > 0) {
                    let found = lines.find(x => x.startsWith("*"));
                    if (found) {
                        root.currentSpelling = "✔ Spelled correctly";
                    } else if (lines.length > 1 && lines[1].startsWith("&")) {
                        let suggestionLine = lines[1];
                        let suggestions = suggestionLine.split(":")[1];
                        root.currentSpelling = "Suggestions: " + suggestions;
                    } else {
                        root.currentSpelling = "No spelling suggestions found";
                    }
                } else {
                    root.currentSpelling = "Spell check error or not available";
                }
            }
        }
    }

    // --- MAIN FETCH FUNCTION ---
    function fetch(rootObject, word) {
        if (!word || word.length === 0) {
            rootObject.mathResultString = "No word provided."
            return
        }

        rootObject.isMathMode = true

        // --- Definitions ---
        dictionaryProcess.running = false;
        dictionaryProcess.command = [
            "sh",
            "-c",
            `dict "${word}" 2>/dev/null || echo "No definition found."`
        ];
        dictionaryProcess.running = true;

        // --- Thesaurus ---
        thesaurusProcess.running = false;
        thesaurusProcess.command = [
            "sh",
            "-c",
            `wn "${word}" -synsn | grep -v '^\s*$' || echo "No synonyms found."`
        ];
        thesaurusProcess.running = true;

        // --- Antonyms ---
        antonymProcess.running = false;
        antonymProcess.command = [
            "sh",
            "-c",
            `wn "${word}" -antsn | grep -v '^\s*$' || echo "No antonyms found."`
        ];
        antonymProcess.running = true;

        // --- Spell check (using aspell if present, else hunspell) ---
        spellProcess.running = false;
        spellProcess.command = [
            "sh",
            "-c",
            "if command -v aspell >/dev/null; then echo \"" + word + "\" | aspell pipe; " +
            "elif command -v hunspell >/dev/null; then echo \"" + word + "\" | hunspell; " +
            "else echo \"Spell checker not found\"; fi"
        ];
        spellProcess.running = true;

        // Optionally, update a UI result:
        Qt.callLater(function() {
            let result =
            "<b>Definition:</b>\n" + (root.currentDefinition || "Loading...") +
            "\n\n<b>Synonyms:</b>\n" + (root.currentSynonyms || "Loading...") +
            "\n\n<b>Antonyms:</b>\n" + (root.currentAntonyms || "Loading...") +
            "\n\n<b>Spell Check:</b>\n" + (root.currentSpelling || "Loading...");

            rootObject.mathResultString = result;
        });
    }
}
