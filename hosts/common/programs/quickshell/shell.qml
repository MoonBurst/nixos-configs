import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io
import Quickshell.Services.Pam

import "./modules/settings" as Settings
import "./modules/style" as Style
import "./modules/bar/unified" as UnifiedMonitor
import "./modules/overlays/rng" as RNG
import "./modules/overlays/amogus" as AmogusModule
import "./modules/overlays/magnify" as Magnify
import "./modules/overlays/notifications" as Notifications

// Specific Overlay Module Folders
import "./modules/overlays/launcher" as AppLauncherModule
import "./modules/overlays/calc" as CalcModule
import "./modules/overlays/clipboard" as ClipboardModule
import "./modules/overlays/dictionary" as DictionaryModule
import "./modules/overlays/unicode" as UnicodeModule
import "./modules/overlays/notes" as NotesModule
import "./modules/overlays/pass" as PassModule
import "./modules/overlays/power" as PowerModule
import "./modules/overlays/todo" as TodoModule
import "./modules/overlays/gemini" as GeminiModule
import "./modules/overlays/settings" as SettingsWindowModule
import "./modules/overlays/email" as EmailModule
import "./modules/overlays/websearch" as WebSearchModule

import "./modules/bar/tray" as SystemTray
import "./modules/bar/battery" as BatteryCapsule
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

    Process {
        id: ipcPathRegistrar
        running: false
        command: [
            "sh", "-c",
            'echo "$1" > "${XDG_RUNTIME_DIR:-/tmp}/quickshell-path"',
            "sh",
            Quickshell.shellDir
        ]
    }

    Process {
        id: tmpCacheCleaner
        running: false
        command: ["sh", "-c", "rm -f /tmp/qs_avatar_notif_*.png /tmp/quickshot_crop_*.png /tmp/qs_dict*.json 2>/dev/null || true"]
    }

    Settings.SettingsManager {
        id: settingsManagerInstance
    }

    property alias settingsManager: settingsManagerInstance
    property alias notificationOverlay: notificationOverlay
    property alias diceRollerWindowInstance: diceRollerWindowInstance
    property alias amogusWindowInstance: amogusWindowInstance
    property alias lockPam: lockPam
    property alias sessionLock: sessionLock

    // Direct handles for mutual exclusivity and fast in-memory switching
    property alias appLauncherWindow: appLauncherWindow
    property alias calcWindow: calcWindow
    property alias clipboardWindow: clipboardWindow
    property alias dictionaryWindow: dictionaryWindow
    property alias unicodeWindow: unicodeWindow
    property alias notesWindow: notesWindow
    property alias passWindow: passWindow
    property alias powerWindow: powerWindow
    property alias todoWindow: todoWindow
    property alias geminiWindow: geminiWindow
    property alias settingsWindow: settingsWindow
    property alias emailWindow: emailWindow
    property alias startPageWindow: startPageWindow

    function closeOtherOverlays(activeWin) {
        var previewTarget = settingsManagerInstance ? settingsManagerInstance.previewWindow : "";
        var list = [
            appLauncherWindow, calcWindow, clipboardWindow, dictionaryWindow,
            unicodeWindow, notesWindow, passWindow, powerWindow,
            todoWindow, geminiWindow, settingsWindow, emailWindow,
            startPageWindow, diceRollerWindowInstance, amogusWindowInstance
        ];

        for (var i = 0; i < list.length; i++) {
            var w = list[i];
            if (!w || w === activeWin) continue;

            // Preserve settings and the currently previewed window together
            if (previewTarget !== "") {
                if (w === settingsWindow) continue;
                if (w.windowId === previewTarget) continue;
            }

            if (w.visible) {
                if (typeof w.close === "function") w.close();
                else if (typeof w.hideWindow === "function") w.hideWindow();
                else w.visible = false;
            }
        }
    }

    QtObject {
        id: activeTheme

        property color base00: settingsManager.customBase00
        property color base01: globalTheme.base01
        property color base02: globalTheme.base02
        property color base03: settingsManager.customBase03
        property color base04: globalTheme.base04
        property color base05: settingsManager.customBase05
        property color base06: globalTheme.base06
        property color base07: globalTheme.base07
        property color base08: settingsManager.customBase08
        property color base09: settingsManager.customBase09
        property color base0A: globalTheme.base0A
        property color base0B: globalTheme.base0B
        property color base0C: settingsManager.customBase0C
        property color base0D: settingsManager.customBase0D
        property color base0E: globalTheme.base0E
        property color base0F: globalTheme.base0F

        property string fontFamily: globalTheme.fontFamily
        property int defaultCardWidth: 420
        property int defaultCardHeight: 140
        property int defaultCardRadius: 10
        property color innerBorderColor: base05
        property color outerBorderColor: base03
        property color scrollHandleColor: base0D

        property int globalFontSize: settingsManager.globalFontSize
        property int slantWidth: settingsManager.slantWidth
        property int globalBorderWidth: settingsManager.globalBorderWidth
        property int globalPadding: settingsManager.globalPadding
    }

    property alias theme: activeTheme

    Binding { target: shell; property: "notificationsEnabled"; value: settingsManager.notificationsEnabled }

    readonly property var primaryScreen: {
        const screens = Quickshell.screens;
        if (!screens || screens.length === 0) return null;
        return screens.find(s => s.name === "DP-1")
            ?? screens.find(s => s.name.startsWith("eDP"))
            ?? screens[0] ?? null;
    }

    property bool showHistoryMode: false
    property bool notificationsEnabled: true
    property int unreadCount: 0
    property var deferredNotificationsQueue: []

    property string globalPasswordBuffer: ""
    property int passwordLength: 0

    function applyCapsuleSlants(loadedItem, modelData, section) {
        if (!settingsManager) return;
        if (!loadedItem) return;
        var slantType = settingsManager ? settingsManager.getModuleSlant(modelData, section) : "left";
        var sLeft = "Left";
        var sRight = "Left";
        var tAlign = "Left";

        if (slantType === "left") {
            sLeft = "Left"; sRight = "Left"; tAlign = "Left";
        } else if (slantType === "right") {
            sLeft = "Right"; sRight = "Right"; tAlign = "Right";
        } else if (slantType === "center") {
            sLeft = "Left"; sRight = "Right"; tAlign = "Center";
        }

        try {
            if ("slantLeft" in loadedItem) loadedItem.slantLeft = sLeft;
            if ("slantRight" in loadedItem) loadedItem.slantRight = sRight;
            if ("tooltipAlign" in loadedItem) loadedItem.tooltipAlign = tAlign;

            for (var i = 0; i < loadedItem.children.length; i++) {
                var c = loadedItem.children[i];
                if (c && (c.id === "bg" || ("slantLeft" in c && "leftPadding" in c))) {
                    c.slantLeft = sLeft;
                    c.slantRight = sRight;
                }
            }
        } catch(e) {}
    }

    Component { id: calendarFactory; CalendarCapsule.Calendar { barWindow: topBarWindow } }
    Component { id: musicFactory; MusicCapsule.Music { barWindow: topBarWindow } }
    Component { id: alarmFactory; AlarmCapsule.AlarmCapsule { barWindow: topBarWindow } }
    Component { id: weatherFactory; WeatherCapsule.Weather { barWindow: topBarWindow } }
    Component { id: unifiedFactory; UnifiedMonitor.UnifiedMonitor { barWindow: topBarWindow } }
    Component { id: notifyFactory; NotifyCapsule.NotifyCapsule { barWindow: topBarWindow } }
    Component { id: clockFactory; ClockCapsule.ClockCapsule { barWindow: topBarWindow } }
    Component { id: audioFactory; SoundModule.AudioCapsule { barWindow: topBarWindow } }
    Component { id: micFactory; SoundModule.MicCapsule { barWindow: topBarWindow } }
    Component { id: netFactory; NetCapsule.NetCapsule { barWindow: topBarWindow } }
    Component { id: cpuFactory; CpuCapsule.CpuCapsule { barWindow: topBarWindow } }
    Component { id: gpuFactory; GpuCapsule.GpuCapsule { barWindow: topBarWindow } }
    Component { id: ramFactory; RamCapsule.RamCapsule { barWindow: topBarWindow } }
    Component { id: trayFactory; SystemTray.Tray { barWindow: topBarWindow } }
    Component { id: batteryFactory; BatteryCapsule.BatteryCapsule { barWindow: topBarWindow } }

    function getFactoryComponent(idStr) {
        var clean = idStr.toLowerCase();
        switch(clean) {
            case "calendar": return calendarFactory;
            case "music": return musicFactory;
            case "alarm": return alarmFactory;
            case "weather": return weatherFactory;
            case "unified": return unifiedFactory;
            case "notify":
            case "notifications": return notifyFactory;
            case "clock": return clockFactory;
            case "audio": return audioFactory;
            case "mic": return micFactory;
            case "net": return netFactory;
            case "cpu": return cpuFactory;
            case "gpu": return gpuFactory;
            case "ram": return ramFactory;
            case "tray": return trayFactory;
            case "battery": return batteryFactory;
        }
        return null;
    }

    PanelWindow {
        id: topBarWindow
        visible: !sessionLock.locked
        screen: primaryScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: (settingsManager && settingsManager.barHeight > 0)
            ? settingsManager.barHeight
            : (shell.theme.globalPadding + 32)
        color: "transparent"

        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Auto

        Style.SlantedBox {
            id: mainBarContainer
            anchors.fill: parent
            anchors.leftMargin: shell.theme.globalPadding / 2
            anchors.rightMargin: shell.theme.globalPadding / 2

            slantLeft: settingsManager.slantStyleMode === "all-right" ? "Right" : "Left"
            slantRight: settingsManager.slantStyleMode === "all-left" ? "Left" : "Right"

            slantWidth: shell.theme.slantWidth * 1.5
            color: shell.theme.base00
            borderColor: shell.theme.base03
            borderWidth: shell.theme.globalBorderWidth

            readonly property int capsuleHeight: height - (shell.theme.globalBorderWidth * 2) - 8

            // Left Section
            Row {
                anchors.left: parent.left
                anchors.leftMargin: mainBarContainer.leftPadding
                anchors.verticalCenter: parent.verticalCenter
                height: mainBarContainer.capsuleHeight
                spacing: settingsManager.capsuleSpacing

                Repeater {
                    model: settingsManager.barLeftModules
                    delegate: Loader {
                        id: leftLoader
                        height: parent.height
                        active: settingsManager.isCapsuleVisible(modelData)
                        visible: active
                        width: (active && item) ? item.implicitWidth : 0
                        sourceComponent: shell.getFactoryComponent(modelData)
                        onItemChanged: shell.applyCapsuleSlants(item, modelData, "left")
                        Component.onCompleted: shell.applyCapsuleSlants(item, modelData, "left")

                        Connections {
                            target: settingsManager
                            function onSlantRevisionChanged() { shell.applyCapsuleSlants(leftLoader.item, modelData, "left"); }
                        }
                    }
                }
            }

            // Center Section
            Row {
                anchors.centerIn: parent
                height: mainBarContainer.capsuleHeight
                spacing: settingsManager.capsuleSpacing

                Repeater {
                    model: settingsManager.barCenterModules
                    delegate: Loader {
                        id: centerLoader
                        height: parent.height
                        active: settingsManager.isCapsuleVisible(modelData)
                        visible: active
                        width: (active && item) ? item.implicitWidth : 0
                        sourceComponent: shell.getFactoryComponent(modelData)
                        onItemChanged: shell.applyCapsuleSlants(item, modelData, "center")
                        Component.onCompleted: shell.applyCapsuleSlants(item, modelData, "center")

                        Connections {
                            target: settingsManager
                            function onSlantRevisionChanged() { shell.applyCapsuleSlants(centerLoader.item, modelData, "center"); }
                        }
                    }
                }
            }

            // Right Section
            Row {
                anchors.right: parent.right
                anchors.rightMargin: mainBarContainer.rightPadding
                anchors.verticalCenter: parent.verticalCenter
                height: mainBarContainer.capsuleHeight
                spacing: settingsManager.capsuleSpacing
                layoutDirection: Qt.RightToLeft

                Repeater {
                    model: settingsManager.barRightModules
                    delegate: Loader {
                        id: rightLoader
                        height: parent.height
                        active: settingsManager.isCapsuleVisible(modelData)
                        visible: active
                        width: (active && item) ? item.implicitWidth : 0
                        sourceComponent: shell.getFactoryComponent(modelData)
                        onItemChanged: shell.applyCapsuleSlants(item, modelData, "right")
                        Component.onCompleted: shell.applyCapsuleSlants(item, modelData, "right")

                        Connections {
                            target: settingsManager
                            function onSlantRevisionChanged() { shell.applyCapsuleSlants(rightLoader.item, modelData, "right"); }
                        }
                    }
                }
            }
        }
    }

    // Modularized Standalone Overlay Windows
    AppLauncherModule.AppLauncherWindow       { id: appLauncherWindow;       shell: shell }
    CalcModule.CalcWindow                     { id: calcWindow;              shell: shell }
    ClipboardModule.ClipboardWindow           { id: clipboardWindow;         shell: shell }
    DictionaryModule.DictionaryWindow         { id: dictionaryWindow;        shell: shell }
    UnicodeModule.UnicodeWindow               { id: unicodeWindow;           shell: shell }
    NotesModule.NotesWindow                   { id: notesWindow;             shell: shell }
    PassModule.PassWindow                     { id: passWindow;              shell: shell }
    PowerModule.PowerWindow                   { id: powerWindow;             shell: shell }
    TodoModule.TodoWindow                     { id: todoWindow;              shell: shell }
    GeminiModule.GeminiWindow                 { id: geminiWindow;            shell: shell }
    SettingsWindowModule.SettingsWindow       { id: settingsWindow;          shell: shell }
    SettingsWindowModule.OverlayInspectorWindow { id: overlayInspectorWindow;  shell: shell }
    EmailModule.EmailWindow                   { id: emailWindow;             shell: shell }
    WebSearchModule.StartPageWindow           { id: startPageWindow;         shell: shell }

    Magnify.Magnify { id: magnifierOverlay }
    RNG.DiceRollerWindow { id: diceRollerWindowInstance; shell: shell }
    AmogusModule.AmogusWindow { id: amogusWindowInstance; shell: shell }

    Component.onCompleted: {
        ipcPathRegistrar.running = true;
        tmpCacheCleaner.running = true;
        pamServiceDetector.running = true;
    }

    property string activePamService: "login"
    Process {
        id: pamServiceDetector
        running: false
        command: ["sh", "-c", "[ -f /etc/pam.d/quickshell ] && echo 'quickshell' || echo 'login'"]
        stdout: SplitParser {
            onRead: data => { if (data && data.trim()) shell.activePamService = data.trim(); }
        }
    }

    PamContext {
        id: lockPam
        config: shell.activePamService
        user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
        onResponseRequiredChanged: {
            if (responseRequired) {
                lockPam.respond(shell.globalPasswordBuffer);
            }
        }
        onCompleted: (result) => {
            if (result === PamResult.Success) {
                sessionLock.locked = false;
                shell.globalPasswordBuffer = "";
                shell.passwordLength = 0;
            } else {
                shell.globalPasswordBuffer = "";
                shell.passwordLength = -1;
            }
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false
        onLockedChanged: { shell.globalPasswordBuffer = ""; shell.passwordLength = 0; }
        surface: Component {
            LockScreen { lockSession: sessionLock; rootRef: shell }
        }
    }

    IpcHandler { 
        id: lockscreenHandler
        target: "lockscreen"
        function lock(): void { sessionLock.locked = true; } 
        function unlock(): void { sessionLock.locked = false; } 
    }

    IpcHandler {
        target: "tooltip"
        function close(): void {
            shell.showHistoryMode = false;
        }
    }

    IpcHandler { target: "amogus"; function toggle(): void { if (!sessionLock.locked && amogusWindowInstance) amogusWindowInstance.toggleWindow(); } }
    IpcHandler { target: "rng"; function toggle(): void { if (!sessionLock.locked && diceRollerWindowInstance) diceRollerWindowInstance.toggleWithTarget(); } }
    IpcHandler { target: "magnifier"; function toggle(): void { if (!sessionLock.locked && magnifierOverlay) magnifierOverlay.toggle(); } }

    Notifications.NotificationOverlay {
        id: notificationOverlay
        showHistoryMode: shell.showHistoryMode
        notificationsEnabled: shell.notificationsEnabled
        onShowHistoryModeChanged: shell.showHistoryMode = showHistoryMode
        onNotificationsEnabledChanged: shell.notificationsEnabled = notificationsEnabled
    }
}

