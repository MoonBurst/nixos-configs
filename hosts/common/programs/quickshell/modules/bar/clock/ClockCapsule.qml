import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland

Rectangle {
    id: clockBox

    width: 150
    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth
    color: shell.theme.base00
    border.color: shell.theme.base05

    property var barWindow: null
    property string timeStr: "00:00:00 AM"

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var date = new Date()
            clockBox.timeStr = date.toLocaleTimeString(Qt.locale(), "hh:mm:ss AP")
        }
    }

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
        text: clockBox.timeStr
    }

    HoverHandler {
        id: clockHoverTracker
    }

    // ============================================================================
    // THE MATRIX POPOVER PANEL WINDOW (PROPERTIES BOUND TO WORKSPACE CONTAINER)
    // ============================================================================
    PanelWindow {
        id: matrixTooltipWindow

        screen: clockBox.barWindow ? clockBox.barWindow.screen : null
        visible: clockHoverTracker.hovered

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-calendar-tooltip"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.left: true
        anchors.right: false
        anchors.bottom: false

        implicitWidth: 800
        implicitHeight: 400
        color: "transparent"

        // ============================================================================
        // PURE PROPERTY BINDINGS (RECALCULATES ON EVERY SINGLE TRAY/LAYOUT RESIZE)
        // ============================================================================
        WlrLayershell.margins.left: {
            if (!clockBox.barWindow) return 0;

            // Get the starting point of the inner bar (accounting for your screen padding)
            var barStart = shell.theme.globalPadding;

            // Because the clock uses anchors.centerIn: parent, its center point is
            // always exactly half the total width of the main bar container!
            var clockCenterAbsolute = barStart + (mainBarContainer.width / 2);

            // Center the tooltip directly underneath that active absolute center coordinate
            return Math.round(clockCenterAbsolute - (implicitWidth / 2));
        }

        WlrLayershell.margins.top: {
            if (!clockBox.barWindow) return 0;

            // Combines top screen padding, bar panel height, and a 8px layout gap
            return shell.theme.globalPadding + 50 + 8;
        }

        Rectangle {
            anchors.fill: parent
            radius: shell.theme.defaultCardRadius
            border.width: shell.theme.globalBorderWidth
            color: shell.theme.base00
            border.color: shell.theme.base05

            ClockMatrixPopupView {
                anchors.fill: parent
                anchors.margins: shell.theme.globalPadding
            }
        }
    }
}
