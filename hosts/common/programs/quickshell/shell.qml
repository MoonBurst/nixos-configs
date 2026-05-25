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

    /*
     * =========================================================================
     * GLOBALS
     * =========================================================================
     */

    Theme {
        id: globalTheme
    }

    property alias theme: globalTheme

    readonly property
    var primaryScreen: Quickshell.screens.find(s => s.name === "DP-1")

    property bool debugNotifications: false

    /*
     * =========================================================================
     * HELPERS
     * =========================================================================
     */

    function toggleWindow(windowObj) {
        if (windowObj) {
            windowObj.visible = !windowObj.visible
        }
    }

    /*
     * =========================================================================
     * TOP BAR
     * =========================================================================
     */

    PanelWindow {
        id: topBarWindow

        screen: primaryScreen

        anchors.top: true
        anchors.left: true
        anchors.right: true

        implicitHeight: 50 + shell.theme.globalPadding

        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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

            readonly property int capsuleHeight: height - (shell.theme.globalBorderWidth * 2) - 8

            /*
             * ================================================================
             * LEFT SIDE
             * ================================================================
             */

            Item {
                id: musicContainer

                anchors.left: parent.left
                anchors.leftMargin: shell.theme.globalPadding
                anchors.verticalCenter: parent.verticalCenter

                width: 200
                height: mainBarContainer.capsuleHeight

                MusicCapsule.Music {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: alarmContainer

                anchors.left: musicContainer.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                width: 140
                height: mainBarContainer.capsuleHeight

                AlarmCapsule.AlarmCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: weatherContainer

                anchors.left: alarmContainer.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                width: 140
                height: mainBarContainer.capsuleHeight

                WeatherCapsule.Weather {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: borgContainer

                anchors.left: weatherContainer.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                width: 140
                height: mainBarContainer.capsuleHeight

                BorgCapsule.BorgCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            /*
             * ================================================================
             * CENTER
             * ================================================================
             */

            Item {
                id: clockContainer

                anchors.centerIn: parent

                width: 150
                height: mainBarContainer.capsuleHeight

                ClockCapsule.ClockCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: audioContainer

                anchors.right: clockContainer.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                width: 140
                height: mainBarContainer.capsuleHeight

                SoundModule.AudioCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: micContainer

                anchors.left: clockContainer.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                width: 140
                height: mainBarContainer.capsuleHeight

                SoundModule.MicCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            /*
             * ================================================================
             * RIGHT SIDE
             * ================================================================
             */

            Item {
                id: trayContainer

                anchors.right: parent.right
                anchors.rightMargin: shell.theme.globalPadding + 20

                anchors.verticalCenter: parent.verticalCenter

                implicitWidth: trayContent.childrenRect.width + 24

                width: implicitWidth

                height: mainBarContainer.capsuleHeight

                SystemTray.Tray {
                    id: trayContent

                    anchors.centerIn: parent

                    barWindow: topBarWindow
                }
            }

            Item {
                id: ramContainer

                anchors.right: trayContainer.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                width: 175
                height: mainBarContainer.capsuleHeight

                RamCapsule.RamCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: gpuContainer

                anchors.right: ramContainer.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                width: 210
                height: mainBarContainer.capsuleHeight

                GpuCapsule.GpuCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: cpuContainer

                anchors.right: gpuContainer.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                width: 175
                height: mainBarContainer.capsuleHeight

                CpuCapsule.CpuCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: netContainer

                anchors.right: cpuContainer.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                width: 200
                height: mainBarContainer.capsuleHeight

                NetCapsule.NetCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }
        }
    }

    /*
     * =========================================================================
     * LAUNCHER OVERLAY
     * =========================================================================
     */

    PanelWindow {
        id: launcherOverlayWindow

        visible: false

        screen: primaryScreen

        anchors.top: true
        anchors.left: true
        anchors.right: true
        anchors.bottom: true

        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay

        WlrLayershell.keyboardFocus: visible ?
        WlrKeyboardFocus.Exclusive :
        WlrKeyboardFocus.None

        LauncherModule.LauncherOverlay {
            id: launcherOverlay

            anchors.fill: parent

            shell: shell
            launcherWindow: launcherOverlayWindow
        }
    }

    /*
     * =========================================================================
     * CLIPBOARD OVERLAY
     * =========================================================================
     */

    LauncherModule.Clipboard {
        id: clipboardOverlayWindow
    }

    /*
     * =========================================================================
     * NOTIFICATION OVERLAY
     * =========================================================================
     */

    Notifications.NotificationOverlay {
        id: notificationOverlay
    }

    /*
     * =========================================================================
     * NOTIFICATION SERVER
     * =========================================================================
     */

    NotificationServer {
        id: notificationServer

        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        actionsSupported: true
        keepOnReload: true

        onNotification: notification => {

            /*
             * ================================================================
             * DEBUG LOGGING
             * ================================================================
             */

            if (shell.debugNotifications) {

                console.log("==================================================")
                console.log("NOTIFICATION DEBUG")
                console.log("==================================================")

                console.log("APP:", notification.appName)
                console.log("SUMMARY:", notification.summary)
                console.log("BODY:", notification.body)

                if (notification.actions?.values) {

                    for (
                        let i = 0; i < notification.actions.values.length;
                    ++i
                    ) {
                        const act =
                        notification.actions.values[i]

                        if (!act) {
                            continue
                        }

                        console.log(
                            "ACTION:",
                            act.identifier,
                            act.label || act.text || ""
                        )
                    }
                }

                if (notification.hints) {

                    for (let hintKey in notification.hints) {

                        try {

                            console.log(
                                "HINT:",
                                hintKey,
                                JSON.stringify(
                                    notification.hints[hintKey]
                                )
                            )

                        } catch (e) {

                            console.log(
                                "HINT:",
                                hintKey,
                                "[binary]"
                            )
                        }
                    }
                }

                console.log("==================================================")
            }

            /*
             * ================================================================
             * NOTIFICATION CARD CREATION
             * ================================================================
             */

            let topScope =
            notificationServer.parent

            if (
                topScope &&
                topScope.cardComponentTemplate
            ) {

                let popupCard =
                topScope.cardComponentTemplate.createObject(
                    topScope, {
                        notification: notification
                    }
                )

                if (topScope.activeNotifications) {
                    topScope.activeNotifications.push(
                        popupCard
                    )
                }

                if (topScope.positionNotificationsDeck) {
                    topScope.positionNotificationsDeck()
                }

                if (topScope.rulesLoader) {
                    topScope.rulesLoader.handleIncomingNotificationCues(
                        notification
                    )
                }
            }
        }
    }
}
