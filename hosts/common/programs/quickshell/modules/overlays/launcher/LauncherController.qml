import QtQuick

Item {
    id: root

    // FIX 1: Explicit path component definitions completely bypass the broken qmldir singleton tracking traps
    Loader { id: appLauncherLoader; source: "AppLauncher.qml" }
    Loader { id: clipboardLoader; source: "Clipboard.qml" }
    Loader { id: dictionaryLoader; source: "Dictionary.qml" }
    Loader { id: mathEngineLoader; source: "MathEngine.qml"; onLoaded: { if(item) item.root = uiRoot } }

    property bool active: false
    property string mode: "apps"
    property string query: ""
    property var uiRoot: null

    function ensureUI() {
        if (!uiRoot) uiRoot = root.parent
    }

    function openApps() {
        ensureUI()
        active = true
        mode = "apps"
        if (uiRoot && appLauncherLoader.item) {
            appLauncherLoader.item.loadApps(uiRoot.filteredAppsModel)
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
        if (uiRoot && clipboardLoader.item) {
            clipboardLoader.item.loadClipboard(uiRoot)
            uiRoot.isMenuOpen = true
            if (typeof uiRoot.openClipboardMenu === "function") {
                uiRoot.openClipboardMenu()
            }
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
        if (uiRoot && dictionaryLoader.item) {
            dictionaryLoader.item.fetch(uiRoot, word)
            uiRoot.isMenuOpen = true
            uiRoot.isMathMode = true
            if (typeof uiRoot.fetchWordDefinition === "function") {
                uiRoot.fetchWordDefinition(word)
            }
        }
    }

    function runMath(query) {
        ensureUI()
        if (!mathEngineLoader.item) return
            if (mathEngineLoader.item.runMeasurementConversion(query)) return
                if (mathEngineLoader.item.runCalculator(query)) return
    }

    function filterApps(searchTerm) {
        if (appLauncherLoader.item) {
            appLauncherLoader.item.filter(searchTerm);
        }
    }

    function activate(modeName) {
        switch (modeName) {
            case "apps": openApps(); break
            case "clipboard": openClipboard(); break
            case "math": openMath(); break
            case "dict": openDictionary(""); break
            default: openApps()
        }
    }
}
