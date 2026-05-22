import QtQuick
import QtQuick.Controls
import Theme

TextField {
    id: field
    property alias text: field.text

    width: parent ? parent.width : 220
    implicitHeight: 32

    padding: 0
    topPadding: 0
    bottomPadding: 0
    leftPadding: 10
    rightPadding: 10

    font.family: "monospace"
    font.pixelSize: 15
    font.bold: true
    verticalAlignment: TextInput.AlignVCenter
    horizontalAlignment: TextInput.AlignHCenter

    // Explicitly guards the variable reference scope to prevent undefined assignment loops
    color: (typeof Theme !== 'undefined' && Theme && Theme.base05 !== undefined) ? Theme.base05 : "#F7F700"

    background: Rectangle {
        id: fieldBg
        color: (typeof Theme !== 'undefined' && Theme && Theme.base01 !== undefined) ? Theme.base01 : "#0F0F0F"
        radius: 6
        border.width: 2
        border.color: (typeof Theme !== 'undefined' && Theme && Theme.base03 !== undefined) ? Theme.base03 : "#003399"
    }

    Component.onCompleted: {
        if (typeof root !== 'undefined' && typeof root.applyCapsuleTheme !== 'undefined') {
            root.applyCapsuleTheme(fieldBg, field);
            field.font.pixelSize = 15;
            field.height = 32;
        }
    }

    signal rejected

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            rejected()
            event.accepted = true
        }
    }
}
