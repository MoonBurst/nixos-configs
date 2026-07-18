import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland

// Import your custom style module relative to this widget's location
import "../../style"

Item {
    id: clockBox

    // Sizing & Layout
    anchors.fill: parent

    // Centralized SlantedBox Background
    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: "Left"
        slantRight: "Right"
    }

    // Global Widget Window Tracking Properties
    property var barWindow: null
    property string dateStr: "12:00:00 PM"

    // Primary Bar Clock Update Loop (12-Hour Format with AM/PM)
    Timer {
        id: clockPollerTimer
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

        //  clear margins using SlantedBox paddings
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: (shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12
        anchors.bottomMargin: (shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12

        color: (shell && shell.theme) ? (shell.theme.base05 || "yellow") : "yellow"
        font.family: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"
        font.pixelSize: (shell && shell.theme) ? (shell.theme.globalFontSize || 14) : 14
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

        // HOVER ACTIVATION: Tied to the bar clock capsule hover tracker state
        visible: clockHoverTracker.hovered

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-timezone-matrix"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.left: true
        anchors.right: false
        anchors.bottom: false

        // Rigid panel specifications to prevent size 25 text layout truncations
        implicitWidth: 1480
        implicitHeight: 520
        color: "transparent"

        // Drops popover right below top bar surface line
        WlrLayershell.margins.top: {
            if (!clockBox.barWindow || typeof mainBarContainer === "undefined" || !mainBarContainer) return 100;
            return ((shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12) + mainBarContainer.capsuleHeight + 8;
        }

        // Centers matrix popover perfectly beneath active bar clock element
        WlrLayershell.margins.left: {
            if (!clockBox.barWindow || typeof clockContainer === "undefined" || !clockContainer) return 100;

            var containerX = clockContainer.x;
            var clockCenterAbsolute = containerX + (clockContainer.width / 2);
            var targetLeftMargin = Math.round(clockCenterAbsolute - (implicitWidth / 2));

            // Off-screen safety constraint boundary layout block
            if (targetLeftMargin < ((shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12)) {
                return (shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12;
            }

            return targetLeftMargin;
        }

        // Inside content card structural component instantiation (Centered widescreen layout)
        ClockMatrixPopupView {
            anchors.fill: parent
        }
    }
}
