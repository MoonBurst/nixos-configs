import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./frontend" as Frontend

Common.OverlayWindow {
    id: clipboardWindow

    windowId: "clipboard"
    defaultW: 1080
    defaultH: 700
    defaultPolicy: "lazy"

    // Background cliphist watchers. Run for the shell's whole lifetime so
    // every clipboard copy is captured regardless of whether the clipboard
    // window has been opened this session.
    // Ignore clipboard events marked sensitive (passwords / keys)
    Process {
        id: cliphistWatcherText
        running: true
        command: ["wl-paste", "--watch", "sh", "-c", '[ "$CLIPBOARD_STATE" = "sensitive" ] || exec cliphist store']
    }
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
