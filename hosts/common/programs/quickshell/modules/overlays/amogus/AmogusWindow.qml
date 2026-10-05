import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style" as Style
import "../../common" as Common
import "../../common/Utils.js" as Utils
import "./frontend" as Frontend

PanelWindow {
    id: root

    property string windowId: "amogus"
    property var shell: null
    property int currentScreenIndex: 0

    readonly property bool isPreviewMode: (shell && shell.settingsManager && shell.settingsManager.previewWindow === windowId)
    property bool isOpenState: false
    visible: isOpenState || isPreviewMode

    property bool isCardActive: true

    readonly property color activeBorderColor: (shell && shell.theme && shell.theme.base03) ? shell.theme.base03 : "#003399"
    readonly property color inactiveBorderColor: (shell && shell.theme && shell.theme.base0D) ? shell.theme.base0D : "#003399"

    onVisibleChanged: {
        if (visible && !isPreviewMode) {
            if (shell && typeof shell.closeOtherOverlays === "function") {
                shell.closeOtherOverlays(root);
            }
            root.isCardActive = true;
        }
    }

    screen: {
        if (Quickshell.screens.length > currentScreenIndex) {
            return Quickshell.screens[currentScreenIndex];
        }
        return Quickshell.screens[0] || null;
    }

    function toggleWindow() {
        if (root.isOpenState) hideWindow();
        else showWindow();
    }

    function showWindow() {
        root.isCardActive = true;
        root.isOpenState = true;
    }

    function activateCard() {
        root.isCardActive = true;
    }

    function hideWindow() {
        root.isOpenState = false;
        root.isCardActive = false;
        if (shell && shell.settingsManager && shell.settingsManager.previewWindow === windowId) {
            shell.settingsManager.previewWindow = "";
        }
    }

    function close() {
        hideWindow();
    }

    Component.onCompleted: {
        if (Quickshell.screens.length > 1) {
            currentScreenIndex = 1;
        }
    }

    Common.GlobalEscWatcher {
        active: root.isOpenState && !root.isPreviewMode
        onEscapePressed: root.close()
    }

    WlrLayershell.namespace: "quickshell-amogus"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        return root.isCardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: root.isCardActive ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: amogusCard }

    color: "transparent"

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: otherScreenCatcher
            required property var modelData
            screen: modelData

            visible: root.isOpenState && root.isCardActive && !root.isPreviewMode && (modelData !== root.screen)

            WlrLayershell.namespace: "quickshell-amogus-dismiss"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    root.isCardActive = false;
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isCardActive && !root.isPreviewMode
        onPressed: {
            root.isCardActive = false;
        }
    }

    readonly property color themeBase00: (shell && shell.theme && shell.theme.base00) ? shell.theme.base00 : "#11111b"
    readonly property int globalBorderWidth: (shell && shell.theme && shell.theme.globalBorderWidth !== undefined) ? shell.theme.globalBorderWidth : 3

    Item {
        id: amogusCard
        x: 80
        y: 80
        width: (shell && shell.settingsManager) ? shell.settingsManager.getWindowWidth(root.windowId, 620) : 620
        height: (shell && shell.settingsManager) ? shell.settingsManager.getWindowHeight(root.windowId, 480) : 480

        Style.ShapeBox {
            anchors.fill: parent
            role: "card"
            color: root.themeBase00
            borderColor: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
            borderWidth: root.globalBorderWidth
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.isCardActive && !root.isPreviewMode
            z: 9999
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                root.activateCard();
            }
        }

        Loader {
            id: viewLoader
            anchors.fill: parent
            sourceComponent: Frontend.AmogusView {
                shell: root.shell
                dragTarget: amogusCard
                dragMaxX: Math.max(0, root.width - amogusCard.width)
                dragMaxY: Math.max(0, root.height - amogusCard.height)
                isPreviewMode: root.isPreviewMode
                isCardActive: root.isCardActive
                currentScreenIndex: root.currentScreenIndex
                onCloseRequested: root.hideWindow()
                onScreenSelected: (idx) => { root.currentScreenIndex = idx; }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible && !root.isPreviewMode
        onActivated: root.close()
    }
}
