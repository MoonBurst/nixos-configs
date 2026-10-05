import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./backend" as Backend
import "./frontend" as Frontend

Common.OverlayWindow {
    id: unicodeWindow

    windowId: "unicode"
    defaultW: 780
    defaultH: 600
    defaultPolicy: "lazy"

    Backend.UnicodeEngine { id: unicodeEngine }

    viewComponent: Component {
        Frontend.UnicodeView {
            engine: unicodeEngine
            theme: unicodeWindow.theme
            settingsManager: unicodeWindow.settingsManager
            onCompleted: unicodeWindow.close()
        }
    }
}
