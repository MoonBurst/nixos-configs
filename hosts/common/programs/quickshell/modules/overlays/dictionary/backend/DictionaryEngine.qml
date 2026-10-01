import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: engine

    property int selectedIndex: 0
    property var definitionEntries: []
    property string activeWord: ""

    function clearData(message) {
        selectedIndex = 0;
        definitionEntries = [{ type: "status", text: message }];
    }

    function stripHtml(htmlStr) {
        if (!htmlStr) return "";
        return htmlStr.replace(/<[^>]*>/g, "").replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&#39;/g, "'").trim();
    }

    function parseResponse(dataStr) {
        var entries = [];
        try {
            var response = JSON.parse(dataStr);
            if (Array.isArray(response) && response.length > 0 && response[0].meanings) {
                for (var i = 0; i < response.length; i++) {
                    var meanings = response[i].meanings || [];
                    for (var m = 0; m < meanings.length; m++) {
                        var pos = meanings[m].partOfSpeech ? ("[" + meanings[m].partOfSpeech.toLowerCase() + "] ") : "";
                        var defs = meanings[m].definitions || [];
                        for (var d = 0; d < defs.length; d++) {
                            var cleanDef = stripHtml(defs[d].definition);
                            if (cleanDef.length > 0 && entries.length < 10) {
                                entries.push({ type: "definition", text: pos + cleanDef });
                            }
                        }
                    }
                }
            } else if (response && response.en && Array.isArray(response.en)) {
                for (var j = 0; j < response.en.length; j++) {
                    var sec = response.en[j];
                    var pos2 = sec.partOfSpeech ? ("[" + sec.partOfSpeech.toLowerCase() + "] ") : "";
                    var defs2 = sec.definitions || [];
                    for (var k = 0; k < defs2.length; k++) {
                        var cleanDef2 = stripHtml(defs2[k].definition);
                        if (cleanDef2.length > 0 && entries.length < 10) {
                            entries.push({ type: "definition", text: pos2 + cleanDef2 });
                        }
                    }
                }
            }
        } catch (e) {}

        if (entries.length === 0) {
            clearData("No definitions found for '" + activeWord + "'.");
            return;
        }
        definitionEntries = entries;
        selectedIndex = 0;
    }

    readonly property Process dictFetcher: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var clean = text.trim();
                if (clean.length > 0) engine.parseResponse(clean);
                else engine.clearData("Definition lookup failed.");
            }
        }
    }

    function fetch(word) {
        const cleanWord = (word || "").toLowerCase().trim();
        if (!cleanWord) { clearData("Enter a word to define."); return; }
        activeWord = cleanWord;
        clearData("Searching definition for '" + cleanWord + "'...");

        dictFetcher.running = false;
        dictFetcher.command = [
            "sh", "-c",
            'w="$1"; ' +
            'out=$(curl -s -L --connect-timeout 4 --max-time 6 -A "Mozilla/5.0" "https://api.dictionaryapi.dev/api/v2/entries/en/$w" 2>/dev/null); ' +
            'if echo "$out" | grep -q "definition"; then echo "$out"; else ' +
            'curl -s -L --connect-timeout 4 --max-time 6 -A "Quickshell-Dict/1.0" "https://en.wiktionary.org/api/rest_v1/page/definition/$w" 2>/dev/null; ' +
            'fi',
            "sh", cleanWord
        ];
        dictFetcher.running = true;
    }

    function copySelected() {
        if (selectedIndex >= 0 && selectedIndex < definitionEntries.length) {
            var def = definitionEntries[selectedIndex].text;
            Quickshell.clipboardText = def;
            Quickshell.execDetached(["notify-send", "-a", "Dictionary", "-i", "accessories-dictionary", "📖 Definition Copied", def]);
            return true;
        }
        return false;
    }
}
