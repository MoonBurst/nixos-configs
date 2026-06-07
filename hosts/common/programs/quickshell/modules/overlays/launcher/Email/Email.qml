import QtQuick
import Quickshell
import "."

Item {
    id: root

    width: 1500
    height: 900
    focus: true

    property alias innerListView: emailListContainer.innerListView
    property var folderOrder: ["INBOX", "ALL MAIL", "DRAFTS", "SENT MAIL", "SPAM", "STARRED", "IMPORTANT", "TRASH"]

    property var stylixTheme: {
        if (typeof launcherRoot !== "undefined" && launcherRoot && launcherRoot.ctrl && launcherRoot.ctrl.theme)
            return launcherRoot.ctrl.theme;
        if (typeof shell !== "undefined" && shell && shell.theme)
            return shell.theme;
        return null;
    }

    EmailController { id: controller }
    EmailProcesses { id: processes; controller: controller }

    // Unified message loader subroutine used by both scrolling and folder shifts
    function triggerMessagePreview() {
        if (emailListContainer.innerListView.count > 0 && emailListContainer.innerListView.currentIndex >= 0) {
            var filtered = emailListContainer.getFilteredEmails();
            var email = filtered[emailListContainer.innerListView.currentIndex];
            if (!email) return;

            var env = email.envelope ? email.envelope : email;
            var msgId = email.id ? String(email.id) : (env && env.id ? String(env.id) : "");
            msgId = msgId.trim();
            if (!msgId) return;

            controller.selectedId = msgId;
            controller.messageBody = "Loading message...";
            var fromObj = email.from ? email.from : env.from;
            controller.currentReplyTo = fromObj ? (fromObj.addr || fromObj || "") : "";
            controller.currentSubject = email.subject ? email.subject : (env.subject ? env.subject : "");
            if (controller.currentSubject.toLowerCase().indexOf("re:") !== 0) {
                controller.currentSubject = "Re: " + controller.currentSubject;
            }
            processes.loadMessage(msgId);
        } else {
            // FIXED: If the folder is entirely empty, clear out the leftover preview layout text
            controller.selectedId = "";
            controller.messageBody = "(No messages in this folder)";
        }
    }

    Timer {
        id: selectionDebounceTimer
        interval: 150
        repeat: false
        running: false
        onTriggered: {
            root.triggerMessagePreview();
        }
    }

    function cycleFolder(forward) {
        var current = controller.currentFolder ? String(controller.currentFolder).toUpperCase() : "INBOX";
        var idx = folderOrder.indexOf(current);
        if (idx === -1) idx = 0;

        idx = forward ? (idx + 1) % folderOrder.length : (idx - 1 + folderOrder.length) % folderOrder.length;
        controller.currentFolder = folderOrder[idx];

        emailListContainer.innerListView.currentIndex = 0;
        controller.currentListIndex = 0;

        root.forceActiveFocus();
    }

    Connections {
        target: controller
        function onCurrentListIndexChanged() { selectionDebounceTimer.restart(); }

        // FIXED: Handles first-message preview loading natively AFTER dataset swapping completes safely
        function onCurrentFolderChanged() {
            root.forceActiveFocus();
            root.triggerMessagePreview();
        }
    }

    Keys.onPressed: (event) => {
        if (controller.isReplying || controller.isComposing) return;

        if (event.key === Qt.Key_Up && (event.modifiers & Qt.AltModifier)) {
            cycleFolder(false);
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Down && (event.modifiers & Qt.AltModifier)) {
            cycleFolder(true);
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            if (emailListContainer.innerListView.count > 0) {
                var filtered = emailListContainer.getFilteredEmails();
                var mail = filtered[emailListContainer.innerListView.currentIndex];
                if (mail) {
                    var env = mail.envelope ? mail.envelope : mail;
                    var msgId = mail.id ? String(mail.id) : (env && env.id ? String(env.id) : "");
                    if (msgId) {
                        var tmpDeleted = emailListContainer.locallyDeletedIds.slice();
                        tmpDeleted.push(msgId);
                        emailListContainer.locallyDeletedIds = tmpDeleted;
                        controller.selectedId = "";
                        controller.statusMessage = "Deleting message...";
                        processes.deleteMessage(msgId);
                    }
                }
            }
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

        if (event.key === Qt.Key_F5) {
            processes.refreshMail();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Up) {
            if (emailListContainer.innerListView.count > 0 && emailListContainer.innerListView.currentIndex > 0) {
                emailListContainer.innerListView.currentIndex--;
                emailListContainer.innerListView.positionViewAtIndex(emailListContainer.innerListView.currentIndex, ListView.Contain);
                controller.currentListIndex = emailListContainer.innerListView.currentIndex;
            }
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Down) {
            if (emailListContainer.innerListView.count > 0 && emailListContainer.innerListView.currentIndex < emailListContainer.innerListView.count - 1) {
                emailListContainer.innerListView.currentIndex++;
                emailListContainer.innerListView.positionViewAtIndex(emailListContainer.innerListView.currentIndex, ListView.Contain);
                controller.currentListIndex = emailListContainer.innerListView.currentIndex;
            }
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            controller.isReplying = true;
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
            emailListContainer.forceSearchFocus();
            event.accepted = true;
            return;
        }
    }

    Component.onCompleted: { root.forceActiveFocus(); }

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

            EmailSidebar { width: parent.width * 0.15; height: parent.height; controller: controller; processes: processes; stylixTheme: root.stylixTheme }
            EmailList { id: emailListContainer; width: parent.width * 0.32; height: parent.height; controller: controller; processes: processes; stylixTheme: root.stylixTheme }
            EmailPreview { width: parent.width * 0.52 - (root.stylixTheme ? root.stylixTheme.globalPadding : 12); height: parent.height; controller: controller; processes: processes; stylixTheme: root.stylixTheme }
        }
    }

    ComposeDialog { controller: controller; processes: processes; stylixTheme: root.stylixTheme }
    ReplyDialog { controller: controller; processes: processes; stylixTheme: root.stylixTheme }
}
