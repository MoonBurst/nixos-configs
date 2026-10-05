import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../" as RootTheme
import "../../style" as Style
import "../../common" as Common
import "../../settings" as SettingsTools
import "./backend" as Backend
import "./frontend" as Frontend

PanelWindow {
    id: launcherWindow

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

    property bool isCardActive: true

    readonly property color activeBorderColor: (theme && theme.base03) ? theme.base03 : "#003399"
    readonly property color inactiveBorderColor: (theme && theme.base0D) ? theme.base0D : "#003399"

    property bool inGracePeriod: false
    Timer {
        id: graceTimer
        repeat: false
        onTriggered: { launcherWindow.inGracePeriod = false; }
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

    Timer {
        id: focusTimer
        interval: 50
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
                safeShell.closeOtherOverlays(launcherWindow);
            }
            launcherWindow.isCardActive = true;
            launcherEngine.scan();
            focusTimer.restart();
        }
    }

    WlrLayershell.namespace: "quickshell-applauncher"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        return launcherWindow.isCardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: launcherWindow.isCardActive ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: card }

    function open() {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        launcherWindow.isCardActive = true;
        isOpenState = true;
        focusTimer.restart();
    }

    function activateCard() {
        launcherWindow.isCardActive = true;
        focusTimer.restart();
    }

    function close() {
        isOpenState = false;
        launcherWindow.isCardActive = false;
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }

    function toggle() { if (isOpenState) close(); else open(); }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcherWindow.toggle(); }
        function open(): void { launcherWindow.open(); }
        function close(): void { launcherWindow.close(); }
    }

    Common.GlobalEscWatcher {
        active: launcherWindow.isOpenState && !launcherWindow.isPreviewMode
        onEscapePressed: launcherWindow.close()
    }

    function routeTo(target, param) {
        launcherWindow.close();
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

        // FIX: Intercept real application binaries (like kitty, browser, discord)
        // and run them in a separate process session completely unlinked from Quickshell
        if (target && target !== "sh" && !target.includes(":") && !target.includes("apps")) {
            Quickshell.execDetached([
                "setsid",
                "sh", "-c",
                "nohup " + target + " " + (param || "") + " >/dev/null 2>&1 &"
            ]);
            return;
        }

        // Fallback fallback loop for raw internal script hooks
        Quickshell.execDetached([
            "sh", "-c",
            'QS=$(command -v qs || command -v quickshell); [ -n "$QS" ] && "$QS" ipc call "$1" open "$2"',
                                "sh", target, param || ""
        ]);
    }


    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: otherScreenCatcher
            required property var modelData
            screen: modelData

            visible: launcherWindow.isOpenState && launcherWindow.isCardActive && !launcherWindow.isPreviewMode && (modelData !== launcherWindow.screen)

            WlrLayershell.namespace: "quickshell-launcher-dismiss"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    launcherWindow.isCardActive = false;
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: launcherWindow.isCardActive && !launcherWindow.isPreviewMode
        onPressed: {
            launcherWindow.isCardActive = false;
        }
    }

    Backend.AppLauncherEngine { id: launcherEngine }

    Item {
        id: card
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(launcherWindow.windowId, 840) : 840
        height: settingsManager ? settingsManager.getWindowHeight(launcherWindow.windowId, 700) : 700

        readonly property color currentBorderColor: launcherWindow.isCardActive ? launcherWindow.activeBorderColor : launcherWindow.inactiveBorderColor
        readonly property int currentBorderWidth: (theme && theme.globalBorderWidth !== undefined) ? theme.globalBorderWidth : 3

        readonly property int cardCornerCut: {
            if (!settingsManager) return 0;
            if (settingsManager.overlayCardShape === "hexagon") return Math.round(settingsManager.overlayHexagonCut || 36);
            if (settingsManager.overlayCardShape === "slant") return Math.round(settingsManager.overlaySlantAngle || 32);
            return 0;
        }
        readonly property int cardPadH: (settingsManager && settingsManager.overlayCardShape !== "rounded")
            ? Math.max(28, Math.round(cardCornerCut * 1.0) + 20)
            : 0
        readonly property int cardPadV: (settingsManager && settingsManager.overlayCardShape !== "rounded")
            ? Math.max(20, Math.round(cardCornerCut * 0.45) + 14)
            : 0

        Style.ShapeBox {
            anchors.fill: parent
            role: "card"
            color: theme.base01
            borderColor: card.currentBorderColor
            borderWidth: card.currentBorderWidth
        }

        MouseArea {
            anchors.fill: parent
            enabled: !launcherWindow.isCardActive && !launcherWindow.isPreviewMode
            z: 9999
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                launcherWindow.activateCard();
            }
        }

        Loader {
            id: viewLoader
            anchors.fill: parent
            anchors.leftMargin: card.cardPadH
            anchors.rightMargin: card.cardPadH
            anchors.topMargin: card.cardPadV
            anchors.bottomMargin: card.cardPadV
            active: launcherWindow.isUiActive
            sourceComponent: Frontend.AppLauncherView {
                engine: launcherEngine
                theme: launcherWindow.theme
                settingsManager: launcherWindow.settingsManager
                onCompleted: launcherWindow.close()
                onRouteRequested: (target, param) => launcherWindow.routeTo(target, param)
            }
            onItemChanged: {
                if (item && launcherWindow.isOpenState && launcherWindow.isCardActive) item.clearAndFocus();
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: launcherWindow.visible && !launcherWindow.isPreviewMode
        onActivated: launcherWindow.close()
    }
}
