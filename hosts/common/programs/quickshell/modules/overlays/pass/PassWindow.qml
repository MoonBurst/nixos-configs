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
    
    property string windowId: "pass"
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
    property string pendingQuery: ""
    
    onVisibleChanged: {
        if (visible && !isPreviewMode) {
            if (safeShell && typeof safeShell.closeOtherOverlays === "function") {
                safeShell.closeOtherOverlays(window);
            }
            passEngine.reload();
            if (viewLoader.item) viewLoader.item.clearAndFocus(pendingQuery);
        }
    }
    
    WlrLayershell.namespace: "quickshell-pass"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (visible && !isPreviewMode) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    
    function open(query) {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        pendingQuery = query || "";
        isOpenState = true;
        passEngine.reload();
        if (viewLoader.item) viewLoader.item.clearAndFocus(pendingQuery);
    }
    function close() {
        isOpenState = false;
        pendingQuery = "";
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }
    function toggle() { if (isOpenState) close(); else open(); }
    
    IpcHandler {
        target: "pass"
        function toggle(): void { window.toggle(); }
        function open(query: string): void { window.open(query); }
        function close(): void { window.close(); }
    }
    
    MouseArea {
        anchors.fill: parent
        enabled: !window.isPreviewMode
        onClicked: window.close()
    }
    
    Backend.PassEngine { id: passEngine }
    
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(window.windowId, 820) : 820
        height: settingsManager ? settingsManager.getWindowHeight(window.windowId, 600) : 600
        radius: theme.defaultCardRadius
        color: theme.base01
        border.width: theme.globalBorderWidth
        border.color: theme.base03
        clip: true
        
        MouseArea { anchors.fill: parent; preventStealing: true }
        
        Loader {
            id: viewLoader
            anchors.fill: parent
            active: window.isUiActive
            sourceComponent: Frontend.PassView {
                engine: passEngine
                theme: window.theme
                onCompleted: window.close()
            }
            onItemChanged: {
                if (item && window.isOpenState) item.clearAndFocus(window.pendingQuery);
            }
        }
    }
    
    SettingsTools.PreviewInspector {
        id: previewInspector
        visible: window.isPreviewMode
        anchors.left: (card.x + card.width + width + 20 <= window.width) ? card.right : undefined
        anchors.right: (card.x + card.width + width + 20 > window.width) ? card.left : undefined
        anchors.leftMargin: 20; anchors.rightMargin: 20
        anchors.verticalCenter: card.verticalCenter
        
        windowId: window.windowId
        settingsManager: window.settingsManager
        theme: window.theme
        defaultW: 820; defaultH: 600
            defaultFH: 52; defaultIS: 32
                hasField: true; hasIcon: false
                defaultPolicy: window.defaultPolicy
                    
                    onDoneRequested: {
                        if (settingsManager) settingsManager.previewWindow = "";
                    }
    }
    
    Shortcut {
        sequence: "Escape"
        enabled: window.visible && !window.isPreviewMode
        onActivated: window.close()
    }
}
