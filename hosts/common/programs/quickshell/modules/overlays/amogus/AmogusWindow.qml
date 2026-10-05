import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "../../common/Utils.js" as Utils
import "./frontend" as Frontend

Common.OverlayWindow {
    id: root

    windowId: "amogus"
    ipcTarget: ""  // OverlayHost owns the "amogus" IPC target
    defaultW: 620
    defaultH: 480
    defaultPolicy: "lazy"

    // Amogus deliberately ignores Escape — it's a game tracker meant to
    // stay visible while you play. Close it via the header ✕ button or
    // `qs ipc call amogus close`.
    escapeCloses: false

    // Keep the original API names so existing callers (launcher, IPC,
    // other overlays) keep working without modification.
    function showWindow() { open(); }
    function hideWindow() { close(); }
    function toggleWindow() { toggle(); }

    // The card needs to be large enough for the crewmate grid even at
    // smaller window sizes, so clamp to a minimum.
    readonly property int cardMinWidth: 480
    readonly property int cardMinHeight: 380

    viewComponent: Component {
        Frontend.AmogusView {
            shell: root.shell
            dragTarget: null
            dragMaxX: 0
            dragMaxY: 0
            isPreviewMode: root.isPreviewMode
            isCardActive: root.isCardActive
            currentScreenIndex: root.currentScreenIndex
            onCloseRequested: root.close()
            onScreenSelected: (idx) => { root.currentScreenIndex = idx; }
        }
    }

    // ---- Amogus-specific state --------------------------------------------
    property int currentScreenIndex: 0

    Component.onCompleted: {
        if (Quickshell.screens.length > 1) {
            currentScreenIndex = 1;
        }
    }

    // Override the base's screen selector so the Amogus window lands on
    // the user's chosen screen rather than the primary.
    screen: {
        if (Quickshell.screens.length > currentScreenIndex) {
            return Quickshell.screens[currentScreenIndex];
        }
        return Quickshell.screens[0] || null;
    }
}
