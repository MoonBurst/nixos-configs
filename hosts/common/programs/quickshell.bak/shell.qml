import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

import "./modules/overlays/notifications" as Notifications
import "./modules/bar/tray" as SystemTray
import "./modules/bar/ram" as RamCapsule

ShellRoot {
    id: shell

    // ============================================================================
    // GLOBAL THEME PROVIDER OBJECT
    // ============================================================================
    Theme {
        id: globalTheme
    }

    property alias theme: globalTheme

    // ============================================================================
    // TOP STATUS BAR (MONITOR: DP-1 ONLY)
    // ============================================================================
    PanelWindow {
        id: topBarWindow

        screen: Quickshell.screens.find(s => s.name === "DP-1")

        anchors.top: true
        anchors.left: true
        anchors.right: true

        implicitHeight: 50 + shell.theme.globalPadding

        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Main Bar Layout Wrapper
        Rectangle {
            id: mainBarContainer

            anchors.fill: parent
            anchors.topMargin: shell.theme.globalPadding
            anchors.leftMargin: shell.theme.globalPadding
            anchors.rightMargin: shell.theme.globalPadding

            color: shell.theme.base00
            radius: shell.theme.defaultCardRadius
            border.width: shell.theme.globalBorderWidth
            border.color: shell.theme.base03

            // Left/Center Content Placeholder
            Text {
                text: "Status Bar"
                color: shell.theme.base05
                font.family: shell.theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                anchors.left: parent.left
                anchors.leftMargin: shell.theme.globalPadding
                anchors.verticalCenter: parent.verticalCenter
            }

            // ============================================================================
            // SYSTEM TRAY CONTAINER (FAR RIGHT)
            // ============================================================================
            Item {
                id: trayContainer

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right

                anchors.rightMargin: shell.theme.globalPadding + 20

                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8
                width: trayContent.childrenRect.width + 24 + (shell.theme.globalBorderWidth * 2)

                SystemTray.Tray {
                    id: trayContent
                    anchors.centerIn: parent
                }
            }

            // ============================================================================
            // RAM MODULE CONTAINER (LEFT OF TRAY)
            // ============================================================================
            Item {
                id: ramContainer

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: trayContainer.left

                // Placed cleanly to the left of the system tray with your 20px gap
                anchors.rightMargin: shell.theme.globalPadding

                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8

                // FIXED: Sets width to 175 to perfectly match the internal capsule footprint width
                width: 175

                RamCapsule.RamCapsule {
                    id: ramContent
                    anchors.fill: parent

                    // Feeds the bar window target context downwards to align the hover dropdown placement
                    barWindow: topBarWindow
                }
            }
        }
    }
}

    // ============================================================================
    // NOTIFICATION OVERLAY INFRASTRUCTURE
    // ============================================================================
    Notifications.NotificationOverlay {
        id: notificationOverlay
    }

    // ============================================================================
    // NOTIFICATION SERVER CORE SERVICE
    // ============================================================================
    NotificationServer {
        id: notificationServer

        bodyMarkupSupported: true
        imageSupported: true

        onNotification: function(notification) {
            console.log(
                "Notification received:",
                notification.summary
            )

            notificationOverlay.handleNotification(notification)
        }
    }
}
