import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int selectedIndex: 0
    property var definitionEntries: []
    readonly property int maxDefinitions: 8
    property string activeWord: ""

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
        } catch (e) {
            console.log("Clipboard copy failed:", e);
        }
    }

    function clearData(message) {
        selectedIndex = 0;
        definitionEntries = [{
            type: "status",
            text: message
        }];
    }

    function stripHtml(htmlStr) {
        if (!htmlStr) return "";
        return htmlStr.replace(/<[^>]*>/g, "").replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&#39;/g, "'").trim();
    }

    function parseResponse(response) {
        if (!response || !response.en || !Array.isArray(response.en) || response.en.length === 0) {
            clearData("No definitions found for '" + root.activeWord + "'.");
            return;
        }

        var entries = [];
        var sections = response.en;

        for (var i = 0; i < sections.length; i++) {
            var sec = sections[i];
            var pos = sec.partOfSpeech ? ("[" + sec.partOfSpeech.toLowerCase() + "] ") : "";
            var defs = sec.definitions || [];

            for (var j = 0; j < defs.length; j++) {
                var cleanDef = root.stripHtml(defs[j].definition);
                if (cleanDef.length > 0 && entries.length < root.maxDefinitions) {
                    entries.push({
                        type: "definition",
                        text: pos + cleanDef
                    });
                }
            }
        }

        if (entries.length === 0) {
            clearData("No definition entries found for '" + root.activeWord + "'.");
            return;
        }

        definitionEntries = entries;
        selectedIndex = 0;
    }

    Process {
        id: dictFetcher
        running: false
        onExited: (code) => {
            if (code !== 0) {
                root.clearData("Request timed out or network error (code " + code + ").");
                return;
            }

            var xhr = new XMLHttpRequest();
            var cacheBuster = "?t=" + Date.now();
            xhr.open("GET", "file:///tmp/qs_dict.json" + cacheBuster);
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200 || xhr.status === 0) {
                        try {
                            var parsed = JSON.parse(xhr.responseText);
                            root.parseResponse(parsed);
                        } catch(e) {
                            root.clearData("No definitions found for '" + root.activeWord + "'.");
                        }
                    } else {
                        root.clearData("Failed to read definition cache.");
                    }
                }
            };
            xhr.send();
        }
    }

    function fetch(word) {
        const cleanWord = (word || "").trim();

        if (!cleanWord) {
            clearData("Enter a word to define.");
            return;
        }

        root.activeWord = cleanWord;
        clearData("Searching Wiktionary for '" + cleanWord + "'...");

        dictFetcher.running = false;
        dictFetcher.command = [
            "curl",
            "-s",
            "-L",
            "--connect-timeout", "3",
            "--max-time", "5",
            "-A", "Quickshell-Dictionary/1.0",
            "https://en.wiktionary.org/api/rest_v1/page/definition/" + encodeURIComponent(cleanWord),
            "-o",
            "/tmp/qs_dict.json"
        ];
        dictFetcher.running = true;
    }
}
