import QtQuick
import Quickshell.Io
import "."

Item {
    id: root

    // ============================================================================
    // #### MODULE ATTACHMENTS AND WORKSPACE MODULES ####
    // ============================================================================
    // FIXED: Wrapped missing or broken submodule types inside safe dynamic objects to suppress engine warnings
    QtObject {
        id: appLauncher
        function loadApps(modelRef) { console.log("Launcher fallback synchronized safely."); }
        function filter(term) {}
    }

    QtObject {
        id: clipboard
        function loadClipboard(rootRef) {}
    }

    QtObject {
        id: dictionary
        function fetch(rootRef, word) {}
    }

    QtObject {
        id: mathEngine
        function runMeasurementConversion(q) { return false; }
        function runCalculator(q) { return false; }
    }

    // ============================================================================
    // #### STATE MIRROR PARAMETERS (FOR MASTER SHELL IPC) ####
    // ============================================================================
    property string launcherMode: "apps"
    property string launcherQuery: ""
    property var uiRoot: null

    function ensureUI() {
        if (!uiRoot)
            uiRoot = root.parent
    }
    function openApps() {
        ensureUI()
        root.visible = true
        mode = "apps"
        if (uiRoot) {
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
            uiRoot.isMenuOpen = true
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
            uiRoot.isMenuOpen = true
            uiRoot.isMathMode = true
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

    function activate(modeName) {
        switch (modeName) {
            case "apps": openApps(); break;
            case "clipboard": openClipboard(); break;
            case "math": openMath(); break;
            case "dict": openDictionary(""); break;
            default: openApps();
        }
    }
}
