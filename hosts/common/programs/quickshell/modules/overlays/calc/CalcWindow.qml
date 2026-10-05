import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./backend" as Backend
import "./frontend" as Frontend

Common.OverlayWindow {
    id: calcWindow

    windowId: "calc"
    defaultW: 820
    defaultH: 580
    defaultPolicy: "lazy"

    Backend.CalcEngine { id: calcEngine }

    viewComponent: Component {
        Frontend.CalcView {
            engine: calcEngine
            theme: calcWindow.theme
            settingsManager: calcWindow.settingsManager
            onCompleted: calcWindow.close()
        }
    }
}
