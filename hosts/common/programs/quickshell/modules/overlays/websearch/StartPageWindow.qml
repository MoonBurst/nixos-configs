import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./backend" as Backend
import "./frontend" as Frontend

// Web search dialog overlay. Inherits native Wayland layer-shell keyboard focus
// and per-window dismissal policies (Dismiss-on-Blur and Close-on-Escape)
// configured via SettingsManager.
Common.OverlayWindow {
    id: webWindow

    windowId: "web"
    defaultW: 780
    defaultH: 320
    defaultPolicy: "lazy"

    Backend.WebSearchEngine { id: webEngine }

    // If the window was opened with a query argument, run it immediately.
    onWindowOpened: if (pendingArg) webEngine.search(pendingArg)

    viewComponent: Component {
        Frontend.WebSearchView {
            engine: webEngine
            theme: webWindow.theme
            settingsManager: webWindow.settingsManager
            onCompleted: webWindow.close()
        }
    }
}
