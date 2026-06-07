import QtQuick
import Quickshell
import "."

Item {
    id: root

    width: 1500
    height: 900
    focus: true

    property alias innerListView: emailListContainer.innerListView

    property var stylixTheme: {
        if (typeof launcherRoot !== "undefined" && launcherRoot && launcherRoot.ctrl && launcherRoot.ctrl.theme)
            return launcherRoot.ctrl.theme;
        if (typeof shell !== "undefined" && shell && shell.theme)
            return shell.theme;
        return null;
    }

    EmailController {
        id: controller
    }

    EmailProcesses {
        id: processes
        controller: controller
    }

    Connections {
        target: controller

        // FIXED: Automatically updates the right-side preview text window at 0 enter presses when rows change
        function onCurrentListIndexChanged() {
            emailListContainer.openCurrentMessage();
        }

        function onIsReplyingChanged() {
            if (!controller.isReplying && !controller.isComposing) {
                emailListContainer.innerListView.forceActiveFocus()
            }
        }
        function onIsComposingChanged() {
            if (!controller.isReplying && !controller.isComposing) {
                emailListContainer.innerListView.forceActiveFocus()
            }
        }
    }
    Keys.onPressed: (event) => {
        if (controller.isReplying || controller.isComposing)
            return;

        if (event.key === Qt.Key_F5) {
            processes.refreshMail();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_N) {
            controller.composeToAddress = "";
            controller.composeSubject = "";
            controller.composeBodyText = "";
            controller.isComposing = true;
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_I) {
            controller.isImportantOnlyView = !controller.isImportantOnlyView;
            processes.refreshMail();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Up) {
            if (emailListContainer.innerListView.currentIndex > 0) {
                emailListContainer.innerListView.currentIndex--;
                controller.currentListIndex = emailListContainer.innerListView.currentIndex;
            }
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Down) {
            if (emailListContainer.innerListView.currentIndex < emailListContainer.innerListView.count - 1) {
                emailListContainer.innerListView.currentIndex++;
                controller.currentListIndex = emailListContainer.innerListView.currentIndex;
            }
            event.accepted = true;
            return;
        }

        // FIXED: Requires exactly 1 enter press to toggle the reply pop-up box open over your stack
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            controller.isReplying = true;
            event.accepted = true;
            return;
        }
    }
    Rectangle {
        anchors.fill: parent
        color: root.stylixTheme ? root.stylixTheme.base00 : "#111115"
        border.color: root.stylixTheme ? root.stylixTheme.base03 : "#333345"
        border.width: root.stylixTheme ? root.stylixTheme.globalBorderWidth : 1
        radius: root.stylixTheme ? root.stylixTheme.defaultCardRadius : 8

        Row {
            anchors.fill: parent
            anchors.margins: root.stylixTheme ? root.stylixTheme.globalPadding : 12
            spacing: root.stylixTheme ? root.stylixTheme.globalPadding : 12

            EmailSidebar {
                width: parent.width * 0.15
                height: parent.height
                controller: controller
                processes: processes
                stylixTheme: root.stylixTheme
            }

            EmailList {
                id: emailListContainer
                width: parent.width * 0.32
                height: parent.height
                controller: controller
                processes: processes
                stylixTheme: root.stylixTheme
            }

            EmailPreview {
                width: parent.width * 0.53 - (root.stylixTheme ? root.stylixTheme.globalPadding : 12)
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
