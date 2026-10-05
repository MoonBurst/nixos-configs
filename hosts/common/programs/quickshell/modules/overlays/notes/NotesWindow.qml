import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./backend" as Backend
import "./frontend" as Frontend

Common.OverlayWindow {
    id: notesWindow

    windowId: "notes"
    defaultW: 840
    defaultH: 650
    defaultPolicy: "lazy"

    Backend.NotesEngine { id: notesEngine }

    onPreShow: notesEngine.loadNotes()

    viewComponent: Component {
        Frontend.NotesView {
            engine: notesEngine
            theme: notesWindow.theme
            settingsManager: notesWindow.settingsManager
            onCompleted: notesWindow.close()
        }
    }
}
