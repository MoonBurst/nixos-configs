import QtQuick
import Quickshell
import Quickshell.Io

Process {
    id: escWatcherProcess

    property bool active: false
    signal escapePressed()

    running: active
    command: [
        "sh", "-c",
        'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
        'exec luajit "$1"',
        "sh",
        Quickshell.shellDir + "/modules/common/escwatcher.lua"
    ]
    stdout: SplitParser {
        splitMarker: "\n"
        onRead: data => {
            if (data.trim() === "ESC") escWatcherProcess.escapePressed();
        }
    }
}
