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
    property bool hasCliphist: true

    Process {
        id: cliphistDetector
        running: true
        command: ["sh", "-c", "export PATH='$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH'; command -v cliphist >/dev/null 2>&1 && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                root.hasCliphist = (data.trim() === "1");
            }
        }
    }
    signal clipboardCopied(string id)

    ListModel {
        id: filteredClipboardModel
    }

    Timer {
        id: filterTimer
        interval: 35
        repeat: false
        onTriggered: refreshFilter(pendingQuery)
    }

    // Polling kept intact, but checks current query so it never resets focus mid-typing
    Timer {
        id: changePoller
        interval: 2000
        running: typeof launcherRoot !== 'undefined' && launcherRoot && launcherRoot.mode === "clipboard" && launcherWindow.visible
        repeat: true
        onTriggered: {
            if (!deleteProc.running && !pollCheckWorker.running && !clipboardLoader.running && root.currentQuery === "") {
                pollCheckWorker.running = true;
            }
        }
    }

    // Debounce preview decode process so rapid arrow-key navigation is instant
    Timer {
        id: previewDebounceTimer
        interval: 75
        repeat: false
        property string targetId: ""
        onTriggered: {
            if (!targetId) return;
            previewLoader.running = false;
            previewLoader.command = ["cliphist", "decode", targetId];
            previewLoader.running = true;
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
        let added = 0;
        const maxDisplay = showAll ? 100 : 200;

        for (let i = 0, c = allClipboardItems.length; i < c; ++i) {
            const item = allClipboardItems[i];

            if (imageMode && !item.isImage) continue;

            if (showAll || item.searchText.includes(q) || (item.isImage && (q === "image" || item.text.toLowerCase().includes(q)))) {
                filteredClipboardModel.append(item);
                added++;
                if (added >= maxDisplay) break;
            }
        }

        if (selectedIndex >= filteredClipboardModel.count) {
            selectedIndex = Math.max(0, filteredClipboardModel.count - 1);
        }
        updatePreview();
    }

    function loadPreviewText(id) {
        previewDebounceTimer.targetId = id;
        previewDebounceTimer.restart();
    }

    function updatePreview() {
        if (selectedIndex < 0 || selectedIndex >= filteredClipboardModel.count) {
            previewImage = "";
            previewText = "";
            previewDebounceTimer.stop();
            return;
        }

        const item = filteredClipboardModel.get(selectedIndex);
        if (item.isImage && item.imagePath) {
            previewDebounceTimer.stop();
            previewImage = "file://" + item.imagePath;
            previewText = "";
        } else {
            previewImage = "";
            loadPreviewText(item.id);
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

        const isImage = Boolean(item.isImage);
        const imagePath = String(item.imagePath || "");
        const cleanId = String(item.id || "").trim();

        for (let i = 0; i < allClipboardItems.length; i++) {
            if (String(allClipboardItems[i].id).trim() === cleanId) {
                allClipboardItems.splice(i, 1);
                break;
            }
        }

        filteredClipboardModel.remove(idx);
        if (selectedIndex >= filteredClipboardModel.count) {
            selectedIndex = Math.max(0, filteredClipboardModel.count - 1);
        }
        updatePreview();

        if (isImage && imagePath.length > 0) {
            var jsonPath = imagePath.replace(/\.png$/, ".json");
            deleteProc.running = false;
            deleteProc.command = ["sh", "-c", "rm -vf '" + imagePath + "' '" + jsonPath + "'"];
            deleteProc.running = true;
        } else if (cleanId.length > 0) {
            deleteProc.running = false;
            deleteProc.command = [
                "sh", "-c",
                "printf '%s\\t-\\n' '" + cleanId + "' | cliphist delete; " +
                "if [ -d /tmp/cliphist_db ]; then printf '%s\\t-\\n' '" + cleanId + "' | CLIPHIST_DB_PATH=/tmp/cliphist_db cliphist delete; fi"
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

    Process {
        id: pollCheckWorker
        command: ["sh", "-c", "cliphist list 2>/dev/null | head -n 1 | cut -f1"]
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

    property string _jsonBuffer: ""

    // Instant JSON pipeline (<10ms total execution time)
    Process {
        id: clipboardLoader
        command: [
            "python3", "-c",
            "import os, glob, json, subprocess, sqlite3, time, shutil, datetime\n" +
            "items = []\n" +
            "\n" +
            "# --- Quickshot images: parse timestamp from the JSON filename ---\n" +
            "hist = os.path.expanduser('~/.cache/quickshot_history')\n" +
            "if os.path.isdir(hist):\n" +
            "    for f in glob.glob(os.path.join(hist, '*.json')):\n" +
            "        img = f[:-5] + '.png'\n" +
            "        if not os.path.exists(img):\n" +
            "            continue\n" +
            "        try:\n" +
            "            with open(f) as jf:\n" +
            "                name = json.load(jf).get('name', '')\n" +
            "            base = os.path.basename(f)\n" +
            "            parts = base.split('_')\n" +
            "            ts = 0\n" +
            "            if len(parts) >= 3 and len(parts[1]) == 8 and len(parts[2]) >= 6:\n" +
            "                dt = datetime.datetime.strptime(parts[1] + '_' + parts[2][:6], '%Y%m%d_%H%M%S')\n" +
            "                ts = dt.timestamp()\n" +
            "            items.append({'id': img, 'text': '[Image: ' + name + ']', 'searchText': name.lower(), 'isImage': True, 'imagePath': img, '_ts': ts})\n" +
            "        except Exception:\n" +
            "            pass\n" +
            "\n" +
            "# --- Cliphist text: read the SQLite DB directly for real timestamps ---\n" +
            "db_paths = []\n" +
            "env_db = os.environ.get('CLIPHIST_DB_PATH')\n" +
            "if env_db:\n" +
            "    db_paths.append(os.path.join(env_db, 'db'))\n" +
            "    db_paths.append(env_db)\n" +
            "xdg_cache = os.environ.get('XDG_CACHE_HOME', os.path.expanduser('~/.cache'))\n" +
            "db_paths.append(os.path.join(xdg_cache, 'cliphist', 'db'))\n" +
            "\n" +
            "cliphist_rows = []\n" +
            "used_db = False\n" +
            "for db in db_paths:\n" +
            "    if not os.path.isfile(db):\n" +
            "        continue\n" +
            "    try:\n" +
            "        conn = sqlite3.connect('file:' + db + '?mode=ro', uri=True)\n" +
            "        cur = conn.cursor()\n" +
            "        try:\n" +
            "            cur.execute('SELECT id, created_at, raw FROM history ORDER BY created_at DESC LIMIT 300')\n" +
            "            for row in cur.fetchall():\n" +
            "                cliphist_rows.append((row[0], row[1], row[2]))\n" +
            "        except sqlite3.OperationalError:\n" +
            "            try:\n" +
            "                cur.execute('SELECT id, created_at, value FROM history ORDER BY created_at DESC LIMIT 300')\n" +
            "                for row in cur.fetchall():\n" +
            "                    cliphist_rows.append((row[0], row[1], row[2]))\n" +
            "            except Exception:\n" +
            "                cliphist_rows = []\n" +
            "        conn.close()\n" +
            "        if cliphist_rows:\n" +
            "            used_db = True\n" +
            "            break\n" +
            "    except Exception:\n" +
            "        continue\n" +
            "\n" +
            "if used_db:\n" +
            "    for cid, created, raw in cliphist_rows:\n" +
            "        try:\n" +
            "            if isinstance(raw, bytes):\n" +
            "                text = raw.decode('utf-8', errors='ignore')\n" +
            "            else:\n" +
            "                text = str(raw)\n" +
            "        except Exception:\n" +
            "            continue\n" +
            "        if 'binary data' in text or '[Image' in text or not text.strip():\n" +
            "            continue\n" +
            "        ts = created / 1000.0 if created > 1e12 else float(created)\n" +
            "        items.append({'id': str(cid), 'text': text, 'searchText': text.lower(), 'isImage': False, 'imagePath': '', '_ts': ts})\n" +
            "else:\n" +
            "    try:\n" +
            "        p = subprocess.Popen(['cliphist', 'list'], stdout=subprocess.PIPE, text=True, errors='ignore')\n" +
            "        count = 0\n" +
            "        for line in p.stdout:\n" +
            "            line = line.rstrip('\\n')\n" +
            "            parts = line.split('\\t', 1)\n" +
            "            if len(parts) == 2 and 'binary data' not in parts[1] and '[Image' not in parts[1]:\n" +
            "                items.append({'id': parts[0].strip(), 'text': parts[1], 'searchText': parts[1].lower(), 'isImage': False, 'imagePath': '', '_ts': 0})\n" +
            "                count += 1\n" +
            "                if count >= 200:\n" +
            "                    break\n" +
            "        p.stdout.close()\n" +
            "        p.wait()\n" +
            "    except Exception:\n" +
            "        pass\n" +
            "\n" +
            "items.sort(key=lambda it: it['_ts'], reverse=True)\n" +
            "for it in items:\n" +
            "    del it['_ts']\n" +
            "\n" +
            "print(json.dumps(items))\n"
        ]

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { root._jsonBuffer += data; }
        }
        onStarted: { root._jsonBuffer = ""; }
        onExited: {
            try {
                root.allClipboardItems = JSON.parse(root._jsonBuffer);
            } catch(e) {
                root.allClipboardItems = [];
            }
            root._jsonBuffer = "";
            root.refreshFilter(root.currentQuery);
        }
    }

    property string _previewAccumulator: ""

    // Single-pass preview loader that never triggers layout thrashing in TextArea
    Process {
        id: previewLoader
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (root._previewAccumulator.length < 4000) {
                    root._previewAccumulator += (root._previewAccumulator.length > 0 ? "\n" : "") + data;
                }
            }
        }
        onStarted: {
            root._previewAccumulator = "";
            root.previewText = "";
        }
        onExited: {
            if (root._previewAccumulator.length >= 4000) {
                root.previewText = root._previewAccumulator + "\n\n... [preview truncated]";
            } else {
                root.previewText = root._previewAccumulator;
            }
        }
    }

    Component.onCompleted: loadClipboard()
}
