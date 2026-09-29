import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int selectedIndex: 0
    property var definitionEntries: []
    readonly property int maxDefinitions: 8
    property string activeWord: ""
    property string dataAccumulatorBuffer: ""

    function selectNext() {
        if (definitionEntries.length === 0) return;
        selectedIndex = (selectedIndex + 1) % definitionEntries.length;
    }

    function selectPrev() {
        if (definitionEntries.length === 0) return;
        selectedIndex = (selectedIndex - 1 + definitionEntries.length) % definitionEntries.length;
    }

    function copySelected() {
        if (selectedIndex < 0 || selectedIndex >= definitionEntries.length) return;
        try {
            Quickshell.clipboardText = definitionEntries[selectedIndex].text;
            Quickshell.execDetached(["notify-send", "-a", "Dictionary", "📖 Definition Copied", definitionEntries[selectedIndex].text]);
        } catch (e) {}
    }

    function clearData(message) {
        selectedIndex = 0;
        definitionEntries = [{ type: "status", text: message }];
    }

    function stripHtml(htmlStr) {
        if (!htmlStr) return "";
        return htmlStr.replace(/<[^>]*>/g, "").replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&#39;/g, "'").trim();
    }

    // Supports both DictionaryAPI (Google/Oxford schema) and Wiktionary fallback schema
    function parseResponse(dataStr) {
        var entries = [];
        try {
            var response = JSON.parse(dataStr);

            // Schema 1: dictionaryapi.dev array
            if (Array.isArray(response) && response.length > 0) {
                for (var i = 0; i < response.length; i++) {
                    var meanings = response[i].meanings || [];
                    for (var m = 0; m < meanings.length; m++) {
                        var pos = meanings[m].partOfSpeech ? ("[" + meanings[m].partOfSpeech.toLowerCase() + "] ") : "";
                        var defs = meanings[m].definitions || [];
                        for (var d = 0; d < defs.length; d++) {
                            var cleanDef = root.stripHtml(defs[d].definition);
                            if (cleanDef.length > 0 && entries.length < root.maxDefinitions) {
                                entries.push({ type: "definition", text: pos + cleanDef });
                            }
                        }
                    }
                }
            }
            // Schema 2: wiktionary rest_v1
            else if (response && response.en && Array.isArray(response.en)) {
                for (var j = 0; j < response.en.length; j++) {
                    var sec = response.en[j];
                    var pos2 = sec.partOfSpeech ? ("[" + sec.partOfSpeech.toLowerCase() + "] ") : "";
                    var defs2 = sec.definitions || [];
                    for (var k = 0; k < defs2.length; k++) {
                        var cleanDef2 = root.stripHtml(defs2[k].definition);
                        if (cleanDef2.length > 0 && entries.length < root.maxDefinitions) {
                            entries.push({ type: "definition", text: pos2 + cleanDef2 });
                        }
                    }
                }
            }
        } catch (e) {}

        if (entries.length === 0) {
            clearData("No definitions found for '" + root.activeWord + "'.");
            return;
        }

        definitionEntries = entries;
        selectedIndex = 0;
    }

    Process {
        id: dictFetcher
        running: false
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { root.dataAccumulatorBuffer += data; }
        }
        onExited: (code) => {
            if (root.dataAccumulatorBuffer.trim().length > 0) {
                root.parseResponse(root.dataAccumulatorBuffer.trim());
            } else {
                root.clearData("Definition lookup failed (network error).");
            }
            root.dataAccumulatorBuffer = "";
        }
    }

    function fetch(word) {
        const cleanWord = (word || "").trim();
        if (!cleanWord) {
            clearData("Enter a word to define.");
            return;
        }

        root.activeWord = cleanWord;
        root.dataAccumulatorBuffer = "";
        clearData("Searching definition for '" + cleanWord + "'...");

        // Dual pipeline: queries primary REST API, falls back automatically to Wiktionary
        dictFetcher.running = false;
        dictFetcher.command = [
            "sh", "-c",
            'w="$1"; ' +
            'out=$(curl -s -L --connect-timeout 3 --max-time 5 -A "Mozilla/5.0" "https://api.dictionaryapi.dev/api/v2/entries/en/$w" 2>/dev/null); ' +
            'if echo "$out" | grep -q "definition"; then echo "$out"; else ' +
            'curl -s -L --connect-timeout 3 --max-time 5 -A "Quickshell-Dictionary/1.0" "https://en.wiktionary.org/api/rest_v1/page/definition/$w" 2>/dev/null; fi',
            "sh", cleanWord
        ];
        dictFetcher.running = true;
    }
}
