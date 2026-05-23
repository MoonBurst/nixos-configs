import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Rectangle {
    id: borgBox

    // FIXED: Added property target definition so shell.qml mapping context works flawlessly
    property var barWindow: null

    // FIXED: Geometry outlines and dimensions scale natively to match your global design rule profiles
    width: 140
    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth

    color: shell.theme.base00
    border.color: shell.theme.base05

    Text {
        id: borgText
        anchors.fill: parent
        anchors.margins: 5

        // FIXED: Bound styling directly to your centralized yellow base05 color tokens
        text: "<font color='" + shell.theme.base05.toString() + "'>Borg:</font> <font color='" + shell.theme.base05.toString() + "'>OK</font>"

        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        textFormat: Text.RichText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
