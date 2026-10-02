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
    
    property string windowId: "email"
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
    
    onVisibleChanged: {
        if (visible && !isPreviewMode) {
            if (safeShell && typeof safeShell.closeOtherOverlays === "function") {
                safeShell.closeOtherOverlays(window);
            }
            emailEngine.checkHimalaya();
            emailEngine.readMailCache();
            if (viewLoader.item) viewLoader.item.clearAndFocus();
        }
    }
    
    WlrLayershell.namespace: "quickshell-email-window"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (visible && !isPreviewMode) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    
    function open() {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        isOpenState = true;
        emailEngine.checkHimalaya();
        emailEngine.readMailCache();
        if (viewLoader.item) viewLoader.item.clearAndFocus();
    }
    function close() {
        isOpenState = false;
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }
    function toggle() { if (isOpenState) close(); else open(); }
    
    IpcHandler {
        target: "email"
        function toggle(): void { window.toggle(); }
        function open(): void { window.open(); }
        function close(): void { window.close(); }
    }
    
    MouseArea {
        anchors.fill: parent
        enabled: !window.isPreviewMode
        onClicked: window.close()
    }
    
    Backend.EmailEngine { id: emailEngine }
    
    Item {
        id: emailCard
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(window.windowId, 1500) : 1500
        height: settingsManager ? settingsManager.getWindowHeight(window.windowId, 900) : 900
        
        MouseArea { anchors.fill: parent; preventStealing: true }
        
        Loader {
            id: viewLoader
            anchors.fill: parent
            active: window.isUiActive
            sourceComponent: Frontend.EmailView {
                engine: emailEngine
                theme: window.theme
                settingsManager: window.settingsManager
                onCloseRequested: window.close()
            }
            onItemChanged: {
                if (item && window.isOpenState) item.clearAndFocus();
            }
        }
    }
    
    // ON-PREVIEW SLIDERS HUD
    SettingsTools.PreviewInspector {
        id: previewInspector
        visible: window.isPreviewMode
        anchors.left: (emailCard.x + emailCard.width + width + 20 <= window.width) ? emailCard.right : undefined
        anchors.right: (emailCard.x + emailCard.width + width + 20 > window.width) ? emailCard.left : undefined
        anchors.leftMargin: 20; anchors.rightMargin: 20
        anchors.verticalCenter: emailCard.verticalCenter
        
        windowId: window.windowId
        settingsManager: window.settingsManager
        theme: window.theme
        defaultW: 1500; defaultH: 900
            defaultFH: 48; defaultIS: 32
                hasField: true; hasIcon: false
                defaultPolicy: window.defaultPolicy
                    
                    onDoneRequested: {
                        if (settingsManager) settingsManager.previewWindow = "";
                    }
    }
    
    Shortcut {
        sequence: "Escape"
        enabled: window.visible && !window.isPreviewMode && (!viewLoader.item || !viewLoader.item.isModalActive())
        onActivated: window.close()
    }
}
