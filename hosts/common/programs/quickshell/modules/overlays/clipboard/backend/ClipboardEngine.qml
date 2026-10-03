import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: engine

    property string currentQuery: ""
    property int selectedIndex: 0
    property string previewImage: ""
    property string previewText: ""
    property bool hasCliphist: true

    property var allClipboardItems: []
    property var filteredClipboardModel: ListModel { id: fModel }

    Component.onCompleted: loadClipboard()

    property string _jsonBuffer: ""
    Process {
        id: clipboardLoader
        running: false
        command: [
            "sh", "-c",
            'SCR="' + Quickshell.shellDir + '/modules/overlays/clipboard/backend/ClipboardEngine.lua"; ' +
            'CMD="lua"; command -v luajit >/dev/null 2>&1 && CMD="luajit"; ' +
            '"$CMD" "$SCR"'
        ]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { engine._jsonBuffer += data; }
        }
        onStarted: { engine._jsonBuffer = ""; }
        onExited: {
            try {
                var parsed = JSON.parse(engine._jsonBuffer.trim());
                if (Array.isArray(parsed)) engine.allClipboardItems = parsed;
            } catch(e) {
                engine.allClipboardItems = [];
            }
            engine._jsonBuffer = "";
            engine.refreshFilter(engine.currentQuery);
        }
    }

    // Zero-polling Inotify filesystem listener
    Process {
        id: clipboardWatcher
        running: true
        command: [
            "sh", "-c",
            'touch /tmp/native_clipboard_history.txt; ' +
            'if command -v inotifywait >/dev/null 2>&1; then ' +
            '  inotifywait -m -q -e close_write,modify /tmp/native_clipboard_history.txt 2>/dev/null; ' +
            'else ' +
            '  while sleep 3; do echo 1; done; ' +
            'fi'
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => engine.loadClipboard()
        }
    }

    Process { id: copyProcess; running: false }
    Process { id: deleteProc; running: false }

    Process {
        id: wipeProcess
        running: false
        command: ["sh", "-c", "rm -f /tmp/native_clipboard_history.txt; touch /tmp/native_clipboard_history.txt; rm -rf $HOME/.cache/quickshot_history/*"]
    }

    function loadClipboard() {
        clipboardLoader.running = false;
        clipboardLoader.running = true;
    }

    function refreshFilter(query) {
        currentQuery = query || "";
        let q = currentQuery.toLowerCase().trim();
        const imageMode = q.startsWith("image:");
        if (imageMode) q = q.substring(6).trim();

        fModel.clear();
        const showAll = q.length === 0;
        let added = 0;
        const maxDisplay = showAll ? 100 : 200;

        for (let i = 0, c = allClipboardItems.length; i < c; ++i) {
            const item = allClipboardItems[i];
            if (imageMode && !item.isImage) continue;
            if (showAll || item.searchText.includes(q) || (item.isImage && (q === "image" || item.text.toLowerCase().includes(q)))) {
                fModel.append(item);
                added++;
                if (added >= maxDisplay) break;
            }
        }
        if (selectedIndex >= fModel.count) selectedIndex = Math.max(0, fModel.count - 1);
        updatePreview();
    }

    function updatePreview() {
        if (selectedIndex < 0 || selectedIndex >= fModel.count) {
            previewImage = ""; previewText = ""; return;
        }
        const item = fModel.get(selectedIndex);
        if (item.isImage && item.imagePath) {
            previewImage = "file://" + item.imagePath;
            previewText = "";
        } else {
            previewImage = "";
            previewText = item.fullRawText || item.text || "";
        }
    }

    function copySelected() {
        if (selectedIndex < 0 || selectedIndex >= fModel.count) return;
        var item = fModel.get(selectedIndex);
        if (!item) return;

        copyProcess.running = false;
        if (item.isImage && item.imagePath) {
            copyProcess.command = ["sh", "-c", "wl-copy --type image/png < '" + item.imagePath.replace(/'/g, "'\\''") + "'"];
        } else {
            copyProcess.command = ["wl-copy", item.fullRawText || item.text];
        }
        copyProcess.running = true;
    }

    function deleteSelected() {
        if (selectedIndex < 0 || selectedIndex >= fModel.count) return;
        const item = fModel.get(selectedIndex);
        if (!item) return;

        const isImage = Boolean(item.isImage);
        const imagePath = String(item.imagePath || "");
        const cleanText = String(item.fullRawText || item.text || "");

        for (let i = 0; i < allClipboardItems.length; i++) {
            var comp = allClipboardItems[i].fullRawText || allClipboardItems[i].text || "";
            if (comp === cleanText) {
                allClipboardItems.splice(i, 1); break;
            }
        }
        fModel.remove(selectedIndex);
        if (selectedIndex >= fModel.count) selectedIndex = Math.max(0, fModel.count - 1);
        updatePreview();

        if (isImage && imagePath.length > 0) {
            var jsonPath = imagePath.replace(/\.png$/, ".json");
            deleteProc.command = ["sh", "-c", "rm -vf '" + imagePath + "' '" + jsonPath + "'"];
            deleteProc.running = true;
        } else {
            deleteProc.command = [
                "sh", "-c",
                'SCR="' + Quickshell.shellDir + '/modules/overlays/clipboard/backend/ClipboardEngine.lua"; ' +
                'if command -v luajit >/dev/null 2>&1; then luajit "$SCR" --delete "$1"; else lua "$SCR" --delete "$1"; fi',
                "sh", cleanText
            ];
            deleteProc.running = true;
        }
    }

    function wipeHistory() {
        wipeProcess.running = false;
        wipeProcess.running = true;
        allClipboardItems = [];
        fModel.clear();
        selectedIndex = 0;
        updatePreview();
    }
}
