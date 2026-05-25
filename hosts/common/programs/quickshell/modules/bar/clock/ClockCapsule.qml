import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland

Rectangle {
    id: clockBox

    // Sizing & Theme Styling Core Profiles
    anchors.fill: parent
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth
    color: shell.theme.base00
    border.color: shell.theme.base05

    // Global Widget Window Tracking Properties
    property var barWindow: null
    property string dateStr: "12:00:00 PM"

    // Primary Bar Clock Update Loop (12-Hour Format with AM/PM)
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var date = new Date()
            clockBox.dateStr = date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
        }
    }

    // Main Bar Text Display Item
    Text {
        id: clockText
        anchors.fill: parent
        anchors.margins: 4
        color: shell.theme.base05
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: clockBox.dateStr
    }

    HoverHandler {
        id: clockHoverTracker
    }

    // ============================================================================
    // THE TIMEZONE MATRIX POPOVER PANEL WINDOW
    // ============================================================================
    PanelWindow {
        id: timezoneClockWindow

        // Wayland Surface Connection Mechanics
        screen: clockBox.barWindow ? clockBox.barWindow.screen : null

        // TESTING FLAG: Set to true for layout verification. Change to clockHoverTracker.hovered later.
        visible: true

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-timezone-matrix"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.left: true
        anchors.right: false
        anchors.bottom: false

        // Updated geometry dimensions mapping the 1480px structural layout wide requirement
        implicitWidth: 1480
        implicitHeight: 480
        color: "transparent"

        // DYNAMIC TOP ALIGNMENT (Drops popover right below top bar surface line)
        WlrLayershell.margins.top: {
            if (!clockBox.barWindow || typeof mainBarContainer === "undefined" || !mainBarContainer) return 100;
            return shell.theme.globalPadding + mainBarContainer.capsuleHeight + 8;
        }

        // DYNAMIC LEFT ALIGNMENT (Centers matrix popover perfectly beneath active bar clock element)
        WlrLayershell.margins.left: {
            if (!clockBox.barWindow || typeof clockContainer === "undefined" || !clockContainer) return 100;

            var containerX = clockContainer.x;
            var clockCenterAbsolute = containerX + (clockContainer.width / 2);
            var targetLeftMargin = Math.round(clockCenterAbsolute - (implicitWidth / 2));

            // Off-screen safety constraint boundary layout block
            if (targetLeftMargin < shell.theme.globalPadding) {
                return shell.theme.globalPadding;
            }

            return targetLeftMargin;
        }

        // Inside content card structural component instantiation
        ClockMatrixPopupView {
            anchors.fill: parent
        }
    }
}
