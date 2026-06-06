import QtQuick
import Quickshell
import "."

Item {
    id: root

    // Explicit widescreen footprint passed down cleanly to nested views
    width: 1500
    height: 900

    focus: true

    property alias innerListView: emailListContainer.innerListView

    Connections {
        target: controller
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

        if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
            emailListContainer.forceSearchFocus();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Up) {
            if (emailListContainer.innerListView.currentIndex > 0) {
                emailListContainer.innerListView.currentIndex--;
                emailListContainer.innerListView.positionViewAtIndex(
                    emailListContainer.innerListView.currentIndex,
                    ListView.Contain
                );
            }
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Down) {
            if (emailListContainer.innerListView.currentIndex < emailListContainer.innerListView.count - 1) {
                emailListContainer.innerListView.currentIndex++;
                emailListContainer.innerListView.positionViewAtIndex(
                    emailListContainer.innerListView.currentIndex,
                    ListView.Contain
                );
            }
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            var email = controller.emails[emailListContainer.innerListView.currentIndex];
            if (email) {
                if (controller.selectedId === email.id &&
                    controller.messageBody !== "" &&
                    controller.messageBody.indexOf("Loading") !== 0) {

                    controller.isReplying = true;
                    } else {
                        emailListContainer.openCurrentMessage();
                    }
            }
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Delete) {
            emailListContainer.deleteCurrentMessage();
            event.accepted = true;
            return;
        }

    }

    EmailController {
        id: controller
    }

    EmailProcesses {
        id: processes
        controller: controller
    }

    property var stylixTheme: {
        if (typeof launcherRoot !== "undefined" && launcherRoot.ctrl && launcherRoot.ctrl.theme)
            return launcherRoot.ctrl.theme

            if (typeof shell !== "undefined" && shell.theme)
                return shell.theme

                if (typeof theme !== "undefined")
                    return theme

                    return null
    }
    Rectangle {
        anchors.fill: parent
        color: root.stylixTheme ? root.stylixTheme.base00 : "#111115"

        // RESTORED BORDER LAYER: Formally draws the outline border bubble around the workspace container frame
        border.color: root.stylixTheme ? root.stylixTheme.base03 : "#333345"
        border.width: root.stylixTheme ? root.stylixTheme.globalBorderWidth : 1
        radius: root.stylixTheme ? root.stylixTheme.defaultCardRadius : 8

        Row {
            anchors.fill: parent
            anchors.margins: root.stylixTheme ? root.stylixTheme.globalPadding : 12
            spacing: root.stylixTheme ? root.stylixTheme.globalPadding : 12

            EmailList {
                id: emailListContainer

                width: parent.width * 0.42
                height: parent.height

                controller: controller
                processes: processes
                stylixTheme: root.stylixTheme
            }

            EmailPreview {
                width: parent.width * 0.58 - (root.stylixTheme ? root.stylixTheme.globalPadding : 12)
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
