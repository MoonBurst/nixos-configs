import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import "../../common" as Common
import "./backend" as Backend
import "./frontend" as Frontend

Common.OverlayWindow {
    id: reminderWindow

    windowId: "reminders"
    defaultW: 780
    defaultH: 580
    defaultPolicy: "lazy"

    Backend.ReminderEngine { id: reminderEngine }

    viewComponent: Component {
        Frontend.ReminderView {
            engine: reminderEngine
            theme: reminderWindow.theme
            settingsManager: reminderWindow.settingsManager
            onCompleted: reminderWindow.close()
        }
    }
}
