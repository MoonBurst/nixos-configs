import QtQuick
import QtQuick.Shapes 1.15

Item {
    id: root
    // Options: "Left" (\), "Right" (/), or "None" (|)
    property string slantLeft: "Left"
    property string slantRight: "Left"
    property color color: (shell && shell.theme) ? (shell.theme.base00 || "black") : "black"
    property color borderColor: (shell && shell.theme) ? (shell.theme.base05 || "yellow") : "yellow"
    property real borderWidth: (shell && shell.theme) ? (shell.theme.globalBorderWidth || 3) : 3
    property int slantWidth: (shell && shell.theme) ? (shell.theme.slantWidth || 12) : 12

    // padding helpers
    readonly property int leftPadding: slantLeft === "None" ? ((shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12) : (slantWidth + 6)
    readonly property int rightPadding: slantRight === "None" ? ((shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12) : (slantWidth + 6)
    readonly property real halfBorder: borderWidth / 2
    readonly property real slantRatio: (height > 0) ? (slantWidth / height) : 0.35
    readonly property real x1: (slantLeft === "Right") ? (slantWidth + halfBorder) : halfBorder
    readonly property real x2: (slantLeft === "Left") ? (slantWidth + halfBorder) : halfBorder
    readonly property real x3: (slantRight === "Left") ? (width - slantWidth - halfBorder) : (width - halfBorder)
    readonly property real x4: (slantRight === "Right") ? (width - slantWidth - halfBorder) : (width - halfBorder)

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

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
}
