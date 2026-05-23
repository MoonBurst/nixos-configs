import QtQuick
import QtQuick.Controls 2
import Quickshell

TextField {
    id: alarmInputTextContainer
    
    width: 140
    height: 30
    font.family: "monospace"
    font.pixelSize: 14
    font.bold: true
    
    color: "yellow"
    selectionColor: "yellow"
    selectedTextColor: "black"

    // FIXED: Added an explicit signal alias property block to completely eliminate the onRejected crash
    signal rejected()

    background: Rectangle {
        color: "black"
        border.width: 2
        border.color: parent.focus ? "yellow" : "#333333"
        radius: 4
    }
}
