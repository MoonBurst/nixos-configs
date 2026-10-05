import QtQuick
import QtQuick.Shapes 1.15

Item {
    id: root

    property string shapeType: "auto"
    property string role: "card" // "card", "input", or "custom"

    // Search up the parent hierarchy to locate settingsManager and theme regardless of scope
    readonly property var resolvedSettingsManager: {
        if (typeof shell !== "undefined" && shell && shell.settingsManager) return shell.settingsManager;
        var p = root.parent;
        while (p) {
            if (p.settingsManager) return p.settingsManager;
            if (p.shell && p.shell.settingsManager) return p.shell.settingsManager;
            p = p.parent;
        }
        return null;
    }

    readonly property var resolvedTheme: {
        if (typeof shell !== "undefined" && shell && shell.theme) return shell.theme;
        var p = root.parent;
        while (p) {
            if (p.theme) return p.theme;
            if (p.shell && p.shell.theme) return p.shell.theme;
            p = p.parent;
        }
        return null;
    }

    property int slantWidth: effectiveSlantWidth
    property int hexCut: effectiveHexCut

    readonly property string effectiveShape: {
        if (shapeType !== "auto" && shapeType !== "") return shapeType;
        if (resolvedSettingsManager) {
            return role === "input" ? resolvedSettingsManager.inputFieldShape : resolvedSettingsManager.overlayCardShape;
        }
        return "rounded";
    }

    property color color: resolvedTheme ? (resolvedTheme.base00 || "#11111b") : "#11111b"
    property color borderColor: resolvedTheme ? (resolvedTheme.base05 || "yellow") : "yellow"

    readonly property real effectiveBorderWidth: {
        if (resolvedSettingsManager) {
            return role === "input"
                ? (resolvedSettingsManager.controlBorderWidth || 2)
                : (resolvedSettingsManager.globalBorderWidth || 3);
        }
        if (resolvedTheme) {
            return (role === "input" && resolvedTheme.controlBorderWidth !== undefined)
                ? resolvedTheme.controlBorderWidth
                : (resolvedTheme.globalBorderWidth || 2);
        }
        return role === "input" ? 2 : 3;
    }

    property real borderWidth: effectiveBorderWidth
    property real radius: resolvedTheme ? (resolvedTheme.defaultCardRadius || 10) : 10

    readonly property string effectiveSlantDirection: {
        if (role === "card" && resolvedSettingsManager) {
            return resolvedSettingsManager.overlaySlantDirection || "left";
        }
        return "left";
    }

    property string slantLeft: {
        if (role === "card") {
            if (effectiveSlantDirection === "right") return "Right";
            if (effectiveSlantDirection === "center") return "Left";
            return "Left";
        }
        return "Left";
    }

    property string slantRight: {
        if (role === "card") {
            if (effectiveSlantDirection === "right") return "Right";
            if (effectiveSlantDirection === "center") return "Right";
            return "Left";
        }
        return "Right";
    }

    readonly property int effectiveSlantWidth: {
        if (resolvedSettingsManager) {
            return role === "input" ? resolvedSettingsManager.inputSlantAngle : resolvedSettingsManager.overlaySlantAngle;
        }
        return role === "input" ? 14 : 32;
    }

    readonly property int effectiveHexCut: {
        if (resolvedSettingsManager) {
            return role === "input" ? resolvedSettingsManager.inputHexagonCut : resolvedSettingsManager.overlayHexagonCut;
        }
        return role === "input" ? 14 : 36;
    }

    readonly property real halfBorder: borderWidth / 2

    // Effective chamfer for the hexagon shape. Defined on the root so both
    // the shape itself and downstream content can reference the same value.
readonly property real hexCutEffective: {
        if (effectiveShape !== "hexagon") return 0;
        // Chamfer constraints, in order of priority:
        //   byHeight — never eat more than 30% of the height. At 45% the
        //              flat vertical band collapses on short rows (46–80px)
        //              and the shape degenerates into a chevron/arrow.
        //   byWidth  — never eat more than 15% of the width.
        //   byContentH — leave room for a minimum flat top/bottom band.
        //                Sized generously for inputs so text isn't squeezed.
        var minFlatH = role === "input" ? 100 : 140;
        var byHeight   = Math.round(height * 0.30);
        var byWidth    = Math.round(width * 0.15);
        var byContentH = Math.max(0, (width - minFlatH) / 2);
        return Math.max(2, Math.min(hexCut, byHeight, byWidth, byContentH));
    }

    // Safe-area insets. Content placed at these margins is guaranteed to be
    // inside the visible shape outline, regardless of shape or size.
    readonly property real contentInsetH: effectiveShape === "hexagon" ? (hexCutEffective + halfBorder) : 0
    readonly property real contentInsetV: contentInsetH

    // Canonical content insets. Sibling content anchored at these margins
    // will always sit inside the visible shape, at any size, border width,
    // or chamfer setting. Mirrors SlantedBox's leftPadding/rightPadding API
    // so both shape primitives are interchangeable in layout code.
    readonly property real leftPadding:   contentInsetH + (role === "input" ? 8 : 12)
    readonly property real rightPadding:  leftPadding

    // Vertical insets only clear the border. The chamfer is a corner
    // feature, so the top and bottom edges of the hexagon are flat
    // between the corners and do not need to be inset by hexCutEffective.
    // Using contentInsetV here shrinks the usable height by ~2*hexCut
    // and clips short-field text at the top.
    readonly property real topPadding:    halfBorder + (role === "input" ? 6 : 10)
    readonly property real bottomPadding: topPadding
    readonly property real x1: (slantLeft === "Right") ? (slantWidth + halfBorder) : halfBorder
    readonly property real x2: (slantLeft === "Left") ? (slantWidth + halfBorder) : halfBorder
    readonly property real x3: (slantRight === "Left") ? (width - slantWidth - halfBorder) : (width - halfBorder)
    readonly property real x4: (slantRight === "Right") ? (width - slantWidth - halfBorder) : (width - halfBorder)

    // 1. Rounded Rectangle
    Rectangle {
        anchors.fill: parent
        visible: root.effectiveShape === "rounded"
        radius: root.radius
        color: root.color
        border.color: root.borderColor
        border.width: root.borderWidth
    }

    // 2. Slanted Parallelogram
    Shape {
        anchors.fill: parent
        visible: root.effectiveShape === "slant"

        ShapePath {
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth
            fillColor: root.color
            joinStyle: ShapePath.MiterJoin

            startX: root.x1
            startY: root.halfBorder
            PathLine { x: root.x3; y: root.halfBorder }
            PathLine { x: root.x4; y: root.height - root.halfBorder }
            PathLine { x: root.x2; y: root.height - root.halfBorder }
            PathLine { x: root.x1; y: root.halfBorder }
        }
    }

    // 3. Wide-Top Hexagon (Shape renders synchronously in the scene graph;
    //    frame whenever a delegate was recycled mid-scroll.)
    Shape {
        id: hexShape
        anchors.fill: parent
        visible: root.effectiveShape === "hexagon"

        // Chamfer size. Capped by height*0.45 to preserve the hexagon
        // silhouette, and additionally by 20% of the smaller dimension so
        // the corners never eat more space than the flat middle band can
        // offer to content laid out edge-to-edge (text, badges, chips).
        readonly property real c: root.hexCutEffective

        ShapePath {
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth
            fillColor: root.color
            joinStyle: ShapePath.MiterJoin

            startX: hexShape.c + root.halfBorder
            startY: root.halfBorder

            PathLine { x: hexShape.width  - hexShape.c - root.halfBorder; y: root.halfBorder }
            PathLine { x: hexShape.width  - root.halfBorder;             y: hexShape.c + root.halfBorder }
            PathLine { x: hexShape.width  - root.halfBorder;             y: hexShape.height - hexShape.c - root.halfBorder }
            PathLine { x: hexShape.width  - hexShape.c - root.halfBorder; y: hexShape.height - root.halfBorder }
            PathLine { x: hexShape.c + root.halfBorder;                  y: hexShape.height - root.halfBorder }
            PathLine { x: root.halfBorder;                               y: hexShape.height - hexShape.c - root.halfBorder }
            PathLine { x: root.halfBorder;                               y: hexShape.c + root.halfBorder }
            PathLine { x: hexShape.c + root.halfBorder;                  y: root.halfBorder }
        }
    }

}
