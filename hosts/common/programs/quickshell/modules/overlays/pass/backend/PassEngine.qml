import QtQuick
import Quickshell
import Quickshell.Io

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
        command: ["sh", "-c", "command -v pass >/dev/null 2>&1 && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => { engine.hasPass = (data.trim() === "1"); }
        }
    }

    readonly property Process listKeysProc: Process {
        command: [
            "sh", "-c",
            'dir="${PASSWORD_STORE_DIR:-$HOME/.password-store}"; [ ! -d "$dir" ] && dir="$HOME/.local/share/pass"; ' +
            '[ -d "$dir" ] && cd "$dir" && find . -type f -name "*.gpg" | sed "s|^\\./||; s|\\.gpg$||" | sort'
        ]
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

    readonly property Process decryptProc: Process {}

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
            "sh", "-c",
            'dir="${PASSWORD_STORE_DIR:-$HOME/.password-store}"; [ ! -d "$dir" ] && dir="$HOME/.local/share/pass"; ' +
            'PASSWORD_STORE_DIR="$dir" pass -c "$1" >/dev/null 2>&1 && ' +
            'notify-send -a Pass -u normal -i dialog-password "🔑 Password Copied" "Auto-clearing clipboard in 45s..."',
            "sh", key
        ];
        decryptProc.running = true;
    }
}
