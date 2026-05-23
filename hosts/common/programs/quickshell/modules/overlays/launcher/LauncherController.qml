import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // =========================
    // UI BINDING
    // =========================
    property Item uiRoot: null

    function bindUI(ui) {
        uiRoot = ui
    }

    function ensureUI() {
        if (!uiRoot) return false
            return true
    }

    // =========================
    // STATE
    // =========================
    property string mode: "apps"
    property string query: ""

    property bool visible: false

    // =========================
    // CORE STATE API (SINGLE SOURCE OF TRUTH)
    // =========================
    function open(modeName) {
        if (!ensureUI()) return

            mode = modeName
            visible = true

            uiRoot.launcherVisible = true
            uiRoot.isMenuOpen = true

            switch (modeName) {
                case "apps":
                    uiRoot.isClipboardMode = false
                    uiRoot.isMathMode = false
                    break

                case "clipboard":
                    uiRoot.isClipboardMode = true
                    uiRoot.isMathMode = false
                    break

                case "math":
                    uiRoot.isMathMode = true
                    uiRoot.isClipboardMode = false
                    break

                case "dict":
                    uiRoot.isMathMode = false
                    uiRoot.isClipboardMode = false
                    break
            }
    }

    function close() {
        if (!ensureUI()) return

            visible = false
            mode = ""

            uiRoot.launcherVisible = false
            uiRoot.isMenuOpen = false
    }

    function toggle() {
        if (visible) close()
            else open("apps")
    }

    function setMode(modeName) {
        open(modeName)
    }

    function openWithQuery(modeName, q) {
        query = q || ""
        open(modeName)
    }

}
