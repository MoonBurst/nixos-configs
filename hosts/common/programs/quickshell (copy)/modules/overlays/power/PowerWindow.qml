import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./backend" as Backend
import "./frontend" as Frontend

Common.OverlayWindow {
    id: powerWindow

    windowId: "power"
    defaultW: 720
    defaultH: 560
    defaultPolicy: "lazy"

    Backend.PowerEngine { id: powerEngine }

    viewComponent: Component {
        Frontend.PowerView {
            engine: powerEngine
            theme: powerWindow.theme
            settingsManager: powerWindow.settingsManager
            onCompleted: powerWindow.close()
        }
    }
}
