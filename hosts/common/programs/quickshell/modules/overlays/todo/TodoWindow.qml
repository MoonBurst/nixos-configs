import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./backend" as Backend
import "./frontend" as Frontend

Common.OverlayWindow {
    id: todoWindow

    windowId: "todo"
    defaultW: 860
    defaultH: 740
    defaultPolicy: "lazy"

    Backend.TodoEngine { id: todoEngine }

    viewComponent: Component {
        Frontend.TodoView {
            id: todoViewInstance
            engine: todoEngine
            theme: todoWindow.theme
            settingsManager: todoWindow.settingsManager
        }
    }
}
