import QtQuick

QtObject {
    id: engine

    property string searchUrlBase: "https://www.startpage.com/sp/search?query="

    function search(query) {
        const trimmed = (query || "").trim();
        if (trimmed.length === 0) return;
        Qt.openUrlExternally(searchUrlBase + encodeURIComponent(trimmed));
    }
}
