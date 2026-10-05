import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../" as RootTheme
import "../../style" as Style
import "../../common" as Common
import "../../common/FallbackTheme.js" as FallbackTheme
import "./backend" as Backend
import "./frontend" as Frontend

PanelWindow {
    id: window

    property string windowId: "notes"
    readonly property string defaultPolicy: "lazy"

    property var shell: null
    readonly property var safeShell: (typeof shell !== "undefined" && shell) ? shell : null
    readonly property var settingsManager: safeShell ? safeShell.settingsManager : null
    readonly property var theme: (safeShell && safeShell.theme) ? safeShell.theme : FallbackTheme.theme

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
                viewLoader.item.clearAndFocus(window.pendingNote);
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
    property string pendingNote: ""

    onVisibleChanged: {
        if (visible && !isPreviewMode) {
            if (safeShell && typeof safeShell.closeOtherOverlays === "function") {
                safeShell.closeOtherOverlays(window);
            }
            window.isCardActive = true;
            notesEngine.loadNotes();
            focusTimer.restart();
        }
    }

    WlrLayershell.namespace: "quickshell-notes"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        return window.isCardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: window.isCardActive ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: card }

    function open(note) {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        pendingNote = note || "";
        window.isCardActive = true;
        isOpenState = true;
        notesEngine.loadNotes();
        focusTimer.restart();
    }

    function activateCard() {
        window.isCardActive = true;
        focusTimer.restart();
    }

    function close() {
        isOpenState = false;
        window.isCardActive = false;
        pendingNote = "";
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }

    function toggle() { if (isOpenState) close(); else open(); }

    IpcHandler {
        target: "notes"
        function toggle(): void { window.toggle(); }
        function open(note: string): void { window.open(note); }
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

            WlrLayershell.namespace: "quickshell-notes-dismiss"
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

    Backend.NotesEngine { id: notesEngine }

    Item {
        id: card
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(window.windowId, 840) : 840
        height: settingsManager ? settingsManager.getWindowHeight(window.windowId, 650) : 650

        readonly property color currentBorderColor: window.isCardActive ? window.activeBorderColor : window.inactiveBorderColor
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
            anchors.leftMargin: card.cardPadH
            anchors.rightMargin: card.cardPadH
            anchors.topMargin: card.cardPadV
            anchors.bottomMargin: card.cardPadV
            active: window.isUiActive
            sourceComponent: Frontend.NotesView {
                engine: notesEngine
                theme: window.theme
                settingsManager: window.settingsManager
                onCompleted: window.close()
            }
            onItemChanged: {
                if (item && window.isOpenState && window.isCardActive) item.clearAndFocus(window.pendingNote);
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: window.visible && !window.isPreviewMode
        onActivated: window.close()
    }
}
