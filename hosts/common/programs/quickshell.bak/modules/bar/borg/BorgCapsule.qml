import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Rectangle {
    id: borgBox

    width: 140
    height: 35
    radius: 10
    border.width: 3

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    color: "black"
    border.color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"

    Text {
        id: borgText
        anchors.fill: parent
        anchors.margins: 5
        // FIXED: Swapped out 'white' for dynamic base05 / yellow to draw 'OK' in deep yellow
        text: (root && root.theme && root.theme.base05 !== undefined) 
            ? "<font color='" + root.theme.base05.toString() + "'>Borg:</font> <font color='" + root.theme.base05.toString() + "'>OK</font>"
            : "<font color='yellow'>Borg:</font> <font color='yellow'>OK</font>"
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        textFormat: Text.RichText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
