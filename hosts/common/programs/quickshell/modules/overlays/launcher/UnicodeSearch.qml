import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    /*
     * CURRENT SELECTION
     */

    property int selectedIndex: 0

    /*
     * UNICODE DATABASE
     */

    property var unicodeItems: [

        { "symbol": "✓", "name": "check mark tick yes" },
        { "symbol": "✔", "name": "heavy check mark" },
        { "symbol": "✕", "name": "multiplication x cross" },
        { "symbol": "✖", "name": "heavy multiplication x cross" },
        { "symbol": "✗", "name": "ballot x cross" },

        { "symbol": "★", "name": "black star favorite" },
        { "symbol": "☆", "name": "white star favorite" },

        { "symbol": "♥", "name": "heart love" },
        { "symbol": "♡", "name": "white heart outline love" },

        { "symbol": "→", "name": "right arrow" },
        { "symbol": "←", "name": "left arrow" },
        { "symbol": "↑", "name": "up arrow" },
        { "symbol": "↓", "name": "down arrow" },

        { "symbol": "•", "name": "bullet point dot" },
        { "symbol": "●", "name": "black circle dot" },
        { "symbol": "○", "name": "white circle dot" },

        { "symbol": "…", "name": "ellipsis dots" },
        { "symbol": "—", "name": "em dash" },
        { "symbol": "–", "name": "en dash" },

        { "symbol": "⚡", "name": "lightning bolt" },
        { "symbol": "⚠", "name": "warning caution" },
        { "symbol": "☢", "name": "radioactive" },
        { "symbol": "☣", "name": "biohazard" },

        { "symbol": "♬", "name": "music note" },
        { "symbol": "♪", "name": "eighth note music" },

        { "symbol": "∞", "name": "infinity" },
        { "symbol": "≈", "name": "approximately equal" },
        { "symbol": "≠", "name": "not equal" },
        { "symbol": "≤", "name": "less than equal" },
        { "symbol": "≥", "name": "greater than equal" },

        { "symbol": "λ", "name": "lambda greek" },
        { "symbol": "π", "name": "pi greek" },
        { "symbol": "Ω", "name": "omega greek" },

        { "symbol": "ゴ", "name": "jojo menacing katakana go" }
    ]

    /*
     * FILTERED RESULTS
     */

    property var filteredUnicodeItems: unicodeItems

    /*
     * SEARCH
     */

    function refreshFilter(query) {

        const q =
        (query || "")
        .toLowerCase()
        .trim()

        if (q.length === 0) {

            filteredUnicodeItems =
            unicodeItems

            selectedIndex = 0

            return
        }

        filteredUnicodeItems =
        unicodeItems.filter(function(item) {

            return (
                item.name
                .toLowerCase()
                .includes(q)
            ) || (
                item.symbol
                .includes(q)
            )
        })

        selectedIndex = 0
    }

    /*
     * NAVIGATION
     */

    function moveDown() {

        if (
            selectedIndex <
            filteredUnicodeItems.length - 1
        ) {
            selectedIndex++
        }
    }

    function moveUp() {

        if (
            selectedIndex > 0
        ) {
            selectedIndex--
        }
    }

    /*
     * COPY TO CLIPBOARD
     */

    function copySelected() {

        if (
            selectedIndex < 0 ||
            selectedIndex >= filteredUnicodeItems.length
        ) {
            return
        }

        const item =
        filteredUnicodeItems[selectedIndex]

        if (!item) {
            return
        }

        const proc =
        Qt.createQmlObject(`
        import Quickshell.Io

        Process {
            command: [
                "wl-copy",
                "${item.symbol}"
            ]
        }
        `, root)

        proc.running = true

        console.log(
            "COPIED UNICODE:",
            item.symbol
        )
    }
}
