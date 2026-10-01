import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../" as RootTheme
import "../../settings" as SettingsTools
import "./backend" as Backend
import "./frontend" as Frontend

PanelWindow {
    id: window

    property string windowId: "calc"
    readonly property string defaultPolicy: "lazy"

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
    property string pendingExpr: ""

    onVisibleChanged: {
        if (visible && !isPreviewMode) {
            if (safeShell && typeof safeShell.closeOtherOverlays === "function") {
                safeShell.closeOtherOverlays(window);
            }
            if (viewLoader.item) viewLoader.item.clearAndFocus(pendingExpr);
        }
    }

    WlrLayershell.namespace: "quickshell-calc"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: (visible && !isPreviewMode) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    function open(initialExpr) {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        pendingExpr = initialExpr || "";
        isOpenState = true;
        if (viewLoader.item) viewLoader.item.clearAndFocus(pendingExpr);
    }
    function close() {
        isOpenState = false;
        pendingExpr = "";
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }
    function toggle() { if (isOpenState) close(); else open(); }

    IpcHandler {
        target: "calc"
        function toggle(): void { window.toggle(); }
        function open(expr: string): void { window.open(expr); }
        function close(): void { window.close(); }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !window.isPreviewMode
        onClicked: window.close()
    }

    Backend.CalcEngine { id: calcEngine }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(window.windowId, 820) : 820
        height: settingsManager ? settingsManager.getWindowHeight(window.windowId, 580) : 580
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
            sourceComponent: Frontend.CalcView {
                engine: calcEngine
                theme: window.theme
                onCompleted: window.close()
            }
            onItemChanged: {
                if (item && window.isOpenState) item.clearAndFocus(window.pendingExpr);
            }
        }
    }

    // STATIC POSITIONED INSPECTOR
    SettingsTools.PreviewInspector {
        id: previewInspector
        visible: window.isPreviewMode
        windowId: window.windowId
        settingsManager: window.settingsManager
        theme: window.theme
        defaultW: 820
        defaultH: 580
        defaultFH: 54
        defaultIS: 32
        hasField: true
        hasIcon: false
        defaultPolicy: window.defaultPolicy

        onDoneRequested: {
            if (settingsManager) settingsManager.previewWindow = "";
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: window.visible
        onActivated: {
            if (window.isPreviewMode) {
                if (settingsManager) settingsManager.previewWindow = "";
            } else {
                window.close();
            }
        }
    }
}
