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

    property bool isCardActive: true
    readonly property bool isModalOpen: (emailEngine && emailEngine.isComposing)
        || (viewLoader.item && (viewLoader.item.modalActive || viewLoader.item.isModalActive()))

    readonly property color activeBorderColor: (theme && theme.base03) ? theme.base03 : "#003399"
    readonly property color inactiveBorderColor: (theme && theme.base0D) ? theme.base0D : "#003399"

    QtObject {
        id: dynamicEmailTheme
        readonly property var src: window.theme

        property color base00: src ? src.base00 : "#121212"
        property color base01: src ? src.base01 : "#181825"
        property color base02: src ? src.base02 : "#313244"
        property color base03: src ? src.base03 : "#003399"
        property color base04: src ? src.base04 : "#45475a"
        property color base05: src ? src.base05 : "yellow"
        property color base06: src ? src.base06 : "white"
        property color base07: src ? src.base07 : "#cccccc"
        property color base08: src ? src.base08 : "#ff5555"
        property color base09: src ? src.base09 : "#fe8019"
        property color base0A: src ? src.base0A : "#fabd2f"
        property color base0B: src ? src.base0B : "#545454"
        property color base0C: src ? src.base0C : "#04f100"
        property color base0D: src ? src.base0D : "#003399"
        property color base0E: src ? src.base0E : "#675ddb"
        property color base0F: src ? src.base0F : "#ff8019"

        property string fontFamily: src ? src.fontFamily : "monospace"
        property int defaultCardWidth: (src && src.defaultCardWidth) ? src.defaultCardWidth : 420
        property int defaultCardHeight: (src && src.defaultCardHeight) ? src.defaultCardHeight : 140
        property int defaultCardRadius: (src && src.defaultCardRadius) ? src.defaultCardRadius : 10
        property int globalBorderWidth: (src && src.globalBorderWidth) ? src.globalBorderWidth : 3
        property int globalPadding: (src && src.globalPadding) ? src.globalPadding : 16
        property int globalFontSize: (src && src.globalFontSize) ? src.globalFontSize : 14
        property color scrollHandleColor: (src && src.scrollHandleColor) ? src.scrollHandleColor : "#003399"

        property color innerBorderColor: (src && src.base05) ? src.base05 : "yellow"
        property color outerBorderColor: window.isCardActive ? window.activeBorderColor : window.inactiveBorderColor
    }

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
            emailEngine.checkHimalaya();
            emailEngine.readMailCache();
            focusTimer.restart();
        }
    }

    WlrLayershell.namespace: "quickshell-email-window"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay

    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        return window.isCardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: (window.isCardActive && !window.isModalOpen) ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: emailCard }

    function open() {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        window.isCardActive = true;
        isOpenState = true;
        emailEngine.checkHimalaya();
        emailEngine.readMailCache();
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
        target: "email"
        function toggle(): void { window.toggle(); }
        function open(): void { window.open(); }
        function close(): void { window.close(); }
    }

    Common.GlobalEscWatcher {
        active: window.isOpenState && !window.isPreviewMode && !window.isModalOpen
        onEscapePressed: {
            if (viewLoader.item && (Date.now() - viewLoader.item.lastModalCloseTime < 350)) {
                return;
            }
            window.close();
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: otherScreenCatcher
            required property var modelData
            screen: modelData

            visible: window.isOpenState && window.isCardActive && !window.isPreviewMode && !window.isModalOpen && (modelData !== window.screen)

            WlrLayershell.namespace: "quickshell-email-dismiss"
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
        enabled: window.isCardActive && !window.isPreviewMode && !window.isModalOpen
        onPressed: {
            window.isCardActive = false;
        }
    }

    Backend.EmailEngine { id: emailEngine }

    Item {
        id: emailCard
        width: settingsManager ? settingsManager.getWindowWidth(window.windowId, 1500) : 1500
        height: settingsManager ? settingsManager.getWindowHeight(window.windowId, 900) : 900
        x: Math.round(Math.max(20, (window.width - width) / 2))
        y: Math.round(Math.max(20, (window.height - height) / 2))

        readonly property int cardCornerCut: {
            if (!settingsManager) return 0;
            if (settingsManager.overlayCardShape === "hexagon") return Math.round(settingsManager.overlayHexagonCut || 36);
            if (settingsManager.overlayCardShape === "slant") return Math.round(settingsManager.overlaySlantAngle || 32);
            return 0;
        }
        readonly property int cardPadH: (settingsManager && settingsManager.overlayCardShape !== "rounded")
            ? Math.max(24, Math.round(cardCornerCut * 1.0) + 16)
            : 0
        readonly property int cardPadV: (settingsManager && settingsManager.overlayCardShape !== "rounded")
            ? Math.max(18, Math.round(cardCornerCut * 0.5) + 12)
            : 0

        Style.ShapeBox {
            anchors.fill: parent
            role: "card"
            color: theme.base01
            borderColor: window.isCardActive ? window.activeBorderColor : window.inactiveBorderColor
            borderWidth: (theme && theme.globalBorderWidth !== undefined) ? theme.globalBorderWidth : 3
        }

        MouseArea {
            anchors.fill: parent
            enabled: !window.isCardActive && !window.isPreviewMode && !window.isModalOpen
            z: 9999
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                window.activateCard();
            }
        }

        Loader {
            id: viewLoader
            anchors.fill: parent
            anchors.leftMargin: emailCard.cardPadH
            anchors.rightMargin: emailCard.cardPadH
            anchors.topMargin: emailCard.cardPadV
            anchors.bottomMargin: emailCard.cardPadV
            active: window.isUiActive
            sourceComponent: Frontend.EmailView {
                engine: emailEngine
                theme: dynamicEmailTheme
                settingsManager: window.settingsManager
                onCloseRequested: window.close()
            }
            onItemChanged: {
                if (item && window.isOpenState && window.isCardActive) item.clearAndFocus();
            }
        }
    }

    SettingsTools.PreviewInspector {
        id: previewInspector
        visible: window.isPreviewMode
        anchors.left: emailCard.right
        anchors.leftMargin: 20
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
        enabled: window.visible && !window.isPreviewMode && !window.isModalOpen
        onActivated: {
            if (viewLoader.item && (Date.now() - viewLoader.item.lastModalCloseTime < 350)) {
                return;
            }
            window.close();
        }
    }
}
