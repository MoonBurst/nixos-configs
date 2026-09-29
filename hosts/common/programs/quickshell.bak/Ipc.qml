pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: ipcBridge

    readonly property string shellDir: Quickshell.shellDir
    property var shellRoot: null

    function call(target, method, ...args) {
        // Fast path: In-memory JavaScript call (<0.02ms latency)
        if (shellRoot) {
            var handler = shellRoot[target + "Handler"] || shellRoot[target];
            if (handler && typeof handler[method] === "function") {
                handler[method](...args);
                return;
            }
        }

        // External CLI fallback
        var cmd = [
            "sh", "-c",
            'QS=$(command -v qs || command -v quickshell)\n' +
            'DIR="$1"\n' +
            'TARGET="$2"\n' +
            'METHOD="$3"\n' +
            'shift 3\n' +
            'if [ -n "$QS" ]; then\n' +
            '  "$QS" -p "$DIR" ipc call "$TARGET" "$METHOD" "$@"\n' +
            'fi',
            "sh",
            ipcBridge.shellDir,
            target,
            method
        ];

        if (args && args.length > 0) {
            for (var i = 0; i < args.length; i++) {
                cmd.push(String(args[i]));
            }
        }

        Quickshell.execDetached(cmd);
    }
}
