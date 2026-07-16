import QtQuick
import QtQuick.Controls 2
import Quickshell
import "../../style"

Item {
    id: notifyBox

    property var barWindow: null

    // Resolve global states directly from the master shell root scope
    property bool isLocked: (typeof sessionLock !== "undefined" && sessionLock && sessionLock.locked)
    property bool isDisabled: (typeof shell !== "undefined" && shell && !shell.notificationsEnabled)
    property int notifCount: (typeof shell !== "undefined" && shell) ? shell.unreadCount : 0

    width: parent ? parent.width : 200
    height: parent.height

    // Centralized SlantedBox Background
    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: "Left"
        slantRight: "Left"

        borderColor: {
            if (shell && shell.theme) {
                if (notifyBox.isLocked) return shell.theme.base03;
                if (notifyBox.isDisabled) return shell.theme.base08;
                return shell.theme.base05;
            }
            return "yellow";
        }
    }

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

            if (shell && shell.theme) {
                if (notifyBox.isLocked) {
                    labelColor = shell.theme.base04;
                    countColor = shell.theme.base04;
                } else if (notifyBox.isDisabled) {
                    labelColor = shell.theme.base04;
                    countColor = shell.theme.base08;
                } else {
                    labelColor = shell.theme.base05;
                    countColor = shell.theme.base05;
                }
            } else {
                labelColor = "yellow";
                countColor = "yellow";
            }

            return "<font color='" + labelColor + "'>Notifications:</font> <font color='" + countColor + "'>" + notifyBox.notifCount + "</font>";
        }

        font.family: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"
        font.pixelSize: (shell && shell.theme) ? (shell.theme.globalFontSize || 14) : 14
        font.bold: true
        color: (shell && shell.theme) ? (shell.theme.base05 || "yellow") : "yellow"
    }
}
