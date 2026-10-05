import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./backend" as Backend
import "./frontend" as Frontend

Common.OverlayWindow {
    id: passWindow

    windowId: "pass"
    defaultW: 820
    defaultH: 600
    defaultPolicy: "lazy"

    Backend.PassEngine { id: passEngine }

    onPreShow: passEngine.reload()

    viewComponent: Component {
        Frontend.PassView {
            engine: passEngine
            theme: passWindow.theme
            settingsManager: passWindow.settingsManager
            onCompleted: passWindow.close()
        }
    }
}
