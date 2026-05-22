import QtQuick
import Quickshell.Io
import "."

Item {
    id: root

    // ============================================================================
    // #### MODULE ATTACHMENTS AND WORKSPACE MODULES ####
    // ============================================================================
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

    // ============================================================================
    // #### STATE MIRROR PARAMETERS (FOR MASTER SHELL IPC) ####
    // ============================================================================
    property bool visible: false
    property string mode: "apps"
    property string query: ""

    property var uiRoot: null

    function ensureUI() {
        if (!uiRoot)
            uiRoot = root.parent
    }

    // ============================================================================
    // #### CORE OPEN/CLOSE LAUNCH SEQUENCE MANAGEMENT ####
    // ============================================================================
    function openApps() {
        ensureUI()

        root.visible = true
        mode = "apps"

        if (uiRoot) {
            appLauncher.loadApps(uiRoot.filteredAppsModel)
            uiRoot.isMenuOpen = true
            uiRoot.isClipboardMode = false
            uiRoot.isMathMode = false
            uiRoot.activeImageCachePath = ""
            uiRoot.launcherVisible = true
        }
    }

    function openClipboard() {
        ensureUI()

        root.visible = true
        mode = "clipboard"

        if (uiRoot) {
            clipboard.loadClipboard(uiRoot)
            uiRoot.isMenuOpen = true
            // FIXED: Swapped out broken 'openClipboardMenu()' call with explicit property flags
            uiRoot.isClipboardMode = true
            uiRoot.isMathMode = false
            uiRoot.launcherVisible = true
        }
    }

    function openMath() {
        ensureUI()

        root.visible = true
        mode = "math"

        if (uiRoot) {
            uiRoot.isMenuOpen = true
            uiRoot.isMathMode = true
            uiRoot.isClipboardMode = false
            uiRoot.launcherVisible = true
        }
    }

    function close() {
        ensureUI()

        root.visible = false
        mode = ""

        if (uiRoot) {
            // FIXED: Swapped out broken 'closeMenu()' call with direct visibility property updates
            uiRoot.isMenuOpen = false
            uiRoot.launcherVisible = false
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

        root.visible = true
        mode = "dict"
        query = word || ""

        if (uiRoot) {
            dictionary.fetch(uiRoot, word)
            uiRoot.isMenuOpen = true
            uiRoot.isMathMode = true
            // FIXED: Removed missing 'fetchWordDefinition()' string parser method
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

    // ============================================================================
    // #### INTER-PROCESS COMMUNICATION DESKTOP HELPER DISPATCHERS ####
    // ============================================================================
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
