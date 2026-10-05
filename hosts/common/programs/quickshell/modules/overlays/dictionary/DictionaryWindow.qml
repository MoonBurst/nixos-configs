import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./backend" as Backend
import "./frontend" as Frontend

Common.OverlayWindow {
    id: dictionaryWindow

    windowId: "dictionary"
    defaultW: 820
    defaultH: 600
    defaultPolicy: "lazy"

    Backend.DictionaryEngine { id: dictEngine }

    viewComponent: Component {
        Frontend.DictionaryView {
            engine: dictEngine
            theme: dictionaryWindow.theme
            settingsManager: dictionaryWindow.settingsManager
            onCompleted: dictionaryWindow.close()
        }
    }
}
