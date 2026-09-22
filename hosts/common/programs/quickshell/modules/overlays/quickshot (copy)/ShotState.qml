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
    // Stealth opacity for the microdot layer. Dots cover far less area than
    // tiled text would, so this needs to run a bit higher than a full-area
    // text overlay to survive re-encoding/downscaling. Tune down if dots
    // become perceptible on your typical backgrounds, or up if the decoder
    // misses real-world (e.g. JPEG-recompressed) screenshots.
    property real watermarkDotOpacity: 0.14
    property bool revealWatermark: false
    // Toggles real-time high-contrast scanner
    property bool scanMode: false
    // Contrast pivot threshold: shifts the scanner to decode dark vs light images
    property real scanThreshold: 0.38

    // ---- Microdot watermark encoding constants --------------------------------
    // Shared by the encoder (AnnotationCanvas's watermarkLayer) and the
    // decoder (PanelWindow's automatic scan-on-selection in overlay.qml).
    // Both read these instead of hardcoding their own copies, so they can
    // never drift apart.
    //
    // Bit layout per tile, row-major:
    //   bits[0:4]    fixed sync nibble wmSyncNibble -- lets the decoder find
    //                grid phase without knowing where an image was cropped from
    //   bits[4:8]    payload length in bytes (0-7)
    //   bits[8:8+8n] payload bytes (ASCII), MSB first, n = length
    //   next 8 bits  checksum = sum(payload bytes) mod 256
    //   remaining    alternating filler
    readonly property int wmDotPitch: 14
    readonly property int wmTileCols: 12
    readonly property int wmTileRows: 6
    readonly property int wmBitCount: wmTileCols * wmTileRows // 72
    readonly property var wmSyncNibble: [1, 0, 1, 0]

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
