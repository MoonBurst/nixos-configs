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
        width: settingsManager ? settingsManager.getWindowWidth(window.windowId, 1040) : 1040
        height: settingsManager ? settingsManager.getWindowHeight(window.windowId, 760) : 760
        x: Math.round(Math.max(20, (window.width - width) / 2))
        y: Math.round(Math.max(20, (window.height - height) / 2))

        radius: theme.defaultCardRadius
        color: theme.base01
        border.width: theme.globalBorderWidth
        border.color: theme.base03

        MouseArea { anchors.fill: parent; preventStealing: true }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: theme.globalBorderWidth
            spacing: 0

            // Title Bar (Follows card top radius, no square outer border)
            Rectangle {
                id: titleBarBox
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(46, Math.round(window.overlayFontSize * 2.4))
                Layout.minimumHeight: Layout.preferredHeight
                color: theme.base00

                // Match top curve of card seamlessly
                radius: card.radius
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.radius
                    color: theme.base00
                }

                // Single clean separator line underneath title bar
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: theme.base03
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
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
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
                    Rectangle {
                        width: 28; height: 28; radius: 6
                        color: "transparent"
                        border.color: theme.base08
                        border.width: 1.5
                        Text { anchors.centerIn: parent; text: "✕"; font.bold: true; font.pixelSize: 13; color: theme.base08 }
                        MouseArea { anchors.fill: parent; onClicked: window.close() }
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
