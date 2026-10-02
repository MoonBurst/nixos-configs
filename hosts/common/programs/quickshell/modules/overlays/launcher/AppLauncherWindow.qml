import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../" as RootTheme
import "./backend" as Backend
import "./frontend" as Frontend

PanelWindow {
    id: window

    property string windowId: "launcher"
    readonly property string defaultPolicy: "eager"

    property var shell: null
    readonly property var safeShell: (typeof shell !== "undefined" && shell) ? shell : null
    readonly property var settingsManager: safeShell ? safeShell.settingsManager : null
    readonly property var theme: (safeShell && safeShell.theme) ? safeShell.theme : fallbackTheme
    RootTheme.Theme { id: fallbackTheme }

    readonly property string loadPolicy: settingsManager ? settingsManager.getWindowLoadPolicy(windowId, defaultPolicy) : defaultPolicy
    readonly property bool shouldKeepLoaded: loadPolicy === "eager"

    screen: (safeShell && safeShell.primaryScreen) ? safeShell.primaryScreen : (Quickshell.screens[0] || null)

    readonly property bool isPreviewMode: (settingsManager && settingsManager.previewWindow === windowId)
    property bool isOpenState: false
    visible: isOpenState || isPreviewMode

    property bool inGracePeriod: false
    Timer {
        id: graceTimer
        repeat: false
        onTriggered: { window.inGracePeriod = false; }
    }

    onIsOpenStateChanged: {
        if (isOpenState) {
            graceTimer.stop();
            inGracePeriod = false;
        } else if (!isPreviewMode) {
            var timeoutSec = settingsManager ? settingsManager.overlayGraceTimeoutSec : 10;
            if (timeoutSec > 0 && !shouldKeepLoaded) {
                inGracePeriod = true;
                graceTimer.interval = timeoutSec * 1000;
                graceTimer.restart();
            } else {
                inGracePeriod = false;
            }
        }
    }

    readonly property bool isUiActive: shouldKeepLoaded || isOpenState || isPreviewMode || inGracePeriod

    // High-priority focus timer ensures instant keyboard focus upon opening
    Timer {
        id: focusTimer
        interval: 30
        repeat: false
        onTriggered: {
            if (viewLoader.item && typeof viewLoader.item.clearAndFocus === "function") {
                viewLoader.item.clearAndFocus();
            }
        }
    }

    onVisibleChanged: {
        if (visible && !isPreviewMode) {
            if (safeShell && typeof safeShell.closeOtherOverlays === "function") {
                safeShell.closeOtherOverlays(window);
            }
            launcherEngine.scan();
            focusTimer.restart();
        }
    }

    WlrLayershell.namespace: "quickshell-applauncher"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    // Exclusive focus routes keyboard input immediately upon opening; None in preview mode so Inspector stays interactive
    WlrLayershell.keyboardFocus: (visible && !isPreviewMode) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: isPreviewMode ? previewMask : null
    Region { id: previewMask; item: card }

    function open() {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        isOpenState = true;
        focusTimer.restart();
    }
    function close() {
        isOpenState = false;
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }
    function toggle() { if (isOpenState) close(); else open(); }

    IpcHandler {
        target: "launcher"
        function toggle(): void { window.toggle(); }
        function open(): void { window.open(); }
        function close(): void { window.close(); }
    }

    function routeTo(target, param) {
        window.close();
        if (safeShell) {
            switch (target) {
                case "settings": if (safeShell.settingsWindow) safeShell.settingsWindow.open(); return;
                case "clipboard": if (safeShell.clipboardWindow) safeShell.clipboardWindow.open(); return;
                case "calc": if (safeShell.calcWindow) safeShell.calcWindow.open(param); return;
                case "todo": if (safeShell.todoWindow) safeShell.todoWindow.open(); return;
                case "email": if (safeShell.emailWindow) safeShell.emailWindow.open(); return;
                case "dictionary": if (safeShell.dictionaryWindow) safeShell.dictionaryWindow.open(param); return;
                case "rng": if (safeShell.diceRollerWindowInstance) safeShell.diceRollerWindowInstance.openWithTarget(); return;
                case "pass": if (safeShell.passWindow) safeShell.passWindow.open(param); return;
                case "notes": if (safeShell.notesWindow) safeShell.notesWindow.open(param); return;
                case "power": if (safeShell.powerWindow) safeShell.powerWindow.open(); return;
                case "gemini": if (safeShell.geminiWindow) { safeShell.geminiWindow.open(); if (param) safeShell.geminiWindow.sendMessage(param); } return;
                case "unicode": if (safeShell.unicodeWindow) safeShell.unicodeWindow.open(); return;
                case "web": if (safeShell.startPageWindow) safeShell.startPageWindow.open(param); return;
                case "amogus": if (safeShell.amogusWindowInstance) safeShell.amogusWindowInstance.showWindow(); return;
            }
        }
        Quickshell.execDetached([
            "sh", "-c",
            'QS=$(command -v qs || command -v quickshell); [ -n "$QS" ] && "$QS" ipc call "$1" open "$2"',
            "sh", target, param || ""
        ]);
    }

    MouseArea {
        anchors.fill: parent
        enabled: !window.isPreviewMode
        onClicked: window.close()
    }

    Backend.AppLauncherEngine { id: launcherEngine }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(window.windowId, 840) : 840
        height: settingsManager ? settingsManager.getWindowHeight(window.windowId, 700) : 700
        radius: theme.defaultCardRadius
        color: theme.base01
        border.width: theme.globalBorderWidth
        border.color: theme.base03
        clip: true

        MouseArea {
            anchors.fill: parent
            enabled: !window.isPreviewMode
            preventStealing: true
        }

        Loader {
            id: viewLoader
            anchors.fill: parent
            active: window.isUiActive
            sourceComponent: Frontend.AppLauncherView {
                engine: launcherEngine
                theme: window.theme
                onCompleted: window.close()
                onRouteRequested: (target, param) => window.routeTo(target, param)
            }
            onItemChanged: {
                if (item && window.isOpenState) item.clearAndFocus();
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: window.visible && !window.isPreviewMode
        onActivated: window.close()
    }
}
