import QtQuick
import QtQuick.Controls 2
import Quickshell
import "../../style"
import "../../common"

Item {
    id: notifyBox

    property var barWindow: null
    property string moduleName: "notify"
    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: (shell && shell.theme && shell.theme.slantWidth) ? shell.theme.slantWidth : 12

    property bool isLocked: (typeof sessionLock !== "undefined" && sessionLock && sessionLock.locked)
    property bool isDisabled: (typeof shell !== "undefined" && shell && !shell.notificationsEnabled)
    property int notifCount: (typeof shell !== "undefined" && shell) ? shell.unreadCount : 0

    implicitWidth: notifyText.implicitWidth + bg.leftPadding + bg.rightPadding + 20
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        containmentMask: bg
        slantLeft: notifyBox.slantLeft
        slantRight: notifyBox.slantRight
        slantWidth: notifyBox.slantWidth

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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (notifyBox.isLocked) return;
            if (mouse.button === Qt.LeftButton) {
                if (typeof shell !== "undefined" && shell) {
                    shell.notificationsEnabled = !shell.notificationsEnabled;
                }
            } else if (mouse.button === Qt.RightButton) {
                if (typeof shell !== "undefined" && shell) {
                    shell.showHistoryMode = !shell.showHistoryMode;
                }
            }
        }
    }

    Text {
        id: notifyText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 4
        anchors.rightMargin: bg.rightPadding + 4
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        textFormat: Text.RichText

        text: {
            var labelColor = (shell && shell.theme) ? (notifyBox.isDisabled ? shell.theme.base04 : shell.theme.base05) : "yellow";
            var countColor = (shell && shell.theme) ? (notifyBox.isDisabled ? shell.theme.base08 : shell.theme.base05) : "yellow";
            return "<font color='" + labelColor + "'>Notifications:</font> <font color='" + countColor + "'>" + notifyBox.notifCount + "</font>";
        }

        font.family: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"
        font.pixelSize: (shell && shell.theme) ? (shell.theme.globalFontSize || 14) : 14
        font.bold: true
        color: (shell && shell.theme) ? (shell.theme.base05 || "yellow") : "yellow"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        clip: true
    }
}
