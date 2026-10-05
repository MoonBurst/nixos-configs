import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../" as RootTheme
import "../../style" as Style
import "../../common" as Common
import "../../common/Utils.js" as Utils
import "../../common/FallbackTheme.js" as FallbackTheme
import "./backend" as Backend
import "./frontend" as Frontend

PanelWindow {
    id: todoWindow

    property string windowId: "todo"
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
        onTriggered: { todoWindow.inGracePeriod = false; }
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
                safeShell.closeOtherOverlays(todoWindow);
            }
            todoWindow.isCardActive = true;
            focusTimer.restart();
        }
    }

    WlrLayershell.namespace: "quickshell-todo"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay

    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        return todoWindow.isCardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: todoWindow.isCardActive ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: card }

    function open() {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        todoWindow.isCardActive = true;
        isOpenState = true;
        focusTimer.restart();
    }

    function activateCard() {
        todoWindow.isCardActive = true;
        focusTimer.restart();
    }

    function close() {
        isOpenState = false;
        todoWindow.isCardActive = false;
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }

    function toggle() {
        if (isOpenState) close();
        else open();
    }

    IpcHandler {
        target: "todo"
        function toggle(): void { todoWindow.toggle(); }
        function open(): void { todoWindow.open(); }
        function close(): void { todoWindow.close(); }
    }

    Common.GlobalEscWatcher {
        active: todoWindow.isOpenState && !todoWindow.isPreviewMode
        onEscapePressed: todoWindow.close()
    }

    Backend.TodoEngine { id: todoEngine }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: otherScreenCatcher
            required property var modelData
            screen: modelData

            visible: todoWindow.isOpenState && todoWindow.isCardActive && !todoWindow.isPreviewMode && (modelData !== todoWindow.screen)

            WlrLayershell.namespace: "quickshell-todo-dismiss"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    todoWindow.isCardActive = false;
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: todoWindow.isCardActive && !todoWindow.isPreviewMode
        onPressed: {
            todoWindow.isCardActive = false;
        }
    }

    Item {
        id: card
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(todoWindow.windowId, 860) : 860
        height: settingsManager ? settingsManager.getWindowHeight(todoWindow.windowId, 740) : 740

        readonly property color currentBorderColor: todoWindow.isCardActive ? todoWindow.activeBorderColor : todoWindow.inactiveBorderColor
        readonly property int currentBorderWidth: (theme && theme.globalBorderWidth !== undefined) ? theme.globalBorderWidth : 3

        readonly property var safePad: Utils.getSafeCardPadding(settingsManager)

        Style.ShapeBox {
            anchors.fill: parent
            role: "card"
            color: (theme && theme.base01 !== undefined) ? theme.base01 : "#181825"
            borderColor: card.currentBorderColor
            borderWidth: card.currentBorderWidth
        }

        MouseArea {
            anchors.fill: parent
            enabled: !todoWindow.isCardActive && !todoWindow.isPreviewMode
            z: 9999
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                todoWindow.activateCard();
            }
        }

        Loader {
            id: viewLoader
            anchors.fill: parent
            anchors.leftMargin: card.safePad.h
            anchors.rightMargin: card.safePad.h
            anchors.topMargin: card.safePad.v
            anchors.bottomMargin: card.safePad.v
            active: todoWindow.isUiActive
            sourceComponent: Frontend.TodoView {
                engine: todoEngine
                theme: todoWindow.theme
                settingsManager: todoWindow.settingsManager
            }
            onItemChanged: {
                if (item && todoWindow.isOpenState && todoWindow.isCardActive) {
                    item.clearAndFocus();
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: todoWindow.visible && !todoWindow.isPreviewMode
        onActivated: todoWindow.close()
    }
}
