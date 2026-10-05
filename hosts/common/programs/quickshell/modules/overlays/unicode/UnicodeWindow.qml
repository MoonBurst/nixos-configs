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
    id: window

    property string windowId: "unicode"
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

    property bool isCardActive: true

    readonly property color activeBorderColor: (theme && theme.base03) ? theme.base03 : "#003399"
    readonly property color inactiveBorderColor: (theme && theme.base0D) ? theme.base0D : "#003399"

    property bool inGracePeriod: false
    Timer {
        id: graceTimer
        repeat: false
        onTriggered: { window.inGracePeriod = false; }
    }

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
            window.isCardActive = true;
            focusTimer.restart();
        }
    }

    WlrLayershell.namespace: "quickshell-unicode"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        return window.isCardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: window.isCardActive ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: card }

    function open() {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        window.isCardActive = true;
        isOpenState = true;
        focusTimer.restart();
    }

    function activateCard() {
        window.isCardActive = true;
        focusTimer.restart();
    }

    function close() {
        isOpenState = false;
        window.isCardActive = false;
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }

    function toggle() { if (isOpenState) close(); else open(); }

    IpcHandler {
        target: "unicode"
        function toggle(): void { window.toggle(); }
        function open(): void { window.open(); }
        function close(): void { window.close(); }
    }

    Common.GlobalEscWatcher {
        active: window.isOpenState && !window.isPreviewMode
        onEscapePressed: window.close()
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: otherScreenCatcher
            required property var modelData
            screen: modelData

            visible: window.isOpenState && window.isCardActive && !window.isPreviewMode && (modelData !== window.screen)

            WlrLayershell.namespace: "quickshell-unicode-dismiss"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    window.isCardActive = false;
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: window.isCardActive && !window.isPreviewMode
        onPressed: {
            window.isCardActive = false;
        }
    }

    Backend.UnicodeEngine { id: unicodeEngine }

    Item {
        id: card
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(window.windowId, 780) : 780
        height: settingsManager ? settingsManager.getWindowHeight(window.windowId, 600) : 600

        readonly property color currentBorderColor: window.isCardActive ? window.activeBorderColor : window.inactiveBorderColor
        readonly property int currentBorderWidth: (theme && theme.globalBorderWidth !== undefined) ? theme.globalBorderWidth : 3

        Style.ShapeBox {
            anchors.fill: parent
            role: "card"
            color: theme.base01
            borderColor: card.currentBorderColor
            borderWidth: card.currentBorderWidth
        }

        MouseArea {
            anchors.fill: parent
            enabled: !window.isCardActive && !window.isPreviewMode
            z: 9999
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                window.activateCard();
            }
        }

        Loader {
            id: viewLoader
            anchors.fill: parent
            active: window.isUiActive
            sourceComponent: Frontend.UnicodeView {
                engine: unicodeEngine
                theme: window.theme
                settingsManager: window.settingsManager
                onCompleted: window.close()
            }
            onItemChanged: {
                if (item && window.isOpenState && window.isCardActive) item.clearAndFocus();
            }
        }

        // Red "X" square removed from corner
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
        defaultW: 780; defaultH: 600
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
