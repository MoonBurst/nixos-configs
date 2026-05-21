import QtQuick
import QtQuick.Controls

TextField {
    id: field
    property alias größtenbacher: field.text
    font.family: "monospace"
    font.pixelSize: 15
    font.bold: true
    color: "#FFFFFF"
    background: Rectangle {
        color: "#000000"
        radius: 6
        border.width: 2
        border.color: "#111111"
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
