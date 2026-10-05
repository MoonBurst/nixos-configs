import QtQuick
import Quickshell
import Quickshell.Io
import "../../../common" as Common

QtObject {
    id: engine

    property string searchQuery: ""
    property int selectedIndex: 0
    property string topKey: ""
    property bool hasPass: true

    property var passModel: ListModel { id: pModel }
    property var filteredModel: ListModel { id: fModel }

    Component.onCompleted: reload()
    onSearchQueryChanged: filterModel()

    readonly property Process passCheckProc: Process {
        running: true
        command: Common.LuaRunner.cmd("/modules/overlays/pass/backend/PassEngine.lua", "check")
        stdout: SplitParser {
            onRead: data => { engine.hasPass = (data.trim() === "1"); }
        }
    }

    readonly property Process listKeysProc: Process {
        command: Common.LuaRunner.cmd("/modules/overlays/pass/backend/PassEngine.lua", "list")
        stdout: SplitParser {
            onRead: data => {
                var lines = data.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim();
                    if (l !== "") pModel.append({ "key": l });
                }
                engine.filterModel();
            }
        }
    }

    // How long a decrypted password is allowed to sit on the clipboard
    // before it is cleared automatically. The clipboard is also cleared on
    // the next pass-copy so overlapping sessions cannot leak into each other.
    property int clipboardClearSeconds: 20

    readonly property Process clipboardSweeper: Process {}

    readonly property Process decryptProc: Process {
        onExited: (code) => {
            if (code !== 0) return;
            // Spawn a detached shell that sleeps, then wipes the clipboard.
            // A second pass-copy within the window restarts the sweep, so
            // only the most recent password ever lives on the clipboard, and
            // only for the configured window.
            engine.clipboardSweeper.running = false;
            engine.clipboardSweeper.command = [
                "sh", "-c",
                'sleep "$1"; printf "" | wl-copy --clear 2>/dev/null || printf "" | wl-copy 2>/dev/null || true',
                "sh", String(engine.clipboardClearSeconds)
            ];
            engine.clipboardSweeper.running = true;
        }
    }

    function reload() {
        pModel.clear();
        fModel.clear();
        selectedIndex = 0;
        topKey = "";
        listKeysProc.running = false;
        listKeysProc.running = true;
    }

    function filterModel() {
        fModel.clear();
        var txt = searchQuery.toLowerCase().trim();
        for (var i = 0; i < pModel.count; i++) {
            var item = pModel.get(i);
            if (txt === "" || item.key.toLowerCase().indexOf(txt) !== -1) {
                fModel.append(item);
            }
        }
        selectedIndex = 0;
        topKey = fModel.count > 0 ? fModel.get(0).key : "";
    }

    function decryptAndCopy(key) {
        if (!key) return;
        decryptProc.command = [
            "lua",
            Quickshell.shellDir + "/modules/overlays/pass/backend/PassEngine.lua",
            "copy",
            key
        ];
        decryptProc.running = true;
    }
}
