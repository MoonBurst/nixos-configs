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
import "./modules/bar/notify" as NotifyCapsule
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

    // Master debug toggle (Set to false to turn off console logging)
    property bool debug: true

    Theme {
        id: globalTheme
    }

    property alias theme: globalTheme

    // Dynamic display auto-detection (Checks for DP-1, falls back to laptop eDP-1, or defaults to first available)
    readonly property var primaryScreen: Quickshell.screens.find(s => s.name === "DP-1")
    || Quickshell.screens.find(s => s.name.startsWith("eDP"))
    || Quickshell.screens[0]

    property bool debugNotifications: shell.debug

    // Master bridge properties to synchronize visual states across multi-window scopes (DP-1 / DP-2)
    property bool showHistoryMode: false
    property bool notificationsEnabled: true

    // Real-time unread/backlog notification counter (ONLY increments when paused/muted)
    property int unreadCount: 0

    // Master Backlog Deferral Queue: Holds notification pointers while muted
    property var deferredNotificationsQueue: []

    // Background Queue Flusher: Initiates the pacing timer when unmuted to show cards one-at-a-time
    onNotificationsEnabledChanged: {
        if (notificationsEnabled && deferredNotificationsQueue.length > 0) {
            if (shell.debug) console.log("DND disabled: Initiating paced backlog flusher for", deferredNotificationsQueue.length, "held notification(s)...");
            backlogFlusherTimer.start(); // Start the pacing timer
        } else if (!notificationsEnabled) {
            // Stop any active flusher if muted again
            backlogFlusherTimer.stop();
        }
    }

    // Reset master unread counts when showHistoryMode changes to clear indicators
    onShowHistoryModeChanged: {
        if (showHistoryMode) {
            shell.unreadCount = 0;
        }
    }

    // Paced Backlog Flusher Timer: Pops up one notification card every 800ms
    Timer {
        id: backlogFlusherTimer
        interval: 800 // 800ms delay between popups
        repeat: true
        running: false
        onTriggered: {
            if (deferredNotificationsQueue.length > 0) {
                // Pull the oldest deferred notification from the front of the queue
                let mockNotif = deferredNotificationsQueue.shift();

                // Decrement the backlog counter as it leaves the queue and pops up on DP-2
                if (shell.unreadCount > 0) {
                    shell.unreadCount--;
                }

                if (notificationOverlay) {
                    notificationOverlay.handleNotification(mockNotif);
                }
            } else {
                // Queue is completely empty, stop the timer
                backlogFlusherTimer.stop();
            }
        }
    }

    property string globalPasswordBuffer: ""
    property int passwordLength: 0
    property var shellRootRef: this

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
            Item {
                id: notifyContainer

                anchors.left: borgContainer.right
                anchors.leftMargin: shell.theme.globalPadding / 2
                anchors.verticalCenter: parent.verticalCenter

                width: 200 // Expanded from 140 to 200 to prevent long "Notifications:" text from clipping
                height: mainBarContainer.capsuleHeight

                NotifyCapsule.NotifyCapsule {
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

                width: 280 // Expanded parent width to match NetCapsule.qml sizing
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
        id: lockscreenHandler
        target: "lockscreen"
        function lock(): void {
            sessionLock.locked = true;
        }
    }

    /*
     * =========================================================================
     * GLOBAL LAUNCHER OVERLAY IPC TARGETS (Redundant single-action targets removed)
     * =========================================================================
     */

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            launcherOverlay.toggleLauncher()
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            launcherOverlay.toggleClipboard()
        }
    }

    IpcHandler {
        target: "todo"
        function toggle(): void {
            launcherOverlay.toggleTodo()
        }
    }

    IpcHandler {
        target: "pass"
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
        showHistoryMode: shell.showHistoryMode
        notificationsEnabled: shell.notificationsEnabled
        onShowHistoryModeChanged: shell.showHistoryMode = showHistoryMode
        onNotificationsEnabledChanged: shell.notificationsEnabled = notificationsEnabled
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
             * MASTER BACKLOG DEFERRAL ENGINE
             * ================================================================
             */

            // If muted/paused, bypass active popup windows entirely, record directly to history, and append to backlog queue
            if (!shell.notificationsEnabled) {
                let resolvedIcon = (notificationOverlay && notificationOverlay.rulesLoader) ? notificationOverlay.rulesLoader.getCustomIcon(notification) : ""
                let avatarVal = resolvedIcon ? resolvedIcon : "image://icon/" + (notification.desktopEntry || notification.appName || "").toLowerCase()

                let resolvedStr = resolvedIcon ? String(resolvedIcon) : ""
                let imageStr = notification.image ? String(notification.image) : ""

                let previewVal = ""
                let hints = notification.hints || {}
                let hintImagePath = hints["image-path"] || hints["image_path"] || hints["image-uri"] || hints["image-uri"] || ""

                if (hintImagePath === "") {
                    let attachmentUrls = hints["attachment-urls"] || hints["attachment_urls"] || hints["attachment-url"] || hints["attachment-url"] || ""
                    if (attachmentUrls !== "") {
                        let strUrls = String(attachmentUrls);
                        let firstUrl = notificationOverlay ? notificationOverlay.extractUrl(strUrls) : ""
                        if (firstUrl !== "") {
                            hintImagePath = firstUrl;
                        }
                    }
                }

                if (hintImagePath !== "") {
                    let strHint = String(hintImagePath);
                    if (strHint.startsWith("/") || strHint.startsWith("file://") || strHint.startsWith("http")) {
                        previewVal = strHint.startsWith("/") ? "file://" + strHint : strHint;
                    }
                }

                if (previewVal === "" && notificationOverlay) {
                    let bodyImageUrl = notificationOverlay.extractImageUrl(notification.body || "")
                    if (bodyImageUrl !== "") {
                        previewVal = bodyImageUrl
                    }
                }

                if (previewVal === "") {
                    if (notification.image && resolvedStr !== imageStr) {
                        previewVal = notification.image;
                    }
                }

                // Create a completely self-contained, stable mock notification object
                let mockNotif = {
                    "isMock": true,
                    "isDeDuplicated": true, // Flag to prevent closeNotificationTrack from creating duplicate history list entries
                    "id": notification.id,
                    "appName": notification.desktopEntry || notification.appName || "",
                    "appIcon": notification.appIcon || "",
                    "summary": notification.summary || "",
                    "body": notification.body || "",
                    "icon": avatarVal,     // Store the stable, resolved avatar filepath
                    "image": previewVal,   // Store the stable, resolved preview filepath/URL
                    "urgency": notification.urgency || 1,
                    "hints": notification.hints || ({})
                }

                if (notificationOverlay) {
                    notificationOverlay.recordHistoryDirect(notification)
                }
                shell.deferredNotificationsQueue.push(mockNotif)
                shell.unreadCount++ // Increment the master backlog count
                notification.dismiss()
                return
            }

            let topScope = notificationServer.parent

            if (topScope && topScope.cardComponentTemplate) {

                // Pass the notification object straight into the template's initial properties
                // FIXED: Injects required 'rulesLoader', 'rootItem', and 'controller' bindings standardly
                let popupCard = topScope.cardComponentTemplate.createObject(
                    topScope, {
                        notification: notification,
                        rulesLoader: topScope.rulesLoader,
                        rootItem: topScope,
                        controller: topScope.notificationIPC
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
