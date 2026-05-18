import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            WlrLayershell.layer: WlrLayershell.Top
            WlrLayershell.namespace: "quickshell-bar"
            
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            
            height: 40
            color: "#111111"


            Row {
                anchors.centerIn: parent
                spacing: 15

                CpuCapsule {}
                GpuCapsule {}
                RamCapsule {}
                NetCapsule {}
                AudioCapsule {}
                AlarmCapsule {}
            }
        }


        PanelWindow {
            id: notificationWindow
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.namespace: "quickshell-notifications"
            
            WlrLayershell.margins.top: 50
            WlrLayershell.margins.right: 20
            
            anchors.top: parent.top
            anchors.right: parent.right
            
            width: 320
            height: 400
            color: "transparent"

            Item {
                anchors.fill: parent

                NotificationServer {
                    id: notifServer
                }

                ListView {
                    id: notificationList
                    anchors.fill: parent
                    model: notifServer.trackedNotifications

                    onCountChanged: {
                        console.log("--> Current Live Count in Model: " + count)
                    }

                    delegate: Rectangle {
                        width: parent.width
                        height: 60
                        color: "#222222"
                        border.color: "#444444"
                        border.width: 1
                        radius: 8

                        Text {
                            anchors.centerIn: parent
                            color: "#ffffff"
                            text: (modelData.summary || "Notification") + " - " + (modelData.body || "")
                        }
                    }
                }
            }
        }
    }
}
