//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io
import Quickshell.Services.Pam

import "./modules/overlays/notifications" as Notifications
import "./modules/overlays/quickshot" as Quickshot
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
import "./modules/bar/calendar" as CalendarCapsule
import "modules/lockscreen"

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

    property bool debugNotifications: true

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

        implicitHeight: shell.theme.globalPadding + 25

        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: mainBarContainer

            anchors.fill: parent
            //   anchors.topMargin: shell.theme.globalPadding
            anchors.leftMargin: shell.theme.globalPadding / 2
            anchors.rightMargin: shell.theme.globalPadding / 2

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
                id: calendarContainer

                anchors.left: parent.left
                anchors.leftMargin: shell.theme.globalPadding
                anchors.verticalCenter: parent.verticalCenter

                width: 150
                height: mainBarContainer.capsuleHeight

                CalendarCapsule.Calendar {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: musicContainer

                anchors.left: calendarContainer.right
                anchors.leftMargin: shell.theme.globalPadding / 2
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
                anchors.leftMargin: shell.theme.globalPadding / 2
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
                anchors.leftMargin: shell.theme.globalPadding / 2
                anchors.verticalCenter: parent.verticalCenter

                width: 100
                height: mainBarContainer.capsuleHeight

                WeatherCapsule.Weather {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: borgContainer

                anchors.left: weatherContainer.right
                anchors.leftMargin: shell.theme.globalPadding / 2
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
                anchors.rightMargin: shell.theme.globalPadding / 2
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
                anchors.leftMargin: shell.theme.globalPadding / 2
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
                anchors.rightMargin: shell.theme.globalPadding
                anchors.verticalCenter: parent.verticalCenter
                width: trayContent.width
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
                anchors.rightMargin: shell.theme.globalPadding / 2
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
                anchors.rightMargin: shell.theme.globalPadding / 2
                anchors.verticalCenter: parent.verticalCenter

                width: 275
                height: mainBarContainer.capsuleHeight

                GpuCapsule.GpuCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: cpuContainer

                anchors.right: gpuContainer.left
                anchors.rightMargin: shell.theme.globalPadding / 2
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
                anchors.rightMargin: shell.theme.globalPadding / 2
                anchors.verticalCenter: parent.verticalCenter

                width: 250 // Expanded parent width to match NetCapsule.qml sizing
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
     * LOCKSCREEN DATA STORAGE & CENTRAL PAM ENGINE
     * =========================================================================
     */

    property string globalPasswordBuffer: ""
    property int passwordLength: 0
    property var shellRootRef: this

    PamContext {
        id: lockPam
        config: "login"

        onResponseRequiredChanged: {
            if (responseRequired) {
                lockPam.respond(shellRootRef.globalPasswordBuffer);
            }
        }

        onActiveChanged: {
            if (!active && !messageIsError && shellRootRef.globalPasswordBuffer !== "") {
                sessionLock.locked = false;
                shellRootRef.globalPasswordBuffer = "";
                shellRootRef.passwordLength = 0;
            } else if (!active && messageIsError) {
                shellRootRef.globalPasswordBuffer = "";
                shellRootRef.passwordLength = -1;
            }
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        onLockedChanged: {
            shellRootRef.globalPasswordBuffer = "";
            shellRootRef.passwordLength = 0;
        }

        surface: Component {
            LockScreen {
                lockSession: sessionLock
                rootRef: shellRootRef
            }
        }
    }

    IpcHandler {
        target: "lockscreen"
        function lock(): void {
            sessionLock.locked = true;
        }
    }

    /*
     * =========================================================================
     * GLOBAL LAUNCHER OVERLAY IPC TARGETS
     * =========================================================================
     */

    IpcHandler {
        target: "launcher"
        function open(): void {
            launcherOverlay.openLauncher()
        }
        function close(): void {
            launcherOverlay.closeOverlay()
        }
        function toggle(): void {
            launcherOverlay.toggleLauncher()
        }
    }

    IpcHandler {
        target: "clipboard"
        function open(): void {
            launcherOverlay.openClipboard()
        }
        function close(): void {
            launcherOverlay.closeOverlay()
        }
        function toggle(): void {
            launcherOverlay.toggleClipboard()
        }
    }

    IpcHandler {
        target: "todo"
        function open(): void {
            launcherOverlay.openTodo()
        }
        function close(): void {
            launcherOverlay.closeOverlay()
        }
        function toggle(): void {
            launcherOverlay.toggleTodo()
        }
    }

    IpcHandler {
        target: "pass"
        function open(): void {
            launcherOverlay.openPass()
        }
        function close(): void {
            launcherOverlay.closeOverlay()
        }
        function toggle(): void {
            launcherOverlay.togglePass()
        }
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

                console.log("APP:", notification.desktopEntry || notification.appName)
                console.log("SUMMARY:", notification.summary)
                console.log("BODY:", notification.body)

                // CORRECTED FOR QUICKSHELL NATIVE C++ IMPLEMENTATION
                if (notification.actions && notification.actions.length > 0) {
                    for (let i = 0; i < notification.actions.length; ++i) {
                        const act = notification.actions[i]

                        if (!act) {
                            continue
                        }

                        console.log(
                            "ACTION:",
                            act.identifier, // Reverted to Quickshell native 'identifier'
                            act.text        // Quickshell native 'text'
                        )
                    }
                } else {
                    console.log("ACTIONS: None available")
                }

                if (notification.hints) {
                    for (let hintKey in notification.hints) {
                        try {
                            console.log(
                                "HINT:",
                                hintKey,
                                JSON.stringify(notification.hints[hintKey])
                            )
                        } catch (e) {
                            console.log("HINT:", hintKey, "[binary]")
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

            let topScope = notificationServer.parent

            if (topScope && topScope.cardComponentTemplate) {

                // Pass the notification object straight into the template's initial properties
                let popupCard = topScope.cardComponentTemplate.createObject(
                    topScope, {
                        notification: notification
                    }
                )

                if (topScope.activeNotifications) {
                    // Push the clean raw component right into the array deck
                    topScope.activeNotifications.push(popupCard)
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
