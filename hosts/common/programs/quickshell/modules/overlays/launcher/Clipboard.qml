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
    property var thumbnailQueue: []
    property var deleteQueue: [] // Queue to handle rapid deletions sequentially

    property alias filteredClipboardItems: filteredClipboardModel

    signal clipboardCopied(string id)

    ListModel {
        id: filteredClipboardModel
    }

    Timer {
        id: filterTimer
        interval: 40
        repeat: false
        onTriggered: {
            refreshFilter(pendingQuery)
        }
    }

    Timer {
        id: changePoller
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            // Only poll if we aren't actively processing deletions to avoid race conditions
            if (deleteQueue.length === 0 && !deleteProcess.running && !pollCheckWorker.running) {
                pollCheckWorker.running = true
            }
        }
    }

    function handleDeleteKeyPress() {
        deleteSelected()
    }

    function queueFilter(query) {
        pendingQuery = query || ""
        filterTimer.restart()
    }

    // Clear and reload clipboard context from database
    function loadClipboard() {
        allClipboardItems = []
        thumbnailQueue = []
        filteredClipboardModel.clear()
        clipboardLoader.running = true
    }

    function refreshFilter(query) {
        currentQuery = query || ""
        let q = currentQuery.toLowerCase().trim()
        const imageMode = q.startsWith("image:")

        if (imageMode) {
            q = q.substring(6).trim()
        }

        filteredClipboardModel.clear()
        const showAll = q.length === 0

        for (let i = 0, c = allClipboardItems.length; i < c; ++i) {
            const item = allClipboardItems[i]

            if (imageMode && !item.isImage) {
                continue
            }

            if (showAll || item.searchText.includes(q) || (item.isImage && q === "image")) {
                filteredClipboardModel.append(item)
            }
        }

        selectedIndex = 0;
        updatePreview();
    }

    function loadPreviewText() {
        if (selectedIndex < 0 || selectedIndex >= filteredClipboardModel.count) {
            previewText = ""
            return
        }

        const item = filteredClipboardModel.get(selectedIndex)
        if (item.isImage) {
            previewText = ""
            return
        }

        previewLoader.command = [
            "sh",
            "-c",
            "cliphist decode " + item.id
        ]
        previewLoader.running = true
    }

    function updatePreview() {
        if (selectedIndex < 0 || selectedIndex >= filteredClipboardModel.count) {
            previewImage = ""
            previewText = ""
            return
        }

        const item = filteredClipboardModel.get(selectedIndex)

        if (item.isImage && item.imagePath) {
            previewImage = "file://" + item.imagePath
            previewText = ""
        } else {
            previewImage = ""
            loadPreviewText()
        }
    }

    function moveUp() {
        if (selectedIndex > 0) {
            --selectedIndex
            updatePreview()
        }
    }

    function moveDown() {
        if (selectedIndex < filteredClipboardModel.count - 1) {
            ++selectedIndex
            updatePreview()
        }
    }

    function copySelected() {
        if (selectedIndex < 0 || selectedIndex >= filteredClipboardModel.count) {
            return
        }
        copyItem(filteredClipboardModel.get(selectedIndex).id)
    }

    function copyItem(clipId) {
        if (!clipId) return;

        copyProcess.command = [
            "sh",
            "-c",
            "cliphist decode " + clipId + " | wl-copy"
        ]
        copyProcess.running = true
    }

    // Optimistic Deletion: Update UI immediately, queue backend writes
    function deleteSelected() {
        if (selectedIndex < 0 || selectedIndex >= filteredClipboardModel.count) {
            return
        }

        const item = filteredClipboardModel.get(selectedIndex)
        if (!item || !item.rawLineText) return;

        const targetId = item.id
        const rawLine = item.rawLineText

        // 1. Remove from local memory immediately
        let allIdx = -1
        for (let i = 0; i < allClipboardItems.length; i++) {
            if (allClipboardItems[i].id === targetId) {
                allIdx = i
                break
            }
        }
        if (allIdx !== -1) {
            allClipboardItems.splice(allIdx, 1)
        }

        // 2. Remove from active UI list
        filteredClipboardModel.remove(selectedIndex)

        // Adjust index and update preview
        if (selectedIndex >= filteredClipboardModel.count) {
            selectedIndex = Math.max(0, filteredClipboardModel.count - 1)
        }
        updatePreview()

        // 3. Queue backend deletion
        deleteQueue.push(rawLine)
        processDeleteQueue()
    }

    function processDeleteQueue() {
        if (deleteQueue.length === 0 || deleteProcess.running) return;

        const nextRawText = deleteQueue.shift()
        deleteProcess.command = [
            "sh",
            "-c",
            "printf '%s\\n' '" + nextRawText.replace(/'/g, "'\\\\''") + "' | cliphist delete"
        ]
        deleteProcess.running = true
    }

    function wipeHistory() {
        allClipboardItems = []
        filteredClipboardModel.clear()
        selectedIndex = 0
        updatePreview()
        wipeProcess.running = true
    }

    function addClipboardItem(clipId, clipText, rawLine) {
        const isImage = /image|\.png|\.jpg|\.jpeg|\.gif|\.webp|binary data/i.test(clipText);
        const thumbDir = "/tmp/clipboard_thumbnails"
        const thumbPath = isImage ? thumbDir + "/quickshell_clip_thumb_" + clipId + ".png" : ""

        if (isImage) {
            // Optimised check: only decode/convert if the thumbnail file does NOT already exist
            thumbnailQueue.push(
                "[ -f " + thumbPath + " ] || (" +
                "cliphist decode " + clipId + " | magick - -thumbnail 100x100 png:" + thumbPath + " 2>/dev/null || " +
                "cliphist decode " + clipId + " | convert - -thumbnail 100x100 png:" + thumbPath + " 2>/dev/null || " +
                "cliphist decode " + clipId + " > " + thumbPath + " 2>/dev/null)"
            )
        }

        allClipboardItems.push({
            id: clipId,
            text: clipText,
            searchText: clipText.toLowerCase(),
                               isImage,
                               imagePath: thumbPath,
                               rawLineText: rawLine
        })
    }

    function flushThumbnailQueue() {
        if (thumbnailQueue.length === 0) return;

        thumbnailWorker.command = [
            "sh",
            "-c",
            "mkdir -p /tmp/clipboard_thumbnails;" + thumbnailQueue.join(";")
        ]
        thumbnailWorker.running = true
    }

    Process {
        id: pollCheckWorker
        command: [
            "sh",
            "-c",
            "cliphist list | head -n 1 | cut -f1"
        ]

        stdout: SplitParser {
            onRead: data => {
                const cleanId = data.trim()
                if (cleanId && cleanId !== root.lastSeenTopId) {
                    root.lastSeenTopId = cleanId
                    loadClipboard()
                }
            }
        }
    }

    Process {
        id: clipboardLoader
        command: [
            "sh",
            "-c",
            "cliphist list | head -n 300"
        ]

        stdout: SplitParser {
            onRead: data => {
                const lines = data.split("\n")
                for (let i = 0, c = lines.length; i < c; ++i) {
                    const line = lines[i].trim()
                    if (!line) continue;

                    let sep = line.indexOf("\t")
                    if (sep === -1) continue;

                    addClipboardItem(
                        line.slice(0, sep).trim(),
                                     line.slice(sep + 1).trim(),
                                     line
                    )
                }
            }
        }

        onExited: {
            flushThumbnailQueue()
            refreshFilter(currentQuery)
        }
    }

    Process {
        id: previewLoader
        stdout: SplitParser {
            onRead: data => {
                root.previewText += data
            }
        }
        onStarted: {
            root.previewText = ""
        }
    }

    Process {
        id: thumbnailWorker
    }

    Process {
        id: copyProcess
        onExited: {
            root.clipboardCopied("done")
        }
    }

    Process {
        id: deleteProcess
        onExited: {
            processDeleteQueue() // Check if there are more queued items to delete
        }
    }

    Process {
        id: wipeProcess
        running: false
        command: ["sh", "-c", "cliphist wipe; rm -rf /tmp/clipboard_thumbnails/*"]
    }

    Component.onCompleted: {
        loadClipboard()
    }
}
