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

    Component.onCompleted: {
        loadClipboard();
    }

    property string _jsonBuffer: ""
    Process {
        id: clipboardLoader
        running: false
        command: [
            "python3", "-c",
            "import os, glob, json\n" +
            "items_pool = []\n" +
            "\n" +
            "# 1. Harvest Image Assets from Quickshot Cache with actual OS creation times\n" +
            "hist = os.path.expanduser('~/.cache/quickshot_history')\n" +
            "if os.path.isdir(hist):\n" +
            "    for f in glob.glob(os.path.join(hist, '*.json')):\n" +
            "        img = f[:-5] + '.png'\n" +
            "        if not os.path.exists(img): continue\n" +
            "        try:\n" +
            "            ts = int(os.path.getmtime(f))\n" +
            "            with open(f) as jf: name = json.load(jf).get('name', '')\n" +
            "            items_pool.append({\n" +
            "                'ts': ts,\n" +
            "                'data': {'id': img, 'text': '[Image: ' + name + ']', 'searchText': name.lower(), 'isImage': True, 'imagePath': img, 'fullRawText': ''}\n" +
            "            })\n" +
            "        except: pass\n" +
            "\n" +
            "# 2. Harvest Null-Terminated Text Blocks (Evaluating reversed to put newest on top)\n" +
            "state_file = '/tmp/native_clipboard_history.txt'\n" +
            "if os.path.exists(state_file):\n" +
            "    try:\n" +
            "        file_ts = int(os.path.getmtime(state_file))\n" +
            "        with open(state_file, 'r', encoding='utf-8', errors='ignore') as sf:\n" +
            "            content = sf.read()\n" +
            "            blocks = [b.strip() for b in content.split('\\x00') if b.strip()]\n" +
            "            \n" +
            "            fallback_ts = 0\n" +
            "            # FIXED: Loop backwards through blocks so the newest logs get the largest timestamps\n" +
            "            for b in reversed(blocks):\n" +
            "                txt = b\n" +
            "                ts = file_ts - fallback_ts\n" +
            "                fallback_ts += 1\n" +
            "                \n" +
            "                if b.startswith('##TS:'):\n" +
            "                    try:\n" +
            "                        parts = b.split('|', 1)\n" +
            "                        if len(parts) == 2:\n" +
            "                            ts = int(parts[0][5:])\n" +
            "                            txt = parts[1]\n" +
            "                    except:\n" +
            "                        pass\n" +
            "                \n" +
            "                lines_list = txt.splitlines()\n" +
            "                first_line = lines_list[0].strip() if lines_list else txt.strip()\n" +
            "                display_text = first_line if len(first_line) < 55 else first_line[:52] + '...'\n" +
            "                if len(lines_list) > 1:\n" +
            "                    display_text += ' ↵'\n" +
            "                \n" +
            "                items_pool.append({\n" +
            "                    'ts': ts,\n" +
            "                    'data': {'id': '', 'text': display_text, 'searchText': txt.lower(), 'isImage': False, 'imagePath': '', 'fullRawText': txt}\n" +
            "                })\n" +
            "    except:\n" +
            "        pass\n" +
            "\n" +
            "# 3. Unified Chronological Interleaving Sort Pass (Newest Items First!)\n" +
            "items_pool.sort(key=lambda x: x['ts'], reverse=True)\n" +
            "\n" +
            "final_items = []\n" +
            "seen_text = set()\n" +
            "\n" +
            "for item in items_pool:\n" +
            "    payload = item['data']\n" +
            "    if not payload['isImage']:\n" +
            "        if payload['fullRawText'] in seen_text: continue\n" +
            "        seen_text.add(payload['fullRawText'])\n" +
            "    \n" +
            "    final_items.append(payload)\n" +
            "\n" +
            "# Post-process re-index serial id markers for list view identification strings\n" +
            "idx = len(final_items)\n" +
            "for item in final_items:\n" +
            "    if not item['isImage']:\n" +
            "        item['id'] = str(idx)\n" +
            "    idx -= 1\n" +
            "\n" +
            "print(json.dumps(final_items))\n"
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
                "python3", "-c",
                "import sys\n" +
                "with open('/tmp/native_clipboard_history.txt', 'r') as f: content = f.read()\n" +
                "blocks = content.split('\\x00')\n" +
                "with open('/tmp/native_clipboard_history.txt', 'w') as f:\n" +
                "    for b in blocks:\n" +
                "        txt = b\n" +
                "        if b.startswith('##TS:'):\n" +
                "            try:\n" +
                "                parts = b.split('|', 1)\n" +
                "                if len(parts) == 2: txt = parts[1]\n" +
                "            except: pass\n" +
                "        if txt.strip() != sys.argv.strip():\n" +
                "            f.write(b + '\\x00')\n",
                cleanText
            ];
            deleteProc.running = true;
        }
    }

    Timer {
        id: liveSyncTimer
        interval: 1000
        running: parent ? parent.visible : false
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            engine.loadClipboard();
        }
    }
}
