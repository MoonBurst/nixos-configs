import QtQuick

Item {
    id: root

    property string currentDefinition: ""

    function fetch(word) {
        const cleanWord = (word || "").trim()

        if (cleanWord.length === 0) {
            currentDefinition =
            "Enter a word to define."
            return
        }

        currentDefinition =
        "Loading definition for '" +
        cleanWord +
        "'..."

        const xhr = new XMLHttpRequest()

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return
            }

            if (xhr.status !== 200) {
                root.currentDefinition =
                "No definition found."
                return
            }

            try {
                const response =
                JSON.parse(xhr.responseText)

                if (
                    !response ||
                    response.length === 0
                ) {
                    root.currentDefinition =
                    "No definition found."
                    return
                }

                /*
                 * SPELLCHECK
                 */

                let suggestionText = ""

                if (
                    response.title &&
                    response.message
                ) {
                    if (response.resolution) {
                        const match =
                        response.resolution.match(
                            /`([^`]+)`/
                        )

                        if (match && match[1]) {
                            suggestionText =
                            "🔎 Did you mean: " +
                            match[1] +
                            "\n\n"
                        }
                    }

                    root.currentDefinition =
                    suggestionText +
                    "No definition found."

                    return
                }

                /*
                 * DEFINITIONS
                 */

                let definitions = []
                let synonyms = []

                for (
                    let i = 0;
                i < response[0].meanings.length;
                ++i
                ) {
                    const meaning =
                    response[0].meanings[i]

                    /*
                     * synonyms from meanings
                     */

                    if (meaning.synonyms) {
                        for (
                            let s = 0;
                        s < meaning.synonyms.length;
                        ++s
                        ) {
                            const synonym =
                            meaning.synonyms[s]

                            if (
                                synonym &&
                                synonyms.indexOf(
                                    synonym
                                ) === -1
                            ) {
                                synonyms.push(synonym)
                            }
                        }
                    }

                    /*
                     * definitions
                     */

                    if (!meaning.definitions) {
                        continue
                    }

                    for (
                        let j = 0;
                    j < meaning.definitions.length;
                    ++j
                    ) {
                        const def =
                        meaning.definitions[j]

                        if (
                            def.definition &&
                            definitions.length < 8
                        ) {
                            definitions.push(
                                "• " +
                                def.definition
                            )
                        }

                        /*
                         * synonyms from defs
                         */

                        if (def.synonyms) {
                            for (
                                let k = 0;
                            k < def.synonyms.length;
                            ++k
                            ) {
                                const synonym =
                                def.synonyms[k]

                                if (
                                    synonym &&
                                    synonyms.indexOf(
                                        synonym
                                    ) === -1
                                ) {
                                    synonyms.push(
                                        synonym
                                    )
                                }
                            }
                        }
                    }
                }

                /*
                 * FORMAT OUTPUT
                 */

                let output = ""

                if (definitions.length > 0) {
                    output +=
                    "DEFINITIONS\n" +
                    "────────────\n\n"

                    output +=
                    definitions.join(
                        "\n\n"
                    )
                }

                if (synonyms.length > 0) {
                    output +=
                    "\n\n\nTHESAURUS\n" +
                    "──────────\n\n"

                    output +=
                    synonyms
                    .slice(0, 30)
                    .join(", ")
                }

                if (
                    output.trim().length === 0
                ) {
                    output =
                    "No definition found."
                }

                root.currentDefinition =
                output

            } catch(error) {
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
}
