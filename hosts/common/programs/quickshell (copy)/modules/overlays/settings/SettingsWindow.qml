import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../" as RootTheme
import "../../style" as Style
import "../../common/Utils.js" as Utils
import "../../common/FallbackTheme.js" as FallbackTheme
import "./frontend" as Frontend

PanelWindow {
    id: window

    property string windowId: "settings"
    property var shell: null
    readonly property var safeShell: (typeof shell !== "undefined" && shell) ? shell : null
    readonly property var settingsManager: safeShell ? safeShell.settingsManager : null
    readonly property var theme: (safeShell && safeShell.theme) ? safeShell.theme : FallbackTheme.theme

    property bool isFileDialogActive: false

    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize : 16

    screen: (safeShell && safeShell.primaryScreen) ? safeShell.primaryScreen : (Quickshell.screens[0] || null)

    readonly property bool isPreviewMode: (settingsManager && settingsManager.previewWindow === windowId)
    property bool isOpenState: false
    visible: isOpenState || isPreviewMode

    function recenterCard() {
        if (window.width > card.width) card.x = Math.round((window.width - card.width) / 2);
        if (window.height > card.height) card.y = Math.round((window.height - card.height) / 2);
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(recenterCard);
            if (!isPreviewMode && safeShell && typeof safeShell.closeOtherOverlays === "function") {
                safeShell.closeOtherOverlays(window);
            }
        }
    }

    onWidthChanged: if (visible) Qt.callLater(recenterCard)
    onHeightChanged: if (visible) Qt.callLater(recenterCard)

    WlrLayershell.namespace: "quickshell-settings-window"
    
    WlrLayershell.layer: isFileDialogActive ? WlrLayer.Bottom : WlrLayer.Top
    WlrLayershell.keyboardFocus: (visible && !isPreviewMode && !isFileDialogActive) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: Region {
        item: (settingsManager && settingsManager.previewWindow !== "") ? card : fullSettingsBg
    }
    Item { id: fullSettingsBg; anchors.fill: parent }

    function open() {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        isOpenState = true;
        Qt.callLater(recenterCard);
    }
    function close() {
        isOpenState = false;
        if (settingsManager && settingsManager.previewWindow !== "") {
            settingsManager.previewWindow = "";
        }
    }
    function toggle() { if (isOpenState) close(); else open(); }

    IpcHandler {
        target: "settings"
        function toggle(): void { window.toggle(); }
        function open(): void { window.open(); }
        function close(): void { window.close(); }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !window.isPreviewMode && (settingsManager ? settingsManager.previewWindow === "" : true) && !window.isFileDialogActive
        visible: enabled
        onClicked: {
            if (settingsManager && settingsManager.previewWindow !== "") {
                settingsManager.previewWindow = "";
            } else {
                window.close();
            }
        }
    }

    Item {
        id: card
        width: settingsManager ? settingsManager.getWindowWidth(window.windowId, 1040) : 1040
        height: settingsManager ? settingsManager.getWindowHeight(window.windowId, 760) : 760
        x: Math.round(Math.max(20, (window.width - width) / 2))
        y: Math.round(Math.max(20, (window.height - height) / 2))

        readonly property var safePad: Utils.getSafeCardPadding(settingsManager)

        Style.ShapeBox {
            anchors.fill: parent
            role: "card"
            color: theme.base01
            borderColor: theme.base03
            borderWidth: theme.globalBorderWidth
        }

        MouseArea { anchors.fill: parent; preventStealing: true }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: (settingsManager && settingsManager.overlayCardShape !== "rounded") ? card.safePad.h : theme.globalBorderWidth
            anchors.rightMargin: (settingsManager && settingsManager.overlayCardShape !== "rounded") ? card.safePad.h : theme.globalBorderWidth
            anchors.topMargin: (settingsManager && settingsManager.overlayCardShape !== "rounded") ? card.safePad.v : theme.globalBorderWidth
            anchors.bottomMargin: (settingsManager && settingsManager.overlayCardShape !== "rounded") ? card.safePad.v : theme.globalBorderWidth
            spacing: 8

            // Title Bar
            Item {
                id: titleBarBox
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(46, Math.round(window.overlayFontSize * 2.4))
                Layout.minimumHeight: Layout.preferredHeight

                readonly property var inputPad: Utils.getSafeInputPadding(settingsManager)

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    color: theme.base00
                    borderColor: theme.base03
                    borderWidth: 1
                    slantWidth: 10
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    drag.target: card
                    drag.minimumX: 0
                    drag.minimumY: 0
                    drag.maximumX: Math.max(0, window.width - card.width)
                    drag.maximumY: Math.max(0, window.height - card.height)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.max(16, titleBarBox.inputPad.left)
                    anchors.rightMargin: Math.max(16, titleBarBox.inputPad.right)
                    spacing: 10

                    Text {
                        text: "⚙"
                        font.pixelSize: Math.max(18, window.overlayFontSize + 2)
                        color: theme.base05
                    }
                    Text {
                        text: "SYSTEM SETTINGS & PREFERENCES"
                        font.bold: true
                        font.pixelSize: Math.max(12, window.overlayFontSize - 2)
                        color: theme.base05
                        Layout.fillWidth: true
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Frontend.SettingsPanel {
                    anchors.fill: parent
                    anchors.margins: theme.globalPadding
                    shell: window.safeShell
                    settingsManager: window.settingsManager
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: window.visible && !window.isFileDialogActive
        onActivated: {
            if (settingsManager && settingsManager.previewWindow !== "") {
                settingsManager.previewWindow = "";
            } else {
                window.close();
            }
        }
    }
}
