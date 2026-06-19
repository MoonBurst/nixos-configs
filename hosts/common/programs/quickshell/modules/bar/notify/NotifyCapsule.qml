import QtQuick
import QtQuick.Controls
import Quickshell

Rectangle {
    id: notifyBox

    // Compatibility properties to align with your status bar layout engine
    property var barWindow: null

    // Resolve global states directly from the master shell root scope
    property bool isLocked: (typeof sessionLock !== "undefined" && sessionLock && sessionLock.locked)
    property bool isDisabled: (typeof shell !== "undefined" && shell && !shell.notificationsEnabled)
    property int notifCount: (typeof shell !== "undefined" && shell) ? shell.unreadCount : 0

    width: parent ? parent.width : 200
    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth

    // Capsule background color always remains standard base00 (never changes on active history)
    color: shell.theme.base00

    // State-based outline border transitions (ONLY changes on paused/unpaused, never on active history)
    border.color: {
        if (notifyBox.isLocked) return shell.theme.base03; // Same color as currently when locked
        if (notifyBox.isDisabled) return shell.theme.base08; // Red outline when paused
        return shell.theme.base05; // base05 outline when unpaused
    }

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton // Handles both left and right clicks
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (notifyBox.isLocked) return; // Prevent clicks while screen is locked

            if (mouse.button === Qt.LeftButton) {
                // Left-click now toggles the Do Not Disturb (disabled) state on the master scope
                if (typeof shell !== "undefined" && shell) {
                    shell.notificationsEnabled = !shell.notificationsEnabled;
                }
            } else if (mouse.button === Qt.RightButton) {
                // Right-click toggles the history drawer
                Ipc.call("global_notif", "toggleHistory");
            }
        }
    }

    Text {
        id: notifyText
        anchors.centerIn: parent
        textFormat: Text.RichText

        // Dynamically styles text colors and labels to provide instant, high-fidelity visual indicators (ONLY toggles on pause)
        text: {
            var labelColor = "";
            var countColor = "";

            if (notifyBox.isLocked) {
                labelColor = shell.theme.base04;
                countColor = shell.theme.base04;
            } else if (notifyBox.isDisabled) {
                labelColor = shell.theme.base04; // Muted label when paused
                countColor = shell.theme.base08; // Red count showing backlog when paused
            } else {
                labelColor = shell.theme.base05; // base05 normally
                countColor = shell.theme.base05; // base05 normally
            }

            return "<font color='" + labelColor + "'>Notifications:</font> <font color='" + countColor + "'>" + notifyBox.notifCount + "</font>";
        }

        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        color: shell.theme.base05
    }
}
