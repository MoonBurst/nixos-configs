import QtQuick
import QtQuick.Shapes 1.15

Item {
    id: root

    property string shapeType: "auto"
    property string role: "card" // "card" or "input"

    // Allow callers to either set slantWidth directly or let it follow the global angle slider
    property int slantWidth: effectiveSlantWidth
    property int hexCut: effectiveHexCut

    readonly property string effectiveShape: {
        if (shapeType !== "auto" && shapeType !== "") return shapeType;
        if (typeof shell !== "undefined" && shell && shell.settingsManager) {
            return role === "input" ? shell.settingsManager.inputFieldShape : shell.settingsManager.overlayCardShape;
        }
        return "rounded";
    }

    property color color: (typeof shell !== "undefined" && shell && shell.theme) ? (shell.theme.base00 || "#11111b") : "#11111b"
    property color borderColor: (typeof shell !== "undefined" && shell && shell.theme) ? (shell.theme.base05 || "yellow") : "yellow"
    property real borderWidth: (typeof shell !== "undefined" && shell && shell.theme && shell.theme.globalBorderWidth !== undefined) ? shell.theme.globalBorderWidth : 2
    property real radius: (typeof shell !== "undefined" && shell && shell.theme && shell.theme.defaultCardRadius !== undefined) ? shell.theme.defaultCardRadius : 10

    property string slantLeft: "Left"
    property string slantRight: "Right"

    readonly property int effectiveSlantWidth: {
        if (typeof shell !== "undefined" && shell && shell.settingsManager) {
            return role === "input" ? shell.settingsManager.inputSlantAngle : shell.settingsManager.overlaySlantAngle;
        }
        return role === "input" ? 14 : 32;
    }

    readonly property int effectiveHexCut: {
        if (typeof shell !== "undefined" && shell && shell.settingsManager) {
            return role === "input" ? shell.settingsManager.inputHexagonCut : shell.settingsManager.overlayHexagonCut;
        }
        return role === "input" ? 14 : 36;
    }

    readonly property real halfBorder: borderWidth / 2
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

    // 3. Wide-Top Hexagon
    Canvas {
        id: hexCanvas
        anchors.fill: parent
        visible: root.effectiveShape === "hexagon"

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.lineWidth = root.borderWidth;
            ctx.strokeStyle = root.borderColor;
            ctx.fillStyle = root.color;

            var w = width, h = height;
            var c = Math.max(4, Math.min(Math.round(h * 0.45), root.hexCut));

            ctx.beginPath();
            ctx.moveTo(c, root.halfBorder);
            ctx.lineTo(w - c, root.halfBorder);
            ctx.lineTo(w - root.halfBorder, c);
            ctx.lineTo(w - root.halfBorder, h - c);
            ctx.lineTo(w - c, h - root.halfBorder);
            ctx.lineTo(c, h - root.halfBorder);
            ctx.lineTo(root.halfBorder, h - c);
            ctx.lineTo(root.halfBorder, c);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
        }

        onVisibleChanged: if (visible) requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: root
            function onBorderColorChanged() { hexCanvas.requestPaint(); }
            function onColorChanged() { hexCanvas.requestPaint(); }
            function onBorderWidthChanged() { hexCanvas.requestPaint(); }
            function onHexCutChanged() { hexCanvas.requestPaint(); }
            function onSlantWidthChanged() { hexCanvas.requestPaint(); }
        }
    }
}
