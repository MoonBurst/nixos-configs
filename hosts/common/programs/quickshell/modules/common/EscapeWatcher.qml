pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Always-running global Escape watcher. Reads /dev/input/event* directly via
// the bundled Lua script and emits `escapePressed()` on every press.
//
// Every OverlayWindow subscribes to this signal. Only the topmost visible
// overlay responds to the event, so Escape always closes whichever window is
// actually open, regardless of compositor focus state.
Singleton {
    id: watcher

    signal escapePressed()

    property bool debugLogging: false

    Process {
        id: watcherProcess
        // Always on. One long-lived process (~1MB) is cheaper than
        // spawning on every overlay open, and sidesteps the PanelWindow
        // Process quirk we hit with per-window instantiation.
        running: true
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
                var line = data.trim();
                if (watcher.debugLogging) console.log("[EscapeWatcher]", line);
                if (line === "ESC") watcher.escapePressed();
            }
        }
        onRunningChanged: {
            if (watcher.debugLogging) console.log("[EscapeWatcher] process running:", running);
        }
    }
}
