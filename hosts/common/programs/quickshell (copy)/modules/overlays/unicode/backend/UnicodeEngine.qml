import QtQuick
import Quickshell
import "../../../common/Utils.js" as Utils

QtObject {
    id: engine

    property int selectedIndex: 0
    property string query: ""

    readonly property var unicodeItems: [
        { symbol: "✓", name: "check mark tick yes" },
        { symbol: "✔", name: "heavy check mark" },
        { symbol: "✕", name: "multiplication x cross cancel" },
        { symbol: "★", name: "black star favorite" },
        { symbol: "☆", name: "white star favorite outline" },
        { symbol: "♥", name: "heart love favorite" },
        { symbol: "→", name: "right arrow next" },
        { symbol: "←", name: "left arrow previous back" },
        { symbol: "↑", name: "up arrow top" },
        { symbol: "↓", name: "down arrow bottom" },
        { symbol: "•", name: "bullet point dot" },
        { symbol: "…", name: "ellipsis dots more" },
        { symbol: "⚡", name: "lightning bolt power electric fast" },
        { symbol: "⚠", name: "warning caution alert danger" },
        { symbol: "♬", name: "music note audio sound" },
        { symbol: "∞", name: "infinity infinite endless" },
        { symbol: "≈", name: "approximately equal math" },
        { symbol: "≠", name: "not equal math" },
        { symbol: "λ", name: "lambda greek half-life" },
        { symbol: "π", name: "pi greek math 3.14" }
    ]

    property var filteredItems: unicodeItems

    onQueryChanged: refreshFilter(query)

    function refreshFilter(qText) {
        const q = (qText || "").toLowerCase().trim();
        if (!q) {
            filteredItems = unicodeItems;
            selectedIndex = 0;
            return;
        }
        filteredItems = unicodeItems.filter(function(item) {
            return item.symbol.includes(q) || item.name.includes(q) || Utils.fuzzyMatch(q, item.name);
        });
        selectedIndex = 0;
    }

    function copySelected() {
        if (selectedIndex >= 0 && selectedIndex < filteredItems.length) {
            const sym = filteredItems[selectedIndex].symbol;
            Quickshell.clipboardText = sym;
            Quickshell.execDetached(["notify-send", "-a", "Unicode", "🔣 Copied Glyph", sym]);
            return true;
        }
        return false;
    }
}
