import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: window
            required property var modelData
            screen: modelData

            property bool active: false

            // Overlay layer
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "recording-indicator"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Position in top-right corner
            anchors {
                top: true
                right: true
            }

            margins {
                top: 16
                right: 16
            }

            implicitWidth: 32
            implicitHeight: 32
            color: "transparent"

            visible: active

            // Fix: '[r]tmp' prevents pgrep from matching its own sub-shell command
            Process {
                id: checkProcess
                command: ["sh", "-c", "pgrep -x wf-recorder >/dev/null || pgrep -f '[r]tmp://live.twitch.tv' >/dev/null"]
                running: false

                onExited: (code, status) => {
                    window.active = (code === 0);
                }
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    if (!checkProcess.running) {
                        checkProcess.running = true;
                    }
                }
            }

            Process {
                id: stopProcess
                running: false
            }

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: "#33000000"

                Rectangle {
                    id: redDot
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    color: "#FF3333"

                    SequentialAnimation on opacity {
                        running: window.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.2; duration: 750; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.2; to: 1.0; duration: 750; easing.type: Easing.InOutSine }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        stopProcess.command = ["sh", "-c", "twitch-stream || record-region"];
                        stopProcess.running = true;
                    }
                }
            }
        }
    }
}
