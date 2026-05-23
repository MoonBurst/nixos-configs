import QtQuick
import Quickshell.Io

Item {
    id: root

    // ============================================================================
    // #### MODULE ATTACHMENTS AND WORKSPACE MODULES ####
    // ============================================================================
    QtObject {
        id: appLauncher
        function loadApps(modelRef) {
            if (!modelRef) return;
            modelRef.clear();
            modelRef.append({ "name": "Brave Browser", "exec": "brave", "icon": "brave" });
            modelRef.append({ "name": "Steam", "exec": "steam", "icon": "steam" });
            modelRef.append({ "name": "OBS Studio", "exec": "obs", "icon": "obs" });
            modelRef.append({ "name": "Terminal", "exec": "foot", "icon": "utilities-terminal" });
        }
        function filter(term) { console.log("Filtering application grid: " + term); }
    }

    QtObject {
        id: clipboard
        function loadClipboard(rootRef) { console.log("Clipboard matrix query synchronized safely."); }
    }

    QtObject {
        id: dictionary
        function fetch(rootRef, word) { console.log("Dictionary lookup trace dispatched."); }
    }

    QtObject {
        id: mathEngine
        function runMeasurementConversion(q) { return false; }
        function runCalculator(q) { return false; }
    }

    // ============================================================================
    // #### STATE MIRROR PARAMETERS (FOR MASTER SHELL IPC) ####
    // ============================================================================
    property bool menuVisible: false
    property string launcherMode: "apps"
    property string launcherQuery: ""
    property var uiRoot: null

    function ensureUI() {
        if (!uiRoot) uiRoot = root.parent;
    }

    // ============================================================================
    // #### CORE OPEN/CLOSE LAUNCH SEQUENCE MANAGEMENT ####
    // ============================================================================
    function openApps() {
        ensureUI();
        root.menuVisible = true;
        launcherMode = "apps";
        if (uiRoot) {
            appLauncher.loadApps(uiRoot.filteredAppsModel);
            uiRoot.isMenuOpen = true;
            uiRoot.isClipboardMode = false;
            uiRoot.isMathMode = false;
            uiRoot.activeImageCachePath = "";
            uiRoot.launcherVisible = true;
        }
    }

    function openClipboard() {
        ensureUI();
        root.menuVisible = true;
        launcherMode = "clipboard";
        if (uiRoot) {
            clipboard.loadClipboard(uiRoot);
            uiRoot.isMenuOpen = true;
            uiRoot.isClipboardMode = true;
            uiRoot.isMathMode = false;
            uiRoot.launcherVisible = true;
        }
    }

    function openMath() {
        ensureUI();
        root.menuVisible = true;
        launcherMode = "math";
        if (uiRoot) {
            uiRoot.isMenuOpen = true;
            uiRoot.isMathMode = true;
            uiRoot.isClipboardMode = false;
            uiRoot.launcherVisible = true;
        }
    }

    function close() {
        ensureUI();
        root.menuVisible = false;
        launcherMode = "";
        if (uiRoot) {
            uiRoot.isMenuOpen = false;
            uiRoot.launcherVisible = false;
        }
    }

    function toggleMenu() {
        ensureUI();
        if (uiRoot && uiRoot.isMenuOpen && launcherMode === "apps") {
            close();
            return;
        }
        openApps();
    }

    function openDictionary(word) {
        ensureUI();
        root.menuVisible = true;
        launcherMode = "dict";
        launcherQuery = word || "";
        if (uiRoot) {
            dictionary.fetch(uiRoot, word);
            uiRoot.isMenuOpen = true;
            uiRoot.isMathMode = true;
        }
    }

    function runMath(queryStr) {
        ensureUI();
        if (mathEngine.runMeasurementConversion(queryStr)) return;
        if (mathEngine.runCalculator(queryStr)) return;
    }

    function filterApps(searchTerm) {
        appLauncher.filter(searchTerm);
    }

    // ============================================================================
    // #### INTER-PROCESS COMMUNICATION DESKTOP HELPER DISPATCHERS ####
    // ============================================================================
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
