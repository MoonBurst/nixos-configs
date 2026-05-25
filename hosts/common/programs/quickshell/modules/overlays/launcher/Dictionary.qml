import QtQuick

QtObject {
    id: root

    property string currentDefinition: "Enter a word to define."

    readonly property int maxDefinitions: 8
    readonly property int maxSynonyms: 30

    property
    var activeRequest: null

    function fetch(word) {
        const cleanWord =
        (word || "").trim()

        if (!cleanWord) {
            currentDefinition =
            "Enter a word to define."

            return
        }

        currentDefinition =
        "Loading definition for '" +
        cleanWord +
        "'..."

        /*
         * Abort previous request
         */

        if (activeRequest) {
            activeRequest.abort()
            activeRequest = null
        }

        const xhr =
        new XMLHttpRequest()

        activeRequest = xhr

        xhr.onreadystatechange =
        function() {
            if (
                xhr.readyState !==
                XMLHttpRequest.DONE
            ) {
                return
            }

            if (xhr !== activeRequest) {
                return
            }

            activeRequest = null

            if (xhr.status !== 200) {
                root.currentDefinition =
                "No definition found."

                return
            }

            try {
                parseResponse(
                    JSON.parse(
                        xhr.responseText
                    )
                )
            } catch (error) {
                root.currentDefinition =
                "Definition parsing failed."
            }
        }

        xhr.open(
            "GET",
            "https://api.dictionaryapi.dev/api/v2/entries/en/" +
            encodeURIComponent(cleanWord)
        )

        xhr.send()
    }

    function appendUnique(
        array,
        value,
        seen
    ) {
        if (
            !value ||
            seen[value]
        ) {
            return
        }

        seen[value] = true
        array.push(value)
    }

    function parseResponse(response) {
        if (
            !response ||
            response.length === 0
        ) {
            currentDefinition =
            "No definition found."

            return
        }

        /*
         * SPELLCHECK RESPONSE
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

                if (
                    match &&
                    match[1]
                ) {
                    suggestion =
                    "🔎 Did you mean: " +
                    match[1] +
                    "\n\n"
                }
            }

            currentDefinition =
            suggestion +
            "No definition found."

            return
        }

        /*
         * DEFINITIONS + SYNONYMS
         */

        const definitions = []
        const synonyms = []

        // O(1) synonym deduplication
        const synonymSet = ({})

        const meanings =
        response[0].meanings || []

        for (
            let i = 0,
             len = meanings.length; i < len;
             ++i
        ) {
            const meaning =
            meanings[i]

            /*
             * Meaning synonyms
             */

            const meaningSynonyms =
            meaning.synonyms || []

            for (
                let s = 0,
                 slen =
                 meaningSynonyms.length; s < slen;
                 ++s
            ) {
                appendUnique(
                    synonyms,
                    meaningSynonyms[s],
                    synonymSet
                )
            }

            /*
             * Definitions
             */

            const defs =
            meaning.definitions || []

            for (
                let j = 0,
                 dlen = defs.length; j < dlen;
                 ++j
            ) {
                const def =
                defs[j]

                if (
                    def.definition &&
                    definitions.length <
                    maxDefinitions
                ) {
                    definitions.push(
                        "• " +
                        def.definition
                    )
                }

                /*
                 * Definition synonyms
                 */

                const defSynonyms =
                def.synonyms || []

                for (
                    let k = 0,
                     klen =
                     defSynonyms.length; k < klen;
                     ++k
                ) {
                    appendUnique(
                        synonyms,
                        defSynonyms[k],
                        synonymSet
                    )
                }
            }
        }

        /*
         * FORMAT OUTPUT
         */

        const sections = []

        if (definitions.length) {
            sections.push(
                "DEFINITIONS\n" +
                "────────────\n\n" +
                definitions.join(
                    "\n\n"
                )
            )
        }

        if (synonyms.length) {
            sections.push(
                "THESAURUS\n" +
                "──────────\n\n" +
                synonyms
                .slice(
                    0,
                    maxSynonyms
                )
                .join(", ")
            )
        }

        currentDefinition =
        sections.length ?
        sections.join("\n\n\n") :
        "No definition found."
    }
}
