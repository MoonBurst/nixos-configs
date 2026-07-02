// modules/style/SlantedBox.qml
import QtQuick
import QtQuick.Shapes 1.15

Item {
    id: root

    // Customizable properties
    property string slantLeft: "None"
    property string slantRight: "None"
    property color color: shell.theme.base00
    property color borderColor: shell.theme.base05
    property real borderWidth: shell.theme.globalBorderWidth

    // Calculated Helpers
    readonly property int slantWidth: shell.theme.slantWidth
    readonly property real halfBorder: borderWidth / 2

    // Optimised: Reclaims text space by only padding enough to safely clear the slant (slantWidth + 6px safety gap)
    readonly property int leftPadding: slantLeft === "None" ? shell.theme.globalPadding : (slantWidth + 6)
    readonly property int rightPadding: slantRight === "None" ? shell.theme.globalPadding : (slantWidth + 6)

    // Points Math
    property real x1: (slantLeft === "Right") ? (slantWidth + halfBorder) : halfBorder
    property real x2: (slantLeft === "Left") ? (slantWidth + halfBorder) : halfBorder
    property real x3: (slantRight === "Left") ? (width - slantWidth - halfBorder) : (width - halfBorder)
    property real x4: (slantRight === "Right") ? (width - slantWidth - halfBorder) : (width - halfBorder)

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
