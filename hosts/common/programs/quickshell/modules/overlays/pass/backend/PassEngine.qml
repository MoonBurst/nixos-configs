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
    property bool isLoading: false
    property int clipboardClearSeconds: 20

    property var passModel: ListModel { id: pModel }
    property var filteredModel: ListModel { id: fModel }

    Component.onCompleted: reload()
    onSearchQueryChanged: filterModel()

    // 1. Check pass availability via Lua
    readonly property Process passCheckProc: Process {
        running: true
        command: Common.LuaRunner.cmd("modules/overlays/pass/backend/PassEngine.lua", "check")
        stdout: StdioCollector {
            onStreamFinished: {
                engine.hasPass = (text ? text.trim() === "1" : false);
            }
        }
    }

    // 2. Fetch password list via Lua
    readonly property Process listKeysProc: Process {
        command: Common.LuaRunner.cmd("modules/overlays/pass/backend/PassEngine.lua", "list")
        stdout: StdioCollector {
            onStreamFinished: {
                engine.isLoading = false;
                pModel.clear();
                var raw = (text || "").trim();
                if (raw.length > 0) {
                    var lines = raw.split("\n");
                    for (var i = 0; i < lines.length; i++) {
                        var l = lines[i].trim();
                        if (l !== "") pModel.append({ "key": l });
                    }
                }
                engine.filterModel();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                engine.isLoading = false;
                if (text && text.trim() !== "") {
                    console.warn("[PassEngine List Error]: " + text.trim());
                }
            }
        }
    }

    // 3. Decrypt and copy via Lua
    readonly property Process decryptProc: Process {
        running: false
    }

    function reload() {
        engine.isLoading = true;
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
        decryptProc.command = Common.LuaRunner.cmd(
            "modules/overlays/pass/backend/PassEngine.lua",
            "copy",
            key,
            String(engine.clipboardClearSeconds)
        );
        decryptProc.running = false;
        decryptProc.running = true;
    }
}
