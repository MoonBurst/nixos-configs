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

    Process {
        id: checkCliphistProc
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null 2>&1 && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => { engine.hasCliphist = (data.trim() === "1"); }
        }
    }

    property string _jsonBuffer: ""
    Process {
        id: clipboardLoader
        running: false
        command: [
            "python3", "-c",
            "import os, glob, json, subprocess\n" +
            "paths = os.environ.get('PATH', '').split(':')\n" +
            "paths += [os.path.expanduser('~/.nix-profile/bin'), os.path.expanduser('~/.local/bin'), '/run/current-system/sw/bin']\n" +
            "os.environ['PATH'] = ':'.join(paths)\n" +
            "items = []\n" +
            "hist = os.path.expanduser('~/.cache/quickshot_history')\n" +
            "if os.path.isdir(hist):\n" +
            "    for f in sorted(glob.glob(os.path.join(hist, '*.json')), key=os.path.getmtime, reverse=True)[:50]:\n" +
            "        img = f[:-5] + '.png'\n" +
            "        if not os.path.exists(img): continue\n" +
            "        try:\n" +
            "            with open(f) as jf: name = json.load(jf).get('name', '')\n" +
            "            items.append({'id': img, 'text': '[Image: ' + name + ']', 'searchText': name.lower(), 'isImage': True, 'imagePath': img})\n" +
            "        except Exception: pass\n" +
            "try:\n" +
            "    p = subprocess.Popen(['cliphist', 'list'], stdout=subprocess.PIPE, text=True, errors='ignore')\n" +
            "    for line in p.stdout:\n" +
            "        line = line.rstrip('\\n')\n" +
            "        parts = line.split('\\t', 1)\n" +
            "        if len(parts) == 2:\n" +
            "            cid, txt = parts[0].strip(), parts[1]\n" +
            "            if 'binary data' not in txt and '[Image' not in txt and txt.strip():\n" +
            "                items.append({'id': cid, 'text': txt, 'searchText': txt.lower(), 'isImage': False, 'imagePath': ''})\n" +
            "                if len(items) >= 250: break\n" +
            "    p.stdout.close(); p.wait()\n" +
            "except Exception: pass\n" +
            "print(json.dumps(items))\n"
        ]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { engine._jsonBuffer += data; }
        }
        onStarted: { engine._jsonBuffer = ""; }
        onExited: {
            try {
                var parsed = JSON.parse(engine._jsonBuffer.trim());
                if (Array.isArray(parsed)) {
                    engine.allClipboardItems = parsed;
                }
            } catch(e) {
                engine.allClipboardItems = [];
            }
            engine._jsonBuffer = "";
            engine.refreshFilter(engine.currentQuery);
        }
    }

    property string _previewAccumulator: ""
    Process {
        id: previewLoader
        running: false
        command: ["cliphist", "decode", ""]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (engine._previewAccumulator.length < 4000) {
                    engine._previewAccumulator += (engine._previewAccumulator.length > 0 ? "\n" : "") + data;
                }
            }
        }
        onStarted: { engine._previewAccumulator = ""; engine.previewText = ""; }
        onExited: {
            engine.previewText = (engine._previewAccumulator.length >= 4000)
                ? (engine._previewAccumulator + "\n\n... [preview truncated]")
                : engine._previewAccumulator;
        }
    }

    Process { id: copyProcess; running: false }
    Process { id: deleteProc; running: false }
    Process {
        id: wipeProcess
        running: false
        command: ["sh", "-c", "export PATH=\"$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH\"; cliphist wipe; rm -rf $HOME/.cache/quickshot_history/*"]
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
            previewLoader.running = false;
            previewLoader.command = ["cliphist", "decode", item.id];
            previewLoader.running = true;
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
            copyProcess.command = ["sh", "-c", "cliphist decode " + item.id + " | wl-copy"];
        }
        copyProcess.running = true;
    }

    function deleteSelected() {
        if (selectedIndex < 0 || selectedIndex >= fModel.count) return;
        const item = fModel.get(selectedIndex);
        if (!item) return;

        const isImage = Boolean(item.isImage);
        const imagePath = String(item.imagePath || "");
        const cleanId = String(item.id || "").trim();

        for (let i = 0; i < allClipboardItems.length; i++) {
            if (String(allClipboardItems[i].id).trim() === cleanId) {
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
        } else if (cleanId.length > 0) {
            deleteProc.command = ["sh", "-c", "printf '%s\\t-\\n' '" + cleanId + "' | cliphist delete"];
            deleteProc.running = true;
        }
    }

    function wipeHistory() {
        allClipboardItems = [];
        fModel.clear();
        selectedIndex = 0;
        updatePreview();
        wipeProcess.running = true;
    }
}
