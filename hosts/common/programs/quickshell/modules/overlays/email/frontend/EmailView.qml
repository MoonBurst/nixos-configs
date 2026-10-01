import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import "../../../common"
import "../backend"

Item {
    id: viewRoot
    
    required property EmailEngine engine
    property var theme: null
    property var settingsManager: null
    
    readonly property color windowBgColor: (theme && theme.base00) ? theme.base00 : "#121212"
    readonly property color outerBorderColor: (theme && theme.outerBorderColor) ? theme.outerBorderColor : "#003399"
    readonly property color innerBorderColor: (theme && theme.innerBorderColor) ? theme.innerBorderColor : "#FABD2F"
    readonly property int outerBorderThickness: 5
    readonly property int innerCardActiveThickness: 5
    
    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
    ? settingsManager.overlayFontSize
    : ((theme && theme.overlayFontSize) ? theme.overlayFontSize : 16)
    
    property int sidebarColumnWidth: Math.max(180, Math.round(width * 0.17))
    property int listingColumnWidth: Math.max(300, Math.round(width * 0.33))
    property int previewColumnWidth: Math.max(380, width - sidebarColumnWidth - listingColumnWidth)
    
    signal closeRequested()
    
    focus: true
    
    function clearAndFocus() {
        mailListView.focus = true;
        Qt.callLater(() => mailListView.forceActiveFocus());
    }
    
    Component.onCompleted: Qt.callLater(() => mailListView.forceActiveFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => mailListView.forceActiveFocus())
    
    function isModalActive() {
        return (typeof himalayaInstallModalOverlay !== "undefined" && himalayaInstallModalOverlay && himalayaInstallModalOverlay.visible)
        || (typeof contactModalOverlay !== "undefined" && contactModalOverlay && contactModalOverlay.visible)
        || (typeof helpModalOverlay !== "undefined" && helpModalOverlay && helpModalOverlay.visible);
    }
    
    Shortcut {
        sequence: "Ctrl+F"
        enabled: !engine.isComposing && !viewRoot.isModalActive()
        onActivated: mailListView.toggleSearch()
    }
    
    Shortcut {
        sequence: "/"
        enabled: !engine.isComposing && !viewRoot.isModalActive()
        onActivated: mailListView.toggleSearch()
    }
    
    function initiateEmailReply() {
        var activeItem = engine.selectedMail;
        if (!activeItem) return;
        var replyTo = activeItem.from ? (activeItem.from.addr || activeItem.from.name) : "";
        var conversationLog = "\n\n----------------------------------------\nFrom: " + replyTo + "\nSubject: " + activeItem.subject + "\n\n" + engine.activeMailBody;
        engine.isComposing = true;
        composeWindowOverlay.prepopulateForm(replyTo, activeItem.subject.startsWith("Re:") ? activeItem.subject : "Re: " + activeItem.subject, conversationLog);
    }
    
    function initiateDraftEdit() {
        var activeItem = engine.selectedMail;
        if (!activeItem) return;
        var draftTo = activeItem.from ? (activeItem.from.addr || activeItem.from.name) : "";
        var draftSubject = activeItem.subject || "";
        var draftBody = engine.activeMailBody || "";
        engine.isComposing = true;
        composeWindowOverlay.restoreDraftForm(draftTo, draftSubject, draftBody);
    }
    
    Keys.onPressed: (event) => {
        if (engine.isComposing || viewRoot.isModalActive()) return;
        var isAltPressed = (event.modifiers === Qt.AltModifier) || (event.modifiers & Qt.AltModifier) !== 0;
        
        if (isAltPressed) {
            if (event.key === Qt.Key_Up) { engine.cycleFolder(false); event.accepted = true; }
            else if (event.key === Qt.Key_Down) { engine.cycleFolder(true); event.accepted = true; }
        } else {
            if (event.key === Qt.Key_Up) { engine.cycleEmail(false); event.accepted = true; }
            else if (event.key === Qt.Key_Down) { engine.cycleEmail(true); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var activeItem = engine.selectedMail;
                if (activeItem && activeItem.folder.toLowerCase() === "drafts") {
                    initiateDraftEdit();
                } else {
                    initiateEmailReply();
                }
                event.accepted = true;
            }
            else if (event.key === Qt.Key_Delete) { engine.handleDeletion(); event.accepted = true; }
            else if (event.key === Qt.Key_U) { engine.handleRestoreFromTrash(); event.accepted = true; }
            else if (event.key === Qt.Key_N) { engine.isComposing = true; composeWindowOverlay.prepopulateForm("", "", ""); event.accepted = true; }
            else if (event.key === Qt.Key_S) { engine.handleStarToggle(); event.accepted = true; }
            else if (event.key === Qt.Key_R) { engine.handleReadToggle(); event.accepted = true; }
            else if (event.text === "?") { helpModalOverlay.visible = true; event.accepted = true; }
        }
    }
    
    Rectangle {
        anchors.fill: parent
        color: viewRoot.windowBgColor
        border.color: viewRoot.outerBorderColor
        border.width: viewRoot.outerBorderThickness
        radius: (theme && theme.defaultCardRadius) ? theme.defaultCardRadius : 10
        
        Row {
            anchors.fill: parent
            
            SidebarView {
                width: viewRoot.sidebarColumnWidth; height: parent.height
                folderListModel: engine.folderList; activeFolderIndex: engine.currentFolderIndex
                countsDictionary: engine.folderCountMap
                fontSize: viewRoot.overlayFontSize
                onHelpRequested: helpModalOverlay.visible = true
            }
            
            EmailListView {
                id: mailListView
                width: viewRoot.listingColumnWidth; height: parent.height
                mailItems: engine.filteredMails; activeMailIndex: engine.currentMailIndex
                focus: true
                textMainSize: viewRoot.overlayFontSize
                textSubSize: Math.max(11, viewRoot.overlayFontSize - 2)
                
                onSearchQueryChanged: engine.searchString = searchQuery
                onSearchCaseSensitiveChanged: engine.searchCaseSensitive = searchCaseSensitive
                onStarToggled: (index) => { engine.currentMailIndex = index; engine.selectedMail = engine.filteredMails[index]; engine.handleStarToggle(); }
                onReadToggled: (index) => { engine.currentMailIndex = index; engine.selectedMail = engine.filteredMails[index]; engine.handleReadToggle(); }
            }
            
            EmailPreview {
                width: viewRoot.previewColumnWidth; height: parent.height
                activeMailObject: engine.selectedMail
                activeMailBodyText: engine.activeMailBody
                titleSize: viewRoot.overlayFontSize + 2
                metaSize: Math.max(11, viewRoot.overlayFontSize - 2)
                bodySize: viewRoot.overlayFontSize
                onContactRequested: (email) => contactModalOverlay.openContactPrompt(email)
                onDownloadAttachmentsRequested: (msgId, folderLabel) => {
                    engine.writeToQueue("DOWNLOAD_ATTACHMENTS", msgId, engine.getMaildirFolder(folderLabel), (Quickshell.env("HOME") + "/Downloads"));
                }
                onMarkSpamRequested: (msgId, folderLabel) => {
                    engine.writeToQueue("MOVE", msgId, engine.getMaildirFolder(folderLabel), "spam");
                    engine.readMailCache();
                }
                onRestoreSpamRequested: (msgId, folderLabel) => {
                    engine.writeToQueue("MOVE", msgId, engine.getMaildirFolder(folderLabel), "inbox");
                    engine.readMailCache();
                }
            }
        }
        
        ComposeModal {
            id: composeWindowOverlay
            anchors.fill: parent
            visible: engine.isComposing
            inputFontSize: viewRoot.overlayFontSize
            onEscapeDismissRequested: {
                engine.isComposing = false;
                mailListView.forceActiveFocus();
                engine.readMailCache();
            }
            onDispatchMailRequested: (to, subject, body) => {
                engine.handleOutboundDelivery(to, subject, body);
                mailListView.forceActiveFocus();
                engine.readMailCache();
            }
            onAttachmentRequested: fileDialog.open()
        }
        
        Rectangle {
            id: himalayaInstallModalOverlay
            anchors.fill: parent; color: "#F40F0F0F"; visible: false; z: 300
            function openInstallPrompt() { visible = true; pkgModal.openPrompt(); }
            MouseArea { anchors.fill: parent; onClicked: himalayaInstallModalOverlay.visible = false }
            
            Rectangle {
                width: 480; height: 240
                color: viewRoot.windowBgColor; border.color: viewRoot.innerBorderColor
                border.width: viewRoot.innerCardActiveThickness; radius: 10
                anchors.centerIn: parent
                
                PackageInstallerModal {
                    id: pkgModal
                    anchors.fill: parent; anchors.margins: 16
                    title: "🔑 INSTALL HIMALAYA (OFFICIAL REPOS)"
                    description: "Enter your sudo password to install himalaya from official repositories:"
                    pacmanPkg: "himalaya"
                    aptPkg: "himalaya"
                    dnfPkg: "himalaya"
                    zypperPkg: "himalaya"
                    nixPkg: "himalaya"
                    onInstalled: {
                        engine.himalayaInstalled = true;
                        himalayaInstallModalOverlay.visible = false;
                        engine.readMailCache();
                    }
                    onCancelled: himalayaInstallModalOverlay.visible = false
                }
            }
            Shortcut { sequence: "Escape"; enabled: himalayaInstallModalOverlay.visible; onActivated: himalayaInstallModalOverlay.visible = false }
        }
        
        Rectangle {
            id: contactModalOverlay; anchors.fill: parent; color: "#F40F0F0F"; visible: false
            property string targetEmail: ""
            function openContactPrompt(email) { targetEmail = email; nicknameInput.text = ""; visible = true; nicknameInput.forceActiveFocus(); }
            MouseArea { anchors.fill: parent; onClicked: contactModalOverlay.visible = false }
            
            Rectangle {
                width: 400; height: 220; color: viewRoot.windowBgColor; border.color: viewRoot.innerBorderColor
                border.width: viewRoot.innerCardActiveThickness; radius: 10; anchors.centerIn: parent
                
                Column {
                    anchors.fill: parent; anchors.margins: 20; spacing: 15
                    Text { text: "ADD TO CONTACTS"; font.bold: true; font.pixelSize: viewRoot.overlayFontSize; color: (theme && theme.base05) ? theme.base05 : "yellow" }
                    Text { text: "Email: " + contactModalOverlay.targetEmail; font.pixelSize: viewRoot.overlayFontSize - 2; color: (theme && theme.base06) ? theme.base06 : "white" }
                    
                    Rectangle {
                        width: parent.width; height: Math.max(38, viewRoot.overlayFontSize * 2); color: viewRoot.windowBgColor; border.color: (theme && theme.base03) ? theme.base03 : "#45475a"; border.width: 1; radius: 6
                        TextInput {
                            id: nicknameInput; anchors.fill: parent; anchors.margins: 8; font.pixelSize: viewRoot.overlayFontSize; color: (theme && theme.base06) ? theme.base06 : "white"
                            Text { text: "Enter nickname..."; color: "#666"; visible: parent.text === "" }
                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    engine.writeToQueue("CONTACT", nicknameInput.text, contactModalOverlay.targetEmail, "");
                                    contactModalOverlay.visible = false; mailListView.forceActiveFocus(); event.accepted = true;
                                }
                            }
                        }
                    }
                }
            }
            Shortcut { sequence: "Escape"; enabled: contactModalOverlay.visible; onActivated: { contactModalOverlay.visible = false; mailListView.forceActiveFocus(); } }
        }
        
        Rectangle {
            id: helpModalOverlay
            anchors.fill: parent
            color: "#F40F0F0F"
            visible: false
            z: 320
            
            MouseArea {
                anchors.fill: parent
                onClicked: helpModalOverlay.visible = false
            }
            
            Rectangle {
                width: 520
                height: 440
                color: viewRoot.windowBgColor
                border.color: viewRoot.innerBorderColor
                border.width: viewRoot.innerCardActiveThickness
                radius: 10
                anchors.centerIn: parent
                
                MouseArea { anchors.fill: parent }
                
                Column {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 14
                    
                    RowLayout {
                        width: parent.width
                        Text {
                            text: "KEYBOARD SHORTCUTS CHEATSHEET"
                            font.bold: true; font.pixelSize: viewRoot.overlayFontSize + 1
                            color: (theme && theme.base05) ? theme.base05 : "yellow"
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            width: 26; height: 26; radius: 4
                            color: "transparent"; border.color: (theme && theme.base08) ? theme.base08 : "#ff5555"; border.width: 1
                            Text { anchors.centerIn: parent; text: "✕"; font.bold: true; color: (theme && theme.base08) ? theme.base08 : "#ff5555" }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: helpModalOverlay.visible = false
                            }
                        }
                    }
                    
                    Rectangle { width: parent.width; height: 1; color: (theme && theme.base03) ? theme.base03 : "#45475a" }
                    
                    Grid {
                        columns: 2; columnSpacing: 24; rowSpacing: 10; width: parent.width
                        Text { text: "Alt + ↑ / ↓"; font.bold: true; font.pixelSize: viewRoot.overlayFontSize; color: (theme && theme.base05) ? theme.base05 : "yellow" }
                        Text { text: "Cycle Folders / Mailboxes"; font.pixelSize: viewRoot.overlayFontSize - 2; color: "#ccc" }
                        Text { text: "↑ / ↓"; font.bold: true; font.pixelSize: viewRoot.overlayFontSize; color: (theme && theme.base05) ? theme.base05 : "yellow" }
                        Text { text: "Cycle Emails in List"; font.pixelSize: viewRoot.overlayFontSize - 2; color: "#ccc" }
                        Text { text: "Ctrl + F or /"; font.bold: true; font.pixelSize: viewRoot.overlayFontSize; color: (theme && theme.base05) ? theme.base05 : "yellow" }
                        Text { text: "Search Emails"; font.pixelSize: viewRoot.overlayFontSize - 2; color: "#ccc" }
                        Text { text: "Enter / Return"; font.bold: true; font.pixelSize: viewRoot.overlayFontSize; color: (theme && theme.base05) ? theme.base05 : "yellow" }
                        Text { text: "Reply to Selected Email"; font.pixelSize: viewRoot.overlayFontSize - 2; color: "#ccc" }
                        Text { text: "N"; font.bold: true; font.pixelSize: viewRoot.overlayFontSize; color: (theme && theme.base05) ? theme.base05 : "yellow" }
                        Text { text: "Compose New Email"; font.pixelSize: viewRoot.overlayFontSize - 2; color: "#ccc" }
                        Text { text: "Delete"; font.bold: true; font.pixelSize: viewRoot.overlayFontSize; color: (theme && theme.base05) ? theme.base05 : "yellow" }
                        Text { text: "Delete Email"; font.pixelSize: viewRoot.overlayFontSize - 2; color: "#ccc" }
                        Text { text: "S"; font.bold: true; font.pixelSize: viewRoot.overlayFontSize; color: (theme && theme.base05) ? theme.base05 : "yellow" }
                        Text { text: "Toggle Star"; font.pixelSize: viewRoot.overlayFontSize - 2; color: "#ccc" }
                        Text { text: "R"; font.bold: true; font.pixelSize: viewRoot.overlayFontSize; color: (theme && theme.base05) ? theme.base05 : "yellow" }
                        Text { text: "Toggle Read"; font.pixelSize: viewRoot.overlayFontSize - 2; color: "#ccc" }
                    }
                    
                    Text {
                        text: "Press [ESC], [?], or click outside to dismiss"
                        font.pixelSize: Math.max(10, viewRoot.overlayFontSize - 4); color: "#666"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
            Shortcut {
                sequence: "Escape"
                enabled: helpModalOverlay.visible
                onActivated: helpModalOverlay.visible = false
            }
            Shortcut {
                sequence: "?"
                enabled: helpModalOverlay.visible
                onActivated: helpModalOverlay.visible = false
            }
        }
    }
    
    FileDialog {
        id: fileDialog
        title: "Select File(s) to Attach"
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            for (var i = 0; i < selectedFiles.length; i++) {
                var path = selectedFiles[i].toString().replace(/^file:\/\//, "");
                composeWindowOverlay.bodyInput.text += "\n<#part filename=\"" + decodeURIComponent(path) + "\">\n<#/part>\n";
            }
        }
    }
}
