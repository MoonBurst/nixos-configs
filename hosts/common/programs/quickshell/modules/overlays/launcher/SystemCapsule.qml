// modules/overlays/launcher/SystemCapsule.qml
import QtQuick
import QtQuick.Controls

Column {
    id: capsuleRoot
    width: parent.width
    spacing: 8

    // Styling context injected from parent
    property var shell

    // Interface properties
    property string label: ""
    property string valueText: ""
    property color valColor: "white"
    property real fillValue: 0.0 // Must be normalized between 0.0 and 1.0

    Item {
        width: parent.width
        height: 24

        Text {
            text: capsuleRoot.label
            color: shell.theme.base05
            font.pixelSize: 20
            font.bold: true
            font.family: shell.theme.fontFamily
            anchors.left: parent.left
        }
        Text {
            text: capsuleRoot.valueText
            color: capsuleRoot.valColor
            font.pixelSize: 20
            font.bold: true
            font.family: "JetBrains Mono"
            anchors.right: parent.right
        }
    }

    Rectangle {
        width: parent.width
        height: 12
        radius: 6
        color: shell.theme.base02
        clip: true

        Rectangle {
            width: parent.width * capsuleRoot.fillValue
            height: parent.height
            radius: 6
            color: capsuleRoot.valColor
            Behavior on width { NumberAnimation { duration: 300 } }
        }
    }
}
