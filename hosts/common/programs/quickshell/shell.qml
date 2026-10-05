import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "./modules/settings" as Settings
import "./modules/bar" as BarModule
import "./modules/lockscreen" as LockscreenModule
import "./modules/overlays" as OverlayHostModule

ShellRoot {
    id: shell

    property bool debug: false

    Theme { id: globalTheme }

    Process {
        id: ipcPathRegistrar
        running: true
        command: ["sh", "-c", 'echo "$1" > "${XDG_RUNTIME_DIR:-/tmp}/quickshell-path"', "sh", Quickshell.shellDir]
    }

    Process {
        id: tmpCacheCleaner
        running: true
        command: [
            "sh", "-c",
            'rm -f /tmp/qs_avatar_notif_*.png /tmp/quickshot_crop_*.png /tmp/qs_dict*.json 2>/dev/null || true; ' +
            '# Clear stale IPC command files so overlays do not pop open on a fresh boot\n' +
            '> /tmp/magnifier-state 2>/dev/null || true; ' +
            'rm -f /tmp/magnifier-state 2>/dev/null || true'
        ]
    }

    Settings.SettingsManager { id: settingsManagerInstance }
    property alias settingsManager: settingsManagerInstance

    readonly property var primaryScreen: {
        const screens = Quickshell.screens;
        if (!screens || screens.length === 0) return null;
        return screens.find(s => s.name === "DP-1")
            ?? screens.find(s => s.name.startsWith("eDP"))
            ?? screens[0] ?? null;
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
        property int controlBorderWidth: settingsManager.controlBorderWidth
        property int globalPadding: settingsManager.globalPadding
    }

    property alias theme: activeTheme

    property bool showHistoryMode: false
    property bool notificationsEnabled: true
    property int unreadCount: 0
    property var deferredNotificationsQueue: []
    Binding { target: shell; property: "notificationsEnabled"; value: settingsManager.notificationsEnabled }

    // Lockscreen & PAM management
    LockscreenModule.LockManager {
        id: lockManager
        shell: shell
    }
    property alias lockPam: lockManager.lockPam
    property alias sessionLock: lockManager.sessionLock
    property alias globalPasswordBuffer: lockManager.globalPasswordBuffer
    property alias passwordLength: lockManager.passwordLength

    // Top Bar Window
    BarModule.TopBar {
        id: topBar
        shell: shell
    }

    // Modular Overlays & Window Registry
    OverlayHostModule.OverlayHost {
        id: overlayHost
        shell: shell
    }

    // Window & Manager aliases
    property alias appLauncherWindow: overlayHost.appLauncherWindow
    property alias calcWindow: overlayHost.calcWindow
    property alias clipboardWindow: overlayHost.clipboardWindow
    property alias dictionaryWindow: overlayHost.dictionaryWindow
    property alias unicodeWindow: overlayHost.unicodeWindow
    property alias notesWindow: overlayHost.notesWindow
    property alias passWindow: overlayHost.passWindow
    property alias powerWindow: overlayHost.powerWindow
    property alias todoWindow: overlayHost.todoWindow
    property alias geminiWindow: overlayHost.geminiWindow
    property alias settingsWindow: overlayHost.settingsWindow
    property alias emailWindow: overlayHost.emailWindow
    property alias startPageWindow: overlayHost.startPageWindow
    property alias diceRollerWindowInstance: overlayHost.diceRollerWindowInstance
    property alias amogusWindowInstance: overlayHost.amogusWindowInstance
    property alias notificationOverlay: overlayHost.notificationOverlay

    function closeOtherOverlays(activeWin) {
        overlayHost.closeOtherOverlays(activeWin);
    }
}
