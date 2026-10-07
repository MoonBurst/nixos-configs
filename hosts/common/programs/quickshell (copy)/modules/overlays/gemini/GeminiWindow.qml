import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./backend" as Backend
import "./frontend" as Frontend

Common.OverlayWindow {
    id: geminiWindow

    windowId: "gemini"
    defaultW: 880
    defaultH: 720
    defaultPolicy: "lazy"

    Backend.GeminiEngine { id: geminiEngine }

    viewComponent: Component {
        Frontend.GeminiView {
            engine: geminiEngine
            theme: geminiWindow.theme
            settingsManager: geminiWindow.settingsManager
        }
    }
}
