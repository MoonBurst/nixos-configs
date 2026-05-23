//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io


import "./modules/overlays/notifications" as Notifications
import "./modules/overlays/launcher" as LauncherModule
import "./modules/bar/tray" as SystemTray
import "./modules/bar/ram" as RamCapsule
import "./modules/bar/gpu" as GpuCapsule
import "./modules/bar/cpu" as CpuCapsule
import "./modules/bar/network" as NetCapsule
import "./modules/bar/clock" as ClockCapsule
import "./modules/bar/sound" as SoundModule
import "./modules/bar/music" as MusicCapsule
import "./modules/bar/alarm" as AlarmCapsule
import "./modules/bar/borg" as BorgCapsule
import "./modules/bar/weather" as WeatherCapsule

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
    // REUSABLE DASHBOARD INTERFACE CAPABILITIES (STATE CONTROLLERS)
    // ============================================================================
    function toggleApplicationLauncherDashboard() {
        if (launcherOverlayWindow) {
            launcherOverlayWindow.visible = !launcherOverlayWindow.visible;
        }
    }

    function toggleClipboardHistoryDashboard() {
        if (clipboardOverlayWindow) {
            clipboardOverlayWindow.visible = !clipboardOverlayWindow.visible;
        }
    }

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

            // ============================================================================
            // MUSIC MODULE CONTAINER (FAR LEFT SIDE)
            // ============================================================================
            Item {
                id: musicContainer

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: shell.theme.globalPadding

                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8
                width: 200

                MusicCapsule.Music {
                    id: musicContent
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            // ============================================================================
            // ALARM MODULE CONTAINER (RIGHT OF MUSIC)
            // ============================================================================
            Item {
                id: alarmContainer

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: musicContainer.right
                anchors.leftMargin: 10

                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8
                width: 140

                AlarmCapsule.AlarmCapsule {
                    id: alarmContent
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            // ============================================================================
            // WEATHER MODULE CONTAINER
            // ============================================================================
            Item {
                id: weatherContainer

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: alarmContainer.right
                anchors.leftMargin: 10

                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8
                width: 140

                WeatherCapsule.Weather {
                    id: weatherContent
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            // ============================================================================
            // BORG MODULE CONTAINER
            // ============================================================================
            Item {
                id: borgContainer
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: weatherContainer.right
                anchors.leftMargin: 10

                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8
                width: 140

                BorgCapsule.BorgCapsule {
                    id: borgContent
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            // ============================================================================
            // MAIN TIME CLOCK CONTAINER (PERFECTLY IN THE MIDDLE)
            // ============================================================================
            Item {
                id: clockContainer

                anchors.centerIn: parent

                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8
                width: 150

                ClockCapsule.ClockCapsule {
                    id: clockContent
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            // ============================================================================
            // AUDIO VOLUME MODULE CONTAINER (IMMEDIATELY LEFT OF CLOCK)
            // ============================================================================
            Item {
                id: audioContainer

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: clockContainer.left
                anchors.rightMargin: 10

                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8
                width: 140

                SoundModule.AudioCapsule {
                    id: audioContent
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }
            // ============================================================================
            // MICROPHONE MODULE CONTAINER (IMMEDIATELY RIGHT OF CLOCK)
            // ============================================================================
            Item {
                id: micContainer

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: clockContainer.right
                anchors.leftMargin: 10

                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8
                width: 140

                SoundModule.MicCapsule {
                    id: micContent
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            // ============================================================================
            // SYSTEM TRAY CONTAINER (FAR RIGHT)
            // ============================================================================
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

                    // THIS CRITICAL LINE FIXES THE PLATFORMMENUENTRY ERROR:
                    barWindow: topBarWindow
                }
            }

            // ============================================================================
            // RAM MODULE CONTAINER (LEFT OF TRAY)
            // ============================================================================
            Item {
                id: ramContainer

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: trayContainer.left
                anchors.rightMargin: 10

                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8
                width: 175

                RamCapsule.RamCapsule {
                    id: ramContent
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            // ============================================================================
            // GPU MODULE CONTAINER (LEFT OF RAM)
            // ============================================================================
            Item {
                id: gpuContainer
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: ramContainer.left
                anchors.rightMargin: 10
                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8
                width: 210
                GpuCapsule.GpuCapsule {
                    id: gpuContent
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            // ============================================================================
            // CPU MODULE CONTAINER (LEFT OF GPU)
            // ============================================================================
            Item {
                id: cpuContainer
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: gpuContainer.left
                anchors.rightMargin: 10
                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8
                width: 175
                CpuCapsule.CpuCapsule {
                    id: cpuContent
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            // ============================================================================
            // NETWORK MODULE CONTAINER (LEFT OF CPU)
            // ============================================================================
            Item {
                id: netContainer
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: cpuContainer.left
                anchors.rightMargin: 10
                height: parent.height - (shell.theme.globalBorderWidth * 2) - 8
                width: 200
                NetCapsule.NetCapsule {
                    id: netContent
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }
        }
    }

    // ============================================================================
    // STANDALONE INDEPENDENT OVERLAY COMPONENT INSTANCES
    // ============================================================================
    PanelWindow {
        id: launcherOverlayWindow

        visible: true

        screen: Quickshell.screens.find(s => s.name === "DP-1")

        anchors.top: true
        anchors.left: true
        anchors.right: true
        anchors.bottom: true

        color: "transparent"



        WlrLayershell.layer: WlrLayer.Overlay

        WlrLayershell.keyboardFocus:
        visible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

        LauncherModule.LauncherOverlay {
            id: launcherOverlay
            anchors.fill: parent
            shell: shell
            launcherWindow: launcherOverlayWindow
        }
    }

    LauncherModule.Clipboard {
        id: clipboardOverlayWindow
    }

    // ============================================================================
    // ROOT LEVEL INDEPENDENT NOTIFICATION LIFECYCLE CONTROLLER
    // ============================================================================
    // This allows the inner NotificationCardWindow elements to draw their own individual
    // click-through shapes cleanly without creating an un-clickable wall on your desktop screen!
    Notifications.NotificationOverlay {
        id: notificationOverlay
    }

    // ============================================================================
    // NOTIFICATION SERVER CORE SERVICE
    // ============================================================================
    NotificationServer {
        id: notificationServer

        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        actionsSupported: true
        keepOnReload: true

        onNotification: function(notification) {
            console.log(
                "Notification received:",
                notification.summary
            )

            notificationOverlay.handleNotification(notification)
        }
    }
    function handleNotification(notification) {
        console.log("======== NEW NOTIFICATION ========");
        console.log("Summary:", notification.summary);
        console.log("Body:", notification.body);
        console.log("App:", notification.appName);

        console.log(
            "Actions:",
            JSON.stringify(notification.actions)
        );

        if (notification.actions) {
            for (let i = 0; i < notification.actions.length; ++i) {
                let action = notification.actions[i];

                console.log(
                    "Action #" + i
                    + " identifier=" + action.identifier
                    + " text=" + action.text
                );
            }
        }

        let popupCard = cardComponentTemplate.createObject(root, {
            notification: notification
        });

        activeNotifications.push(popupCard);

        positionNotificationsDeck();

        rulesLoader.handleIncomingNotificationCues(notification);
    }
}
