pragma Singleton

import Quickshell
import QtQuick

// Shared, cross-monitor session state. The selection geometry and annotations
// live on the individual ScreenOverlay that owns them (they are screen-local),
// but the *tool* choices and the "which monitor is active" coordination are
// global and therefore live here.
Singleton {
    id: root

    // Currently selected tool. One of the `id`s in `tools` below, or "select".
    property string tool: "select"
    property color strokeColor: Style.annotationPalette[0]
    property real strokeWidth: 4
    property int fontSize: 26

    // Monotonic counter for the numbered-step tool. Reset when annotations clear.
    property int counterValue: 1

    // Name of the ShellScreen that currently owns the selection. Empty until the
    // user starts dragging on a monitor; afterwards every other overlay locks
    // itself out so a screenshot only ever spans the monitor it began on.
    property string activeScreen: ""

    // Set once an export has been kicked off so a stray second Enter/click can't
    // fire a duplicate save while we are tearing down.
    property bool finishing: false

    // Keyboard focus under layershell lands on a single overlay, which may not
    // be the monitor that owns the selection. Key handlers therefore broadcast
    // these requests; only the owning overlay acts on them.
    signal copyRequested()
    signal saveRequested()
    signal undoRequested()

    readonly property var tools: [
        { id: "select",    icon: "⤢", tip: "Move / resize selection (V)" },
        { id: "rect",      icon: "▭", tip: "Rectangle (R)" },
        { id: "ellipse",   icon: "◯", tip: "Ellipse (O)" },
        { id: "arrow",     icon: "↗", tip: "Arrow (A)" },
        { id: "line",      icon: "╱", tip: "Line (L)" },
        { id: "pen",       icon: "✎", tip: "Freehand pen (P)" },
        { id: "highlight", icon: "▬", tip: "Highlighter (H)" },
        { id: "text",      icon: "T",      tip: "Text (T)" },
        { id: "counter",   icon: "①", tip: "Numbered step (N)" },
        { id: "pixelate",  icon: "▦", tip: "Pixelate / redact (X)" }
    ]

    function isDrawTool() { return root.tool !== "select"; }

    function claimScreen(name) {
        if (root.activeScreen === "")
            root.activeScreen = name;
    }

    function ownsSelection(name) {
        return root.activeScreen === "" || root.activeScreen === name;
    }

    // ---- Paths ---------------------------------------------------------------
    function home() {
        var h = Quickshell.env("HOME");
        return (h && h.length > 0) ? h : "/tmp";
    }

    function saveDir() {
        return home() + "/Pictures/Screenshots";
    }

    function timestamp() {
        return Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss");
    }

    function savePath() {
        return saveDir() + "/quickshot_" + timestamp() + ".png";
    }

    function clipPath() {
        return "/tmp/quickshot-clip.png";
    }

    // Single-quote a path for safe use inside `sh -c`.
    function shQuote(p) {
        return "'" + String(p).replace(/'/g, "'\\''") + "'";
    }
}
