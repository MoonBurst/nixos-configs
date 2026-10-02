import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../" as RootTheme
import "./frontend" as Frontend

PanelWindow {
    id: window

    property string windowId: "settings"
    property var shell: null
    readonly property var safeShell: (typeof shell !== "undefined" && shell) ? shell : null
    readonly property var settingsManager: safeShell ? safeShell.settingsManager : null
    readonly property var theme: (safeShell && safeShell.theme) ? safeShell.theme : fallbackTheme
    RootTheme.Theme { id: fallbackTheme }

    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize : 16

    screen: (safeShell && safeShell.primaryScreen) ? safeShell.primaryScreen : (Quickshell.screens[0] || null)

    readonly property bool isPreviewMode: (settingsManager && settingsManager.previewWindow === windowId)
    property bool isOpenState: false
    visible: isOpenState || isPreviewMode

    onVisibleChanged: {
        if (visible && !isPreviewMode) {
            if (safeShell && typeof safeShell.closeOtherOverlays === "function") {
                safeShell.closeOtherOverlays(window);
            }
        }
    }

    WlrLayershell.namespace: "quickshell-settings-window"
    // Settings stays on Top layer so previewed overlays on Overlay layer appear ABOVE it
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: (visible && !isPreviewMode) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: Region {
        item: (settingsManager && settingsManager.previewWindow !== "") ? card : fullSettingsBg
    }
    Item { id: fullSettingsBg; anchors.fill: parent }

    function open() {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        isOpenState = true;
        if (card.x <= 0 || card.y <= 0) {
            card.x = Math.round(Math.max(20, (window.width - card.width) / 2));
            card.y = Math.round(Math.max(20, (window.height - card.height) / 2));
        }
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
        enabled: !window.isPreviewMode && (settingsManager ? settingsManager.previewWindow === "" : true)
        visible: enabled
        onClicked: {
            if (settingsManager && settingsManager.previewWindow !== "") {
                settingsManager.previewWindow = "";
            } else {
                window.close();
            }
        }
    }

    Rectangle {
        id: card
        x: Math.round(Math.max(20, (window.width - width) / 2))
        y: Math.round(Math.max(20, (window.height - height) / 2))

        width: settingsManager ? settingsManager.getWindowWidth(window.windowId, 1040) : 1040
        height: settingsManager ? settingsManager.getWindowHeight(window.windowId, 760) : 760

        radius: theme.defaultCardRadius
        color: theme.base01
        border.width: theme.globalBorderWidth
        border.color: theme.base03
        clip: true

        MouseArea { anchors.fill: parent; preventStealing: true }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true; height: Math.max(44, window.overlayFontSize * 2.4); color: theme.base00
                border.width: 1; border.color: theme.base03

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.SizeAllCursor
                    drag.target: card
                    drag.minimumX: 0; drag.minimumY: 0
                    drag.maximumX: Math.max(0, window.width - card.width)
                    drag.maximumY: Math.max(0, window.height - card.height)
                }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12; spacing: 10
                    Text { text: "⚙"; font.pixelSize: Math.max(18, window.overlayFontSize + 2); color: theme.base05 }
                    Text { text: "SYSTEM SETTINGS & PREFERENCES"; font.bold: true; font.pixelSize: Math.max(12, window.overlayFontSize - 2); color: theme.base05; Layout.fillWidth: true }
                    Rectangle {
                        width: 28; height: 28; radius: 4; color: "transparent"; border.color: theme.base08; border.width: 1
                        Text { anchors.centerIn: parent; text: "✕"; font.bold: true; font.pixelSize: 13; color: theme.base08 }
                        MouseArea { anchors.fill: parent; onClicked: window.close() }
                    }
                }
            }

            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
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
        enabled: window.visible
        onActivated: {
            if (settingsManager && settingsManager.previewWindow !== "") {
                settingsManager.previewWindow = "";
            } else {
                window.close();
            }
        }
    }
}
