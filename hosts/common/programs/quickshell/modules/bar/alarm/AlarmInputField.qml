import QtQuick
import QtQuick.Controls
import "../.config/quickshell/Theme.qml" as Theme

TextField {
    id: field
    property alias text: field.text
    font.family: "monospace"
    font.pixelSize: 20
    font.bold: true
    color: Theme.base05

    background: Rectangle {
        color: Theme.base01
        radius: 6
        border.width: 2
        border.color: Theme.base03
    }

    signal rejected

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            rejected()
            event.accepted = true
        }
    }

    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(background, field);
        }
    }
}
