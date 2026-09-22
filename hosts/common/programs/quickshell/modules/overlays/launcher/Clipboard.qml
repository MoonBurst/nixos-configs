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
    property var deleteQueue: []

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
            if (deleteQueue.length === 0 && !deleteProcess.running && !pollCheckWorker.running && !clipboardLoader.running) {
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
        allClipboardItems = [];
        filteredClipboardModel.clear();
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

        selectedIndex = 0;
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

        if (item.isImage && item.imagePath) {
            copyProcess.command = ["sh", "-c", "wl-copy --type image/png < '" + item.imagePath.replace(/'/g, "'\\''") + "'"];
        } else {
            copyProcess.command = ["sh", "-c", "cliphist decode " + item.id + " | wl-copy"];
        }
        copyProcess.running = true;
    }

    function deleteSelected() {
        if (selectedIndex < 0 || selectedIndex >= filteredClipboardModel.count) return;

        const item = filteredClipboardModel.get(selectedIndex);
        if (!item) return;

        const targetId = item.id;
        let allIdx = -1;
        for (let i = 0; i < allClipboardItems.length; i++) {
            if (allClipboardItems[i].id === targetId) {
                allIdx = i;
                break;
            }
        }
        if (allIdx !== -1) allClipboardItems.splice(allIdx, 1);

        filteredClipboardModel.remove(selectedIndex);
        if (selectedIndex >= filteredClipboardModel.count) {
            selectedIndex = Math.max(0, filteredClipboardModel.count - 1);
        }
        updatePreview();

        if (item.isImage && item.imagePath) {
            deleteProcess.command = ["sh", "-c", "rm -f '" + item.imagePath + "' '${item.imagePath%.png}.json'"];
            deleteProcess.running = true;
        } else if (item.rawLineText) {
            deleteQueue.push(item.rawLineText);
            processDeleteQueue();
        }
    }

    function processDeleteQueue() {
        if (deleteQueue.length === 0 || deleteProcess.running) return;
        const nextRawText = deleteQueue.shift();
        deleteProcess.command = ["sh", "-c", "printf '%s\\n' '" + nextRawText.replace(/'/g, "'\\\\''") + "' | cliphist delete"];
        deleteProcess.running = true;
    }

    function wipeHistory() {
        allClipboardItems = [];
        filteredClipboardModel.clear();
        selectedIndex = 0;
        updatePreview();
        wipeProcess.running = true;
    }

    // Atomic Single-Line Change Watcher (Eliminates the 2-second refresh loop)
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

        stdout: SplitParser {
            onRead: data => {
                const lines = data.split("\n");
                for (let i = 0, c = lines.length; i < c; ++i) {
                    const line = lines[i].trim();
                    if (!line) continue;

                    const parts = line.split("\t");
                    if (parts.length < 3) continue;

                    const type = parts[0];
                    const col1 = parts[1];
                    const col2 = parts[2];

                    if (type === "QS_IMG") {
                        allClipboardItems.push({
                            id: col2,
                            text: "[Image: " + col1 + "]",
                            searchText: col1.toLowerCase(),
                            isImage: true,
                            imagePath: col2,
                            rawLineText: ""
                        });
                    } else if (type === "CLIP") {
                        allClipboardItems.push({
                            id: col1,
                            text: col2,
                            searchText: col2.toLowerCase(),
                            isImage: false,
                            imagePath: "",
                            rawLineText: line
                        });
                    }
                }
            }
        }

        onExited: refreshFilter(currentQuery)
    }

    Process {
        id: previewLoader
        stdout: SplitParser {
            onRead: data => { root.previewText += data; }
        }
        onStarted: { root.previewText = ""; }
    }

    Process {
        id: copyProcess
        onExited: { root.clipboardCopied("done"); }
    }

    Process {
        id: deleteProcess
        onExited: { processDeleteQueue(); }
    }

    Process {
        id: wipeProcess
        running: false
        command: ["sh", "-c", "cliphist wipe; rm -rf $HOME/.cache/quickshot_history/*"]
    }

    Component.onCompleted: loadClipboard()
}
