import QtQuick
import QtQuick.Controls

FocusScope {
    id: rootScope
    
    property alias text: inputArea.text
    property alias placeholderText: placeholderLabel.text
    
    // Explicit signal definitions
    signal accepted()
    signal rejected()

    width: 280
    height: 36

    Rectangle {
        anchors.fill: parent
        color: "#222222"
        border.color: inputArea.activeFocus ? "#33FF33" : "#003399"
        border.width: 2
        radius: 6

        Text {
            id: placeholderLabel
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: "#555555"
            font.family: "monospace"
            font.pixelSize: 13
            visible: !inputArea.text && !inputArea.activeFocus
        }

        TextInput {
            id: inputArea
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: "#ffffff"
            font.family: "monospace"
            font.pixelSize: 14
            focus: true
            selectByMouse: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    event.accepted = true;
                    rootScope.accepted();
                } else if (event.key === Qt.Key_Escape) {
                    event.accepted = true;
                    rootScope.rejected();
                }
            }
        }
    }
}
