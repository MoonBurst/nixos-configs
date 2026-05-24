import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string currentQuery: ""
    property int selectedIndex: 0
    property string previewImage: ""

    property alias clipboardItems: clipboardModel
    property alias filteredClipboardItems: filteredClipboardModel

    signal clipboardCopied(string id)

    ListModel { id: clipboardModel }
    ListModel { id: filteredClipboardModel }

    function handleDeleteKeyPress() {
        deleteSelected();
    }

    Timer {
        id: reloadDelayTimer
        interval: 50
        repeat: false
        onTriggered: {
            root.loadClipboard();
        }
    }

    property string lastSeenTopId: ""

    Timer {
        id: changePoller
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            pollCheckWorker.running = true
        }
    }

    Process {
        id: pollCheckWorker
        command: ["sh", "-c", "cliphist list | head -n 1 | cut -d' ' -f1"]
        stdout: SplitParser {
            onRead: (id) => {
                let cleanId = id.trim();
                if (cleanId.length > 0 && cleanId !== root.lastSeenTopId) {
                    root.lastSeenTopId = cleanId;
                    root.loadClipboard();
                }
            }
        }
    }

    function loadClipboard() {
        clipboardModel.clear()
        filteredClipboardModel.clear()
        clipboardLoader.running = true
    }

    function refreshFilter(query) {
        currentQuery = query || ""
        let q = currentQuery.toLowerCase().trim()
        let imageMode = false

        if (q.startsWith("image:")) {
            imageMode = true
            q = q.substring(6).trim()
        }

        filteredClipboardModel.clear()

        for (let i = 0; i < clipboardModel.count; ++i) {
            const item = clipboardModel.get(i)
            const text = (item.text || "").toLowerCase()

            if (imageMode && !item.isImage) continue;

            if (q.length === 0 || text.includes(q) || (item.isImage && q === "image")) {
                filteredClipboardModel.append({
                    id: item.id,
                    text: item.text,
                    isImage: item.isImage,
                    imagePath: item.imagePath,
                    rawLineText: item.rawLineText
                })
            }
        }
        selectedIndex = 0
        updatePreview()
    }

    function updatePreview() {
        if (selectedIndex < 0 || selectedIndex >= filteredClipboardModel.count) {
            previewImage = ""
            return
        }
        const item = filteredClipboardModel.get(selectedIndex)
        if (item.isImage && item.imagePath) {
            imageExtractor.command = ["sh", "-c", "cliphist decode " + item.id + " > " + item.imagePath + " 2>/dev/null"]
            imageExtractor.running = true
        } else {
            previewImage = ""
        }
    }

    function moveUp() { if (selectedIndex > 0) { selectedIndex--; updatePreview(); } }
    function moveDown() { if (selectedIndex < filteredClipboardModel.count - 1) { selectedIndex++; updatePreview(); } }

    function copySelected() {
        if (selectedIndex < 0 || selectedIndex >= filteredClipboardModel.count) return;
        copyItem(filteredClipboardModel.get(selectedIndex).id)
    }

    function copyItem(clipId) {
        if (!clipId || clipId.length === 0) return;
        copyProcess.command = ["sh", "-c", "cliphist decode " + clipId + " | wl-copy"]
        copyProcess.running = true
    }

    /*
     * FIXED: Changed the shell command parameters completely.
     * Echoes the full unmodified source string row entry straight into the delete tool stdin pipe interface.
     */
    function deleteSelected() {
        if (selectedIndex < 0 || selectedIndex >= filteredClipboardModel.count) return;
        const item = filteredClipboardModel.get(selectedIndex);
        if (!item.rawLineText) return;

        deleteProcess.command = ["sh", "-c", "echo '" + item.rawLineText.replace(/'/g, "'\\''") + "' | cliphist delete"]
        deleteProcess.running = true
    }
    Process {
        id: clipboardLoader
        command: ["sh", "-c", "cliphist list | head -n 300 > /tmp/quickshell_clipboard.txt"]
        onExited: {
            const xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                const lines = (xhr.responseText || "").split("\n")
                clipboardModel.clear()

                for (let i = 0; i < lines.length; ++i) {
                    const line = lines[i].trim()
                    if (!line.length) continue;

                    let firstSpace = line.indexOf("\t")
                    if (firstSpace === -1) firstSpace = line.indexOf(" ")
                        if (firstSpace === -1) continue;

                        const clipId = line.substring(0, firstSpace).trim()
                        const clipText = line.substring(firstSpace + 1).trim()
                        const lower = clipText.toLowerCase()

                        const isImage = lower.includes("image") || lower.includes(".png") ||
                        lower.includes(".jpg") || lower.includes(".jpeg") ||
                        lower.includes(".gif") || lower.includes(".webp") ||
                        lower.includes("binary data")

                        const rawPath = isImage ? "/tmp/quickshell_clip_raw_" + clipId : ""
                        const thumbPath = isImage ? "/tmp/quickshell_clip_thumb_" + clipId + ".png" : ""

                        if (isImage) {
                            thumbnailBatcher.commands.push(
                                "cliphist decode " + clipId + " > " + rawPath + " 2>/dev/null; " +
                                "if [ -s " + rawPath + " ]; then " +
                                "  TYPE_STR=$(file --mime-type -b " + rawPath + " | cut -d'/' -f2); " +
                                "  [ \"$TYPE_STR\" = \"x-empty\" ] && TYPE_STR=\"png\" || true; " +
                                "  (convert \"$TYPE_STR\":" + rawPath + " -thumbnail 100x100 png:" + thumbPath + " || " +
                                "   gm convert \"$TYPE_STR\":" + rawPath + " -thumbnail 100x100 png:" + thumbPath + " || " +
                                "   cp " + rawPath + " " + thumbPath + ") 2>/dev/null; " +
                                "fi; rm -f " + rawPath
                            )
                        }

                        /*
                         * FIXED: Added the 'rawLineText' parameter hook properties to store the original unmodified
                         * text layout line string, making sure cliphist's deletion module can find and drop the database target entry.
                         */
                        clipboardModel.append({
                            id: clipId,
                            text: isImage ? "<img src='file://" + thumbPath + "' width='100' height='100'/>" : clipText,
                            isImage: isImage,
                            imagePath: thumbPath,
                            rawLineText: line
                        })
                }
                if (thumbnailBatcher.commands.length > 0) thumbnailBatcher.executeNext();
                refreshFilter(currentQuery)
            }
            xhr.open("GET", "file:///tmp/quickshell_clipboard.txt")
            xhr.send()
        }
    }

    Item {
        id: thumbnailBatcher
        property var commands: []
        function executeNext() {
            if (commands.length === 0) return;
            batchWorker.command = ["sh", "-c", commands.shift()];
            batchWorker.running = true;
        }
        Process { id: batchWorker; onExited: thumbnailBatcher.executeNext() }
    }

    Process { id: imageExtractor; onExited: { const item = filteredClipboardModel.get(selectedIndex); if (item && item.isImage) previewImage = "file://" + item.imagePath; } }
    Process { id: copyProcess; onExited: root.clipboardCopied("done") }
    Process { id: deleteProcess; onExited: reloadDelayTimer.start() }

    Component.onCompleted: loadClipboard()
}
