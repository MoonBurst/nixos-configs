pragma Singleton

import Quickshell
import QtQuick

// Shared, cross-monitor session state.
Singleton {
    id: root

    // Currently selected tool.
    property string tool: "select"
    property color strokeColor: Style.annotationPalette[0]
    property real strokeWidth: 4
    property int fontSize: 26

    property int counterValue: 1

    // ---- Watermark & Dual-Stage Scanner State ---------------------------------
    property string watermarkText: ""
    // 0.009 (0.9%): Ultra-stealth. Completely invisible to the naked eye,
    // but amplified into crisp binary text by the 2-stage scanner.
    property real watermarkOpacity: 0.009
    property bool revealWatermark: false
    // Toggles real-time high-contrast scanner
    property bool scanMode: false
    // Contrast pivot threshold: shifts the scanner to decode dark vs light images
    property real scanThreshold: 0.38

    property string activeScreen: ""
    property bool finishing: false

    signal copyRequested()
    signal saveRequested()
    signal undoRequested()
    signal ocrRequested()

    readonly property var tools: [
        { id: "select",      icon: "⤢", tip: "Move / resize selection (V)" },
        { id: "rect",        icon: "▭", tip: "Rectangle (R)" },
        { id: "ellipse",     icon: "◯", tip: "Ellipse (O)" },
        { id: "arrow",       icon: "↗", tip: "Arrow (A)" },
        { id: "line",        icon: "╱", tip: "Line (L)" },
        { id: "pen",         icon: "✎", tip: "Freehand pen (P)" },
        { id: "highlight",   icon: "▬", tip: "Highlighter (H)" },
        { id: "text",        icon: "T", tip: "Text (T)" },
        { id: "counter",     icon: "①", tip: "Numbered step (N)" },
        { id: "redact",      icon: "█", tip: "Redact / redact (X)" },
        { id: "colorpicker", icon: "✛", tip: "Color Picker (I)" }
    ]

    function isDrawTool() { return root.tool !== "select" && root.tool !== "colorpicker"; }

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

    function shQuote(p) {
        return "'" + String(p).replace(/'/g, "'\\''") + "'";
    }

    function saveDir() {
        return home() + "/Screenshots";
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
}
