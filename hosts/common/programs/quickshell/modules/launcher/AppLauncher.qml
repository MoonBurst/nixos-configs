import QtQuick
import Quickshell.Io

Item {
    id: root

    // === THEME VARIABLES: GROUPED AT TOP ===
    property int fontSize: 20
    property color mainColor: "#F7F700"
    property color backgroundColor: "#1a1a1a"
    property color borderColor: "#F7F700"
    property int borderRadius: 8
    property int borderWidth: 2

    // ------------------------
    // MODULES
    // ------------------------

    AppLauncher {
        id: appLauncher
    }

    Clipboard {
        id: clipboard
    }

    Dictionary {
        id: dictionary
    }

    MathEngine {
        id: mathEngine
        root: uiRoot
    }

    // -------------------------
    // STATE MIRROR (FOR IPC)
    // -------------------------
    property bool active: false
    property string mode: "apps"
    property string query: ""

    // -------------------------
    // CONNECT TO ROOT VIA PROPERTY LOOKUP
    // -------------------------
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
            appLauncher.loadApps(uiRoot.filteredAppsModel)
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
            clipboard.loadClipboard(uiRoot)
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
            dictionary.fetch(uiRoot, word)
            uiRoot.isMenuOpen = true
            uiRoot.isMathMode = true
            uiRoot.fetchWordDefinition(word)
        }
    }

    function runMath(query) {
        ensureUI()
        if (mathEngine.runMeasurementConversion(query)) return
            if (mathEngine.runCalculator(query)) return
    }

    function filterApps(searchTerm) {
        appLauncher.filter(searchTerm);
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
