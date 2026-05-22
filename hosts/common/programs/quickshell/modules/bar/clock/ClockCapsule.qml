import QtQuick
import QtQuick.Controls 2
import Quickshell

Rectangle {
    id: clockCapsule

    width: 145
    height: 35
    radius: 10
    border.width: 3

    color: "black"
    border.color: "yellow"

    property var barWindow: null
    property bool isHoveredExternal: false

    property string localTime: "---"
    SystemClock { id: systemTime; precision: SystemClock.Seconds }

    Binding {
        target: clockCapsule
        property: "localTime"
        value: systemTime.date ? Qt.formatDateTime(systemTime.date, "hh:mm:ss AP") : "---"
    }

    Text {
        id: timeText
        anchors.fill: parent
        anchors.margins: 5
        text: clockCapsule.localTime
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: "yellow"
    }
}
