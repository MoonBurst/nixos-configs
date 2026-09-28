import QtQuick
import QtQuick.Layouts 1.15
import "../style"

Item {
    id: root

    property string label: "Toggle Feature"
    property bool checked: false
    property var theme: null

    signal toggled(bool newState)

    implicitWidth: 260
    implicitHeight: 36

    readonly property color base00: (theme && theme.base00) ? theme.base00 : "#11111b"
    readonly property color base02: (theme && theme.base02) ? theme.base02 : "#313244"
    readonly property color base03: (theme && theme.base03) ? theme.base03 : "#45475a"
    readonly property color base05: (theme && theme.base05) ? theme.base05 : "yellow"
    readonly property color base0C: (theme && theme.base0C) ? theme.base0C : "#a6e3a1"
    readonly property color base08: (theme && theme.base08) ? theme.base08 : "#f38ba8"
    readonly property string fontFamily: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"

    RowLayout {
        anchors.fill: parent
        spacing: 10

        Text {
            text: root.label
            font.family: root.fontFamily
            font.pixelSize: 13
            font.bold: true
            color: root.base05
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Item {
            width: 58
            height: 24

            SlantedBox {
                anchors.fill: parent
                slantLeft: "Left"
                slantRight: "Left"
                slantWidth: 8
                color: root.checked ? root.base00 : root.base02
                borderColor: root.checked ? root.base0C : root.base03
                borderWidth: 1.5

                Rectangle {
                    x: root.checked ? (parent.width - width - 4) : 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 16
                    radius: 3
                    color: root.checked ? root.base0C : root.base08

                    Behavior on x {
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.checked ? "ON" : "OFF"
                        font.family: root.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        color: root.base00
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.checked = !root.checked;
                    root.toggled(root.checked);
                }
            }
        }
    }
}
