import QtQuick
import Quickshell.Io

Item {
    id: root

    // -------------------------
    // STATE MIRROR (FOR IPC)
    // -------------------------
    property bool active: false
    property string mode: "apps"
    property string query: ""

    // -------------------------
    // CONNECT TO ROOT VIA PROPERTY LOOKUP
    // -------------------------
    // This is the key fix: we mutate the actual UI instance if present
    property var uiRoot: null

    function ensureUI() {
        if (!uiRoot)
            uiRoot = root.parent
    }

    // -------------------------
    // CORE OPEN/CLOSE
    // -------------------------

    function openApps() {
        ensureUI()

        active = true
        mode = "apps"

        if (uiRoot) {
            uiRoot.isMenuOpen = true
            uiRoot.isClipboardMode = false
            uiRoot.isMathMode = false
            uiRoot.activeImageCachePath = ""
        }
    }

    function openClipboard() {
        ensureUI()

        active = true
        mode = "clipboard"

        if (uiRoot) {
            uiRoot.isMenuOpen = true
            uiRoot.openClipboardMenu()
        }
    }

    function openMath() {
        ensureUI()

        active = true
        mode = "math"

        if (uiRoot) {
            uiRoot.isMenuOpen = true
            uiRoot.isMathMode = true
        }
    }

    function close() {
        ensureUI()

        active = false
        mode = ""

        if (uiRoot) {
            uiRoot.closeMenu()
        }
    }

    function toggleMenu() {
        ensureUI()

        if (uiRoot && uiRoot.isMenuOpen && mode === "apps") {
            close()
            return
        }

        openApps()
    }

    function openDictionary(word) {
        ensureUI()

        active = true
        mode = "dict"
        query = word || ""

        if (uiRoot) {
            uiRoot.isMenuOpen = true
            uiRoot.isMathMode = true
            uiRoot.fetchWordDefinition(word)
        }
    }

    // -------------------------
    // IPC HELPERS
    // -------------------------

    function activate(modeName) {
        switch (modeName) {
            case "apps":
                openApps()
                break
            case "clipboard":
                openClipboard()
                break
            case "math":
                openMath()
                break
            case "dict":
                openDictionary("")
                break
            default:
                openApps()
        }
    }
}
