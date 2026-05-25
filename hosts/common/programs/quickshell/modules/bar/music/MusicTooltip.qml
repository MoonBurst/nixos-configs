import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    implicitWidth: 400
    implicitHeight: 180

    radius: shell.theme.defaultCardRadius ?? 8
    border.width: shell.theme.globalBorderWidth ?? 3
    color: shell.theme.base00 ?? "black"
    border.color: shell.theme.base05 ?? "yellow"

    // Property storage flags populated dynamically by the parent capsule
    property string fullTrack: "Loading..."
    property string artistName: "Unknown Artist"

    // Media Interaction Process execution anchors
    Process { id: playPauseProc; command: ["playerctl", "play-pause"] }
    Process { id: prevProc; command: ["playerctl", "previous"] }
    Process { id: nextProc; command: ["playerctl", "next"] }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // ============================================================================
        // TRACK DETAILS SECTION (Centered Bubble Block)
        // ============================================================================
        Rectangle {
            width: parent.width
            height: 70
            radius: shell.theme.defaultCardRadius ?? 8
            border.width: shell.theme.globalBorderWidth ?? 3
            color: "transparent"
            border.color: root.border.color

            Column {
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 4

                Text {
                    width: parent.width
                    text: root.fullTrack
                    font.family: shell.theme.fontFamily ?? "monospace"
                    font.pixelSize: 18
                    font.bold: true
                    color: root.border.color
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.artistName
                    font.family: shell.theme.fontFamily ?? "monospace"
                    font.pixelSize: 14
                    color: root.border.color
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }

        // ============================================================================
        // INTERACTIVE CONTROL BUTTON ROW
        // ============================================================================
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            Repeater {
                model: [
                    { icon: "⏮", proc: prevProc },
                    { icon: "⏯", proc: playPauseProc },
                    { icon: "⏭", proc: nextProc }
                ]

                delegate: Rectangle {
                    width: 60
                    height: 40
                    radius: shell.theme.defaultCardRadius ?? 4
                    border.width: shell.theme.globalBorderWidth ?? 2
                    color: "transparent"
                    border.color: root.border.color

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        font.pixelSize: 20
                        color: parent.border.color
                    }

                    TapHandler {
                        onTapped: modelData.proc.running = true
                    }
                }
            }
        }
    }
}
