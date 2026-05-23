import QtQuick
import QtQuick.Controls 2
import Quickshell

// Natively loads your dynamic Nix-compiled color palette definitions

Rectangle {
    id: clockCapsule

    // Expanded width prevents the AM/PM marker string from clipping into the border
    width: 165
    height: 35
    radius: 10
    border.width: 3

    // Dynamically references your theme colors; falls back to black if uninitialized
    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"

    // Dynamically pulls your active base05 accent color from your Nix configuration setup
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

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

        // Dynamically applies your core Nix theme color to the clock digits
        color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"
    }
}
