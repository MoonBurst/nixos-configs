import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string currentQuery: ""
    property string pendingQuery: ""
    property int selectedIndex: 0
    property string previewImage: ""
    property string previewText: ""
    property string lastSeenTopId: ""

    property var allClipboardItems: []
    property alias filteredClipboardItems: filteredClipboardModel
    signal clipboardCopied(string id)

    ListModel {
        id: filteredClipboardModel
    }

    Timer {
        id: filterTimer
        interval: 40
        repeat: false
        onTriggered: refreshFilter(pendingQuery)
    }

    Timer {
        id: changePoller
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!deleteProc.running && !pollCheckWorker.running && !clipboardLoader.running) {
                pollCheckWorker.running = true;
            }
        }
    }

    function handleDeleteKeyPress() {
        deleteSelected();
    }

    function queueFilter(query) {
        pendingQuery = query || "";
        filterTimer.restart();
    }

    function loadClipboard() {
        if (clipboardLoader.running) return;
        clipboardLoader.running = true;
    }

    function refreshFilter(query) {
        currentQuery = query || "";
        let q = currentQuery.toLowerCase().trim();
        const imageMode = q.startsWith("image:");

        if (imageMode) {
            q = q.substring(6).trim();
        }

        filteredClipboardModel.clear();
        const showAll = q.length === 0;

        for (let i = 0, c = allClipboardItems.length; i < c; ++i) {
            const item = allClipboardItems[i];

            if (imageMode && !item.isImage) continue;

            if (showAll || item.searchText.includes(q) || (item.isImage && (q === "image" || item.text.toLowerCase().includes(q)))) {
                filteredClipboardModel.append(item);
            }
        }

        if (selectedIndex >= filteredClipboardModel.count) {
            selectedIndex = Math.max(0, filteredClipboardModel.count - 1);
        }
        updatePreview();
    }

    function loadPreviewText() {
        if (selectedIndex < 0 || selectedIndex >= filteredClipboardModel.count) {
            previewText = "";
            return;
        }

        const item = filteredClipboardModel.get(selectedIndex);
        if (item.isImage) {
            previewText = "";
            return;
        }

        previewLoader.running = false;
        previewLoader.command = ["sh", "-c", "cliphist decode " + item.id];
        previewLoader.running = true;
    }

    function updatePreview() {
        if (selectedIndex < 0 || selectedIndex >= filteredClipboardModel.count) {
            previewImage = "";
            previewText = "";
            return;
        }

        const item = filteredClipboardModel.get(selectedIndex);
        if (item.isImage && item.imagePath) {
            previewImage = "file://" + item.imagePath;
            previewText = "";
        } else {
            previewImage = "";
            loadPreviewText();
        }
    }

    function moveUp() {
        if (selectedIndex > 0) {
            --selectedIndex;
            updatePreview();
        }
    }

    function moveDown() {
        if (selectedIndex < filteredClipboardModel.count - 1) {
            ++selectedIndex;
            updatePreview();
        }
    }

    function copySelected() {
        if (selectedIndex < 0 || selectedIndex >= filteredClipboardModel.count) return;
        copyItem(filteredClipboardModel.get(selectedIndex));
    }

    function copyItem(item) {
        if (!item) return;

        copyProcess.running = false;
        if (item.isImage && item.imagePath) {
            copyProcess.command = ["sh", "-c", "wl-copy --type image/png < '" + item.imagePath.replace(/'/g, "'\\''") + "'"];
        } else {
            copyProcess.command = ["sh", "-c", "cliphist decode " + item.id + " | wl-copy"];
        }
        copyProcess.running = true;
        root.clipboardCopied("done");
    }

    function deleteSelected() {
        deleteItemAt(selectedIndex);
    }

    function deleteItemAt(idx) {
        if (idx < 0 || idx >= filteredClipboardModel.count) return;
        const item = filteredClipboardModel.get(idx);
        if (!item) return;

        // CRITICAL FIX: Extract primitive values BEFORE removing from model!
        const isImage = Boolean(item.isImage);
        const imagePath = String(item.imagePath || "");
        const cleanId = String(item.id || "").trim();

        // 1. Remove from memory storage array
        for (let i = 0; i < allClipboardItems.length; i++) {
            if (String(allClipboardItems[i].id).trim() === cleanId) {
                allClipboardItems.splice(i, 1);
                break;
            }
        }

        // 2. Remove visually from the UI list
        filteredClipboardModel.remove(idx);
        if (selectedIndex >= filteredClipboardModel.count) {
            selectedIndex = Math.max(0, filteredClipboardModel.count - 1);
        }
        updatePreview();

        // 3. Execute permanent disk deletion using the preserved variables
        if (isImage && imagePath.length > 0) {
            var jsonPath = imagePath.replace(/\.png$/, ".json");
            deleteProc.running = false;
            deleteProc.command = [
                "sh", "-c",
                "echo '=== [IMAGE DELETE] ===' >> /tmp/clipboard_debug.log; " +
                "rm -vf '" + imagePath + "' '" + jsonPath + "' >> /tmp/clipboard_debug.log 2>&1"
            ];
            deleteProc.running = true;
        } else if (cleanId.length > 0) {
            deleteProc.running = false;
            deleteProc.command = [
                "sh", "-c",
                "echo '=== [TEXT DELETE ID: " + cleanId + "] ===' >> /tmp/clipboard_debug.log; " +
                "printf '%s\\t-\\n' '" + cleanId + "' | cliphist delete >> /tmp/clipboard_debug.log 2>&1; " +
                "if [ -d /tmp/cliphist_db ]; then printf '%s\\t-\\n' '" + cleanId + "' | CLIPHIST_DB_PATH=/tmp/cliphist_db cliphist delete >> /tmp/clipboard_debug.log 2>&1; fi"
            ];
            deleteProc.running = true;
        }
    }

    function wipeHistory() {
        allClipboardItems = [];
        filteredClipboardModel.clear();
        selectedIndex = 0;
        updatePreview();
        wipeProcess.running = false;
        wipeProcess.running = true;
    }

    Process { id: deleteProc }
    Process { id: copyProcess }
    Process { 
        id: wipeProcess 
        command: ["sh", "-c", "cliphist wipe; if [ -d /tmp/cliphist_db ]; then CLIPHIST_DB_PATH=/tmp/cliphist_db cliphist wipe; fi; rm -rf $HOME/.cache/quickshot_history/*"]
    }

    // Top-item change watcher
    Process {
        id: pollCheckWorker
        command: [
            "sh",
            "-c",
            "printf '%s::%s\n' \"$(cliphist list | head -n 1 | cut -f1)\" \"$(ls -1t $HOME/.cache/quickshot_history/*.json 2>/dev/null | head -n 1)\""
        ]
        stdout: SplitParser {
            onRead: data => {
                const cleanId = data.trim();
                if (cleanId && cleanId !== root.lastSeenTopId) {
                    root.lastSeenTopId = cleanId;
                    loadClipboard();
                }
            }
        }
    }

    property var _tempLoadingBuffer: []

    Process {
        id: clipboardLoader
        command: [
            "sh",
            "-c",
            "HIST=\"$HOME/.cache/quickshot_history\"; " +
            "if [ -d \"$HIST\" ]; then " +
            "  for meta in $(ls -1t \"$HIST\"/*.json 2>/dev/null | head -n 60); do " +
            "    img=\"${meta%.json}.png\"; " +
            "    if [ -f \"$img\" ]; then " +
            "      name=$(grep -o '\"name\":\"[^\"]*\"' \"$meta\" | cut -d'\"' -f4); " +
            "      printf \"QS_IMG\\t%s\\t%s\\n\" \"$name\" \"$img\"; " +
            "    fi; " +
            "  done; " +
            "fi; " +
            "cliphist list | head -n 200 | while IFS=$'\\t' read -r id text; do " +
            "  if [[ \"$text\" != *\"binary data\"* && \"$text\" != *\"[Image\"* ]]; then " +
            "    printf \"CLIP\\t%s\\t%s\\n\" \"$id\" \"$text\"; " +
            "  fi; " +
            "done"
        ]

        onStarted: {
            root._tempLoadingBuffer = [];
        }

        stdout: SplitParser {
            onRead: data => {
                const lines = data.split("\n");
                for (let i = 0, c = lines.length; i < c; ++i) {
                    const line = lines[i].trim();
                    if (!line) continue;

                    const parts = line.split("\t");
                    if (parts.length < 3) continue;

                    const type = parts[0];
                    const col1 = parts[1].trim(); // Clean numeric ID
                    const col2 = parts[2];

                    if (type === "QS_IMG") {
                        root._tempLoadingBuffer.push({
                            id: col2,
                            text: "[Image: " + col1 + "]",
                            searchText: col1.toLowerCase(),
                            isImage: true,
                            imagePath: col2
                        });
                    } else if (type === "CLIP") {
                        root._tempLoadingBuffer.push({
                            id: col1,
                            text: col2,
                            searchText: col2.toLowerCase(),
                            isImage: false,
                            imagePath: ""
                        });
                    }
                }
            }
        }

        onExited: {
            root.allClipboardItems = root._tempLoadingBuffer;
            root.refreshFilter(root.currentQuery);
        }
    }

    Process {
        id: previewLoader
        stdout: SplitParser {
            onRead: data => { root.previewText += data; }
        }
        onStarted: { root.previewText = ""; }
    }

    Component.onCompleted: loadClipboard()
}
