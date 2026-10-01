import QtQuick
import QtQuick.Layouts 1.15
import "../style"

Item {
    id: root

    property string label: "Toggle Feature"
    property bool checked: false
    property var theme: null
    property int fontSize: (theme && theme.overlayFontSize) ? Math.max(12, theme.overlayFontSize - 2) : 14

    signal toggled(bool newState)

    Layout.fillWidth: true
    implicitWidth: labelText.implicitWidth + badgePill.width + 30
    implicitHeight: Math.max(34, root.fontSize * 2.0)

    readonly property color base00: (theme && theme.base00) ? theme.base00 : "#11111b"
    readonly property color base05: (theme && theme.base05) ? theme.base05 : "yellow"
    readonly property color base0C: (theme && theme.base0C) ? theme.base0C : "#04f100"
    readonly property color base08: (theme && theme.base08) ? theme.base08 : "#ff5555"
    readonly property string fontFamily: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"

    RowLayout {
        anchors.fill: parent
        spacing: 14

        Text {
            id: labelText
            text: root.label
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            font.bold: true
            color: root.base05
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        // Solid badge button identical to bar's SHOW / HIDE
        SlantedBox {
            id: badgePill
            Layout.preferredWidth: 64
            Layout.preferredHeight: Math.max(26, root.fontSize * 1.6)
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

            slantLeft: "Left"
            slantRight: "Left"
            slantWidth: 8

            color: root.checked ? root.base0C : root.base08
            borderColor: root.checked ? root.base0C : root.base08
            borderWidth: 1

            Text {
                anchors.centerIn: parent
                text: root.checked ? "ON" : "OFF"
                font.family: root.fontFamily
                font.pixelSize: Math.max(11, root.fontSize - 3)
                font.bold: true
                color: "#000000"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.toggled(!root.checked);
                }
            }
        }
    }
}
