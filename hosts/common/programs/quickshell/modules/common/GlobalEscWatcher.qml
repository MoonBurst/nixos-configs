import QtQuick
import Quickshell
import Quickshell.Io

Process {
    id: escWatcherProcess

    property bool active: false
    signal escapePressed()

    running: active
    command: [
        "luajit",
        Quickshell.shellDir + "/modules/common/escwatcher.lua"
    ]
    stdout: SplitParser {
        splitMarker: "\n"
        onRead: data => {
            if (data.trim() === "ESC") escWatcherProcess.escapePressed();
        }
    }
}
