import QtQuick
import Quickshell

QtObject {
    id: root

    /*
     * STATE
     */

    property int selectedIndex: 0

    property var definitionEntries: []

    property var activeRequest: null

    readonly property int maxDefinitions: 8
    readonly property int maxSynonyms: 30

    /*
     * NAVIGATION
     */

    function selectNext() {
        if (definitionEntries.length === 0)
            return

            selectedIndex =
            (selectedIndex + 1) %
            definitionEntries.length
    }

    function selectPrev() {
        if (definitionEntries.length === 0)
            return

            selectedIndex =
            (selectedIndex - 1 + definitionEntries.length) %
            definitionEntries.length
    }

    /*
     * COPY
     */

    function copySelected() {
        if (
            selectedIndex < 0 ||
            selectedIndex >= definitionEntries.length
        ) {
            return
        }

        try {
            Quickshell.clipboardText =
            definitionEntries[selectedIndex].text
        } catch (e) {
            console.log("Clipboard copy failed:", e)
        }
    }

    /*
     * FETCH
     */

    function fetch(word) {
        const cleanWord =
        (word || "").trim()

        if (!cleanWord) {
            clearData("Enter a word to define.")
            return
        }

        clearData(
            "Loading definition for '" +
            cleanWord +
            "'..."
        )

        if (activeRequest) {
            activeRequest.abort()
            activeRequest = null
        }

        const xhr = new XMLHttpRequest()

        activeRequest = xhr

        xhr.onreadystatechange = function() {
            if (
                xhr.readyState !== XMLHttpRequest.DONE
            ) {
                return
            }

            if (xhr !== activeRequest)
                return

                activeRequest = null

                if (xhr.status !== 200) {
                    clearData("No definition found.")
                    return
                }

                try {
                    parseResponse(
                        JSON.parse(xhr.responseText)
                    )
                } catch(error) {
                    clearData(
                        "Definition parsing failed."
                    )
                }
        }

        xhr.open(
            "GET",
            "https://api.dictionaryapi.dev/api/v2/entries/en/" +
            encodeURIComponent(cleanWord)
        )

        xhr.send()
    }

    /*
     * CLEAR
     */

    function clearData(message) {
        selectedIndex = 0

        definitionEntries = [{
            type: "status",
            text: message
        }]
    }

    /*
     * DUPLICATE FILTER
     */

    function appendUnique(
        array,
        value,
        seen
    ) {
        if (!value || seen[value])
            return

            seen[value] = true

            array.push(value)
    }

    /*
     * PARSER
     */

    function parseResponse(response) {
        if (!response || response.length === 0) {
            clearData("No definition found.")
            return
        }

        /*
         * SPELLCHECK
         */

        if (
            response.title &&
            response.message
        ) {
            let suggestion = ""

            if (response.resolution) {
                const match =
                response.resolution.match(
                    /`([^`]+)`/
                )

                if (match && match[1]) {
                    suggestion =
                    "Did you mean: " +
                    match[1]
                }
            }

            clearData(
                suggestion || "No definition found."
            )

            return
        }

        const entries = []

        const synonymSet = ({})

        const collectedSynonyms = []

        const meanings =
        response[0].meanings || []

        /*
         * DEFINITIONS
         */

        for (
            let i = 0;
        i < meanings.length;
        ++i
        ) {
            const meaning = meanings[i]

            const defs =
            meaning.definitions || []

            for (
                let j = 0;
            j < defs.length;
            ++j
            ) {
                const def = defs[j]

                if (
                    def.definition &&
                    entries.length <
                    maxDefinitions
                ) {
                    entries.push({
                        type: "definition",
                        text: def.definition
                    })
                }

                const defSynonyms =
                def.synonyms || []

                for (
                    let k = 0;
                k < defSynonyms.length;
                ++k
                ) {
                    appendUnique(
                        collectedSynonyms,
                        defSynonyms[k],
                        synonymSet
                    )
                }
            }
        }

        /*
         * SYNONYMS
         */

        if (collectedSynonyms.length > 0) {
            entries.push({
                type: "synonyms",
                text:
                "Synonyms:\n\n" +
                collectedSynonyms
                .slice(0, maxSynonyms)
                .join(", ")
            })
        }

        /*
         * FALLBACK
         */

        if (entries.length === 0) {
            entries.push({
                type: "status",
                text: "No definition found."
            })
        }

        definitionEntries = entries

        selectedIndex = 0
    }
}
