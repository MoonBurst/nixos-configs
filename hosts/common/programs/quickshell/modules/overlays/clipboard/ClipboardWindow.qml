import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./frontend" as Frontend

// Main overlay window for clipboard history management.
// Runs persistent background watchers that capture copies across the session.
Common.OverlayWindow {
    id: clipboardWindow

    windowId: "clipboard"
    defaultW: 1080
    defaultH: 700
    defaultPolicy: "lazy"

    // Text Watcher: Captures text copies into cliphist.
    // Checks for the active pass lockfile before storing. When a password
    // is decrypted, the lockfile exists, preventing cliphist from writing plaintext
    // passwords to the local history database.
    Process {
        id: cliphistWatcherText
        running: true
        command: [
            "wl-paste", "--watch", "sh", "-c",
            '[ -f "${XDG_RUNTIME_DIR:-/tmp}/quickshell-pass-copying" ] || exec cliphist store'
        ]
    }

    // Image Watcher: Captures copied images and screenshots into cliphist.
    Process {
        id: cliphistWatcherImage
        running: true
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
    }

    viewComponent: Component {
        Frontend.ClipboardView {
            theme: clipboardWindow.theme
            settingsManager: clipboardWindow.settingsManager
            onCompleted: clipboardWindow.close()
        }
    }
}
