//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io
import Quickshell.Services.Pam

import "./modules/bar/unified" as UnifiedMonitor
import "./modules/overlays/rng" as RNG
import "./modules/overlays/recording" as Recording
import "./modules/overlays/magnify" as Magnify
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
import "./modules/bar/notify" as NotifyCapsule
import "./modules/bar/weather" as WeatherCapsule
import "./modules/bar/calendar" as CalendarCapsule
import "modules/lockscreen"

ShellRoot {
    id: shell

    property bool debug: false

    Theme {
        id: globalTheme
    }

    property alias theme: globalTheme

    readonly property var primaryScreen: Quickshell.screens.find(s => s.name === "DP-1")
    || Quickshell.screens.find(s => s.name.startsWith("eDP"))
    || Quickshell.screens[0]

    property bool debugNotifications: shell.debug
    property bool showHistoryMode: false
    property bool notificationsEnabled: true
    property int unreadCount: 0
    property var deferredNotificationsQueue: []

    onNotificationsEnabledChanged: {
        if (notificationsEnabled && deferredNotificationsQueue.length > 0) {
            backlogFlusherTimer.start();
        } else if (!notificationsEnabled) {
            backlogFlusherTimer.stop();
        }
    }

    onShowHistoryModeChanged: {
        if (showHistoryMode) {
            shell.unreadCount = 0;
        }
    }

    Timer {
        id: backlogFlusherTimer
        interval: 800
        repeat: true
        running: false
        onTriggered: {
            if (deferredNotificationsQueue.length > 0) {
                let mockNotif = deferredNotificationsQueue.shift();
                if (shell.unreadCount > 0) {
                    shell.unreadCount--;
                }
                if (notificationOverlay) {
                    notificationOverlay.handleNotification(mockNotif);
                }
            } else {
                backlogFlusherTimer.stop();
            }
        }
    }

    property string globalPasswordBuffer: ""
    property int passwordLength: 0
    property var shellRootRef: this

    function toggleWindow(windowObj) {
        if (windowObj) {
            windowObj.visible = !windowObj.visible
        }
    }

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
            anchors.leftMargin: shell.theme.globalPadding / 2
            anchors.rightMargin: shell.theme.globalPadding / 2
            color: shell.theme.base00
            radius: shell.theme.defaultCardRadius
            border.width: shell.theme.globalBorderWidth
            border.color: shell.theme.base03

            readonly property int capsuleHeight: height - (shell.theme.globalBorderWidth * 2) - 8
            readonly property int layoutSpacing: 5

            // LEFT SIDE
            Item {
                id: calendarContainer
                anchors.left: parent.left
                anchors.leftMargin: shell.theme.globalPadding
                anchors.verticalCenter: parent.verticalCenter
                width: 120
                height: mainBarContainer.capsuleHeight
                CalendarCapsule.Calendar {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: musicContainer
                anchors.left: calendarContainer.right
                anchors.leftMargin: mainBarContainer.layoutSpacing
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
                anchors.leftMargin: mainBarContainer.layoutSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: 130
                height: mainBarContainer.capsuleHeight
                AlarmCapsule.AlarmCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: weatherContainer
                anchors.left: alarmContainer.right
                anchors.leftMargin: mainBarContainer.layoutSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                height: mainBarContainer.capsuleHeight
                WeatherCapsule.Weather {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: unifiedContainer
                anchors.left: weatherContainer.right
                anchors.leftMargin: mainBarContainer.layoutSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: 125
                height: mainBarContainer.capsuleHeight
                UnifiedMonitor.UnifiedMonitor {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: notifyContainer
                anchors.left: unifiedContainer.right
                anchors.leftMargin: mainBarContainer.layoutSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: 180
                height: mainBarContainer.capsuleHeight
                NotifyCapsule.NotifyCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            // CENTER
            Item {
                id: clockContainer
                anchors.centerIn: parent
                width: 130
                height: mainBarContainer.capsuleHeight
                ClockCapsule.ClockCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: audioContainer
                anchors.right: clockContainer.left
                anchors.rightMargin: mainBarContainer.layoutSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                height: mainBarContainer.capsuleHeight
                SoundModule.AudioCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: micContainer
                anchors.left: clockContainer.right
                anchors.leftMargin: mainBarContainer.layoutSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                height: mainBarContainer.capsuleHeight
                SoundModule.MicCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            // RIGHT SIDE
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
                anchors.rightMargin: mainBarContainer.layoutSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: 155
                height: mainBarContainer.capsuleHeight
                RamCapsule.RamCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: gpuContainer
                anchors.right: ramContainer.left
                anchors.rightMargin: mainBarContainer.layoutSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: 295
                height: mainBarContainer.capsuleHeight
                GpuCapsule.GpuCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: cpuContainer
                anchors.right: gpuContainer.left
                anchors.rightMargin: mainBarContainer.layoutSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: 170
                height: mainBarContainer.capsuleHeight
                CpuCapsule.CpuCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }

            Item {
                id: netContainer
                anchors.right: cpuContainer.left
                anchors.rightMargin: mainBarContainer.layoutSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: 260
                height: mainBarContainer.capsuleHeight
                NetCapsule.NetCapsule {
                    anchors.fill: parent
                    barWindow: topBarWindow
                }
            }
        }
    }

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
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        LauncherModule.LauncherOverlay {
            id: launcherOverlay
            anchors.fill: parent
            shell: shell
            launcherWindow: launcherOverlayWindow
        }
    }

    Recording.Recording {
        id: recordingOverlay
    }

    Magnify.Magnify {
        id: magnifierOverlay
    }

    RNG.DiceRollerWindow {
        id: diceRollerWindowInstance
        shell: shell
    }

    Component.onCompleted: {
        LauncherModule.LauncherController.rng.diceWindowInstance = diceRollerWindowInstance;
    }

    PamContext {
        id: lockPam
        config: "quickshell"
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
        id: lockscreenHandler
        target: "lockscreen"
        function lock(): void { sessionLock.locked = true; }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcherOverlay.toggleLauncher(); }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { launcherOverlay.toggleClipboard(); }
    }

    IpcHandler {
        target: "todo"
        function toggle(): void { launcherOverlay.toggleTodo(); }
    }

    IpcHandler {
        target: "pass"
        function toggle(): void { launcherOverlay.togglePass(); }
    }

    IpcHandler {
        target: "rng"
        function toggle(): void { launcherOverlay.toggleRng(); }
    }

    Notifications.NotificationOverlay {
        id: notificationOverlay
        showHistoryMode: shell.showHistoryMode
        notificationsEnabled: shell.notificationsEnabled
        onShowHistoryModeChanged: shell.showHistoryMode = showHistoryMode
        onNotificationsEnabledChanged: shell.notificationsEnabled = notificationsEnabled
    }
}
