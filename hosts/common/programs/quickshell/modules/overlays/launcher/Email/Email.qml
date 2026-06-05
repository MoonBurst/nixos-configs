import QtQuick
import Quickshell
import "."

Item {
    id: root
    focus: true

    EmailController {
        id: controller
    }

    EmailProcesses {
        id: processes
        controller: controller
    }

    property var stylixTheme: {
        if (typeof launcherRoot !== "undefined" &&
            launcherRoot.ctrl &&
            launcherRoot.ctrl.theme)
            return launcherRoot.ctrl.theme

        if (typeof shell !== "undefined" && shell.theme)
            return shell.theme

        if (typeof theme !== "undefined")
            return theme

        return null
    }

    Shortcut {
        sequence: "F5"

        onActivated: {
            if (!controller.isReplying &&
                !controller.isComposing) {
                processes.refreshMail()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: stylixTheme ? stylixTheme.base00 : "#111111"

        Row {
            anchors.fill: parent
            anchors.margins:
                stylixTheme ? stylixTheme.globalPadding : 8

            spacing:
                stylixTheme ? stylixTheme.globalPadding : 8

            EmailList {
                id: emailList

                width: parent.width * 0.42
                height: parent.height

                controller: controller
                processes: processes
                stylixTheme: root.stylixTheme
            }

            EmailPreview {
                width: parent.width * 0.58 -
                       (stylixTheme
                        ? stylixTheme.globalPadding
                        : 8)

                height: parent.height

                controller: controller
                processes: processes
                stylixTheme: root.stylixTheme
            }
        }
    }

    ComposeDialog {
        controller: controller
        processes: processes
        stylixTheme: root.stylixTheme
    }

    ReplyDialog {
        controller: controller
        processes: processes
        stylixTheme: root.stylixTheme
    }

    Timer {
        interval: 300000
        repeat: true
        running: true

        onTriggered: processes.refreshMail()
    }
}
