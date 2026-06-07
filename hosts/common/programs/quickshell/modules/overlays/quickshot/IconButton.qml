import QtQuick

// A flat, square icon button used throughout the toolbar. Renders a glyph, a
// hover/checked background, and a small tooltip on hover.
Item {
    id: btn

    property string glyph: ""
    property string tip: ""
    property bool checked: false
    property color tint: Style.accent
    property real glyphSize: 18

    signal clicked()

    implicitWidth: Style.buttonSize
    implicitHeight: Style.buttonSize

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Style.buttonRadius
        color: btn.checked ? btn.tint
                           : (mouse.containsMouse ? Style.panelRaised : "transparent")
        Behavior on color { ColorAnimation { duration: 90 } }
    }

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        font.family: Style.iconFamily
        font.pixelSize: btn.glyphSize
        color: btn.checked ? Style.accentText : Style.text
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }

    // ---- Tooltip -------------------------------------------------------------
    Rectangle {
        id: tooltip
        visible: opacity > 0
        opacity: (mouse.containsMouse && btn.tip.length > 0) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        anchors.bottom: parent.top
        anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter

        width: tipText.implicitWidth + 16
        height: tipText.implicitHeight + 10
        radius: 6
        color: "#0d0e13"
        border.color: Style.panelBorder
        z: 1000

        Text {
            id: tipText
            anchors.centerIn: parent
            text: btn.tip
            color: Style.text
            font.family: Style.fontFamily
            font.pixelSize: 12
        }
    }
}
