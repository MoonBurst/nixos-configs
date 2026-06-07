pragma Singleton

import Quickshell
import QtQuick

// Central design tokens for Quickshot. Keeping colours, sizes and fonts in one
// singleton lets every component share a consistent look and makes re-theming a
// one-file change.
Singleton {
    id: root

    // ---- Palette -------------------------------------------------------------
    readonly property color accent: "#4c9aff"
    readonly property color accentText: "#ffffff"
    readonly property color panel: "#1d1f27"
    readonly property color panelRaised: "#2a2d38"
    readonly property color panelBorder: "#3a3e4d"
    readonly property color text: "#eceef4"
    readonly property color textMuted: "#9aa0b4"
    readonly property color shadow: "#000000"

    // The veil drawn over everything outside the active selection.
    readonly property color dim: "#000000"
    readonly property real dimOpacity: 0.55

    // ---- Selection chrome ----------------------------------------------------
    readonly property color selectionBorder: accent
    readonly property real selectionBorderWidth: 1.5
    readonly property real handleSize: 12
    readonly property color handleFill: "#ffffff"
    readonly property color handleBorder: accent

    // ---- Toolbar / buttons ---------------------------------------------------
    readonly property real toolbarRadius: 12
    readonly property real toolbarPadding: 6
    readonly property real toolbarSpacing: 4
    readonly property real buttonSize: 34
    readonly property real buttonRadius: 8
    readonly property real swatchSize: 20
    readonly property real gap: 12

    // ---- Annotation defaults -------------------------------------------------
    // A spread of strong, high-contrast colours plus white & near-black.
    readonly property var annotationPalette: [
        "#ff453a", "#ff9f0a", "#ffd60a", "#32d74b",
        "#0a84ff", "#5e5ce6", "#ffffff", "#1c1c1e"
    ]
    readonly property var strokeWidths: [2, 4, 7, 12]

    // ---- Typography ----------------------------------------------------------
    readonly property string fontFamily: "Inter, Roboto, Noto Sans, sans-serif"
    readonly property string iconFamily: "Noto Sans Symbols2, Noto Sans Symbols, Segoe UI Symbol, sans-serif"
    readonly property real badgeFontSize: 13
}
