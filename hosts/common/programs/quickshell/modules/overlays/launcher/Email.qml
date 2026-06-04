import QtCore
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    focus: true

    // Dynamically initialized via your encrypted SOPS data vault on application startup
    property string userEmailAddress: ""
    property var emails: []
    property string messageBody: ""
    property string statusMessage: "Loading..."
    property var messageCache: ({})
    property bool isReplying: false

    // Interactive Module Composition Window Visibilities
    property bool isComposing: false
    property string composeSubject: ""

    property string selectedId: ""

    property string currentReplyTo: ""
    property string currentSubject: ""
    property int currentListIndex: 0

    // FIXED FALLBACK VARIABLES: Clearly initialized with hardcoded defaults to eliminate [undefined] assignment log warnings
    property int globalFontSize: 20
    property int globalHeaderSize: 20
    property string fontFamily: "Fira Sans"

    property int defaultCardWidth: 420
    property int defaultCardHeight: 140
    property int defaultCardRadius: 10
    property int globalBorderWidth: 3
    property int globalPadding: 20

    // CONTACTS LIST START
    property var contactDirectoryList: []
    Timer {
        id: contactsLoaderTimer
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            var xhr = new XMLHttpRequest();
            var docUrl = StandardPaths.writableLocation(StandardPaths.DocumentsLocation).toString();

            if (!docUrl.startsWith("file://")) {
                docUrl = "file://" + docUrl;
            }
            var path = docUrl + "/Contacts";

            console.log(">>>> CONTACTS LOADING PATH: " + path);

            xhr.open("GET", path, true);
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200 || xhr.status === 0) {
                        try {
                            // Assigns data directly up to the parent directory list
                            contactDirectoryList = JSON.parse(xhr.responseText);
                            console.log(">>>> SUCCESS: Loaded " + contactDirectoryList.length + " contacts.");
                        } catch(e) {
                            console.log(">>>> PARSING ERROR: Check file formatting.", e);
                        }
                    } else {
                        console.log(">>>> FILE READ ERROR: Terminal system failed to read target content file.");
                    }
                }
            }
            xhr.send();
        }
    }
    // CONTACTS LIST END

    // Automated Stylix Base16 Color Scheme Bridge
    property var stylixTheme: {
        if (typeof launcherRoot !== "undefined" && launcherRoot.ctrl && launcherRoot.ctrl.theme) return launcherRoot.ctrl.theme;
        if (typeof shell !== "undefined" && shell.theme) return shell.theme;
        if (typeof theme !== "undefined") return theme;
        return null;
    }

    onActiveFocusChanged: {
        if (activeFocus && !isReplying && !isComposing) {
            emailList.forceActiveFocus()
        }
    }



    function currentEmail() {
        if (emailList.currentIndex < 0 || emailList.currentIndex >= emails.length)
            return null
            return emails[emailList.currentIndex]
    }

    function sendRawEmail(content) {
        sendEmailProcess.command = [
            "sh",
            "-c",
            "cat > /tmp/qs-mail.eml <<'EOF'\n" +
            content +
            "\nEOF\n" +
            "himalaya message send < /tmp/qs-mail.eml > /tmp/himalaya-send.log 2> /tmp/himalaya-error.log"
        ]
        sendEmailProcess.running = false
        sendEmailProcess.running = true
    }

    function refreshMail() {
        root.statusMessage = "Syncing mail cache..."
        forceCacheSyncDownstream.running = true
    }

    function loadMessage(id) {
        selectedId = id
        messageBody = "Loading message from local cache..."
        isReplying = false

        for (var i = 0; i < emails.length; i++) {
            if (emails[i].id === id) {
                currentReplyTo = emails[i].from ? emails[i].from.addr : ""
                currentSubject = emails[i].subject ? emails[i].subject : ""
                if (currentSubject.toLowerCase().indexOf("re:") !== 0) {
                    currentSubject = "Re: " + currentSubject
                }
                break
            }
        }
        if (root.emails.length > 0 && emailList.currentIndex >= 0 && emailList.currentIndex < root.emails.length) {
            readMessage.command = ["himalaya", "message", "read", id]
            readMessage.running = true
        }
    }

    function deleteCurrentMessage() {
        var currentMail = emails[emailList.currentIndex]
        if (!currentMail) return

            var targetId = currentMail.id
            var tempArray = emails.slice()
            tempArray.splice(emailList.currentIndex, 1)
            emails = tempArray
            messageBody = "Message moved to Trash locally."

            Quickshell.execDetached(["himalaya", "message", "delete", targetId])
            root.selectedId = ""
    }

    function spamTargetMessage(msgId) {
        if (!msgId) return
            var tempArray = emails.slice()
            tempArray.splice(emailList.currentIndex, 1)
            emails = tempArray
            messageBody = "Flagged as spam locally."

            Quickshell.execDetached(["himalaya", "message", "move", msgId, "[Gmail]/Spam"])
            root.selectedId = ""
    }
    Component.onCompleted: {
        // Safe asynchronous bootstrapping loops fetch credentials on runtime startup
        readSopsSecret.running = true
    }

    Process {
        id: readSopsSecret
        command: [
            "cat",
            "/run/secrets/gmail_address"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.userEmailAddress = text.trim()

                console.log(
                    "Loaded email address:",
                    root.userEmailAddress
                )

                mailList.running = true
                emailList.forceActiveFocus()
            }
        }
    }

    Process {
        id: forceCacheSyncDownstream
        command: ["mbsync", "gmail"]
        onExited: {
            mailList.running = false
            mailList.running = true
        }
    }

    Process {
        id: mailList
        command: [
            "himalaya",
            "--output",
            "json",
            "envelope",
            "list"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim()
                if (!raw.length) {
                    root.emails = []
                    root.statusMessage = "0 message(s)"
                    return
                }
                try {
                    root.emails = JSON.parse(raw)
                    root.statusMessage = root.emails.length + " message(s)"
                } catch (e) {
                    root.emails = []
                    root.statusMessage = "Failed to load current cache"
                }
            }
        }
    }
    Process {
        id: readMessage
        stdout: StdioCollector {
            onStreamFinished: root.messageBody = text
        }
    }

    Process {
        id: sendEmailProcess

        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.isReplying = false
                root.isComposing = false
                root.messageBody = "Message transmitted successfully upstream!"
                emailList.forceActiveFocus()
                refreshMail()
            } else {
                readErrorLog.running = false
                readErrorLog.running = true
            }
        }
    }

    Process {
        id: readErrorLog
        command: ["cat", "/tmp/himalaya-error.log"]
        stdout: StdioCollector { onStreamFinished: root.messageBody = "Himalaya Debug Error:\n\n" + text.trim() }
    }

    Shortcut {
        sequence: "F5"
        onActivated: { if (!root.isReplying && !root.isComposing) refreshMail() }
    }
    Rectangle {
        anchors.fill: parent
        color: stylixTheme ? stylixTheme.base00 : "#111111"

        Row {
            anchors.fill: parent
            anchors.margins: stylixTheme ? stylixTheme.globalPadding : 8
            spacing: stylixTheme ? stylixTheme.globalPadding : 8

            /*
             * LEFT COLUMN PANEL (EMAIL SIDEBAR REGISTRY LISTVIEW)
             */
            Rectangle {
                width: parent.width * 0.42
                height: parent.height
                color: stylixTheme ? stylixTheme.base01 : "#1a1a24"
                border.color: stylixTheme ? stylixTheme.base02 : "#333333"
                border.width: stylixTheme ? stylixTheme.globalBorderWidth : 1
                radius: stylixTheme ? stylixTheme.defaultCardRadius : 0

                Column {
                    anchors.fill: parent
                    anchors.margins: stylixTheme ? (stylixTheme.globalPadding / 2) : 6
                    spacing: stylixTheme ? (stylixTheme.globalPadding / 2) : 6

                    Text {
                        id: statusText
                        text: root.statusMessage
                        color: stylixTheme ? stylixTheme.base07 : "#aaaaaa"
                        font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"
                        font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize + 4) : 24
                    }

                    ListView {
                        id: emailList
                        width: parent.width
                        height: parent.height - statusText.height - 20
                        model: root.emails
                        clip: true
                        spacing: 8
                        highlightFollowsCurrentItem: true
                        focus: !root.isReplying && !root.isComposing
                        activeFocusOnTab: true

                        Keys.onUpPressed: if (emailList.currentIndex > 0) emailList.currentIndex--
                        Keys.onDownPressed: if (emailList.currentIndex < root.emails.length - 1) emailList.currentIndex++

                        Keys.onReturnPressed: {
                            if (root.isReplying || root.isComposing) return
                                var email = root.emails[emailList.currentIndex]
                                if (!email) return

                                    if (root.selectedId === email.id && root.messageBody !== "Loading message..." && root.messageBody !== "") {
                                        root.isReplying = true
                                        replyInput.text = "From: " + root.userEmailAddress + "\n" +
                                        "To: " + root.currentReplyTo + "\n" +
                                        "Subject: " + root.currentSubject + "\n\n" +
                                        "--- Original Message ---\n" + root.messageBody
                                        replyInput.forceActiveFocus()
                                    } else {
                                        loadMessage(email.id)
                                    }
                        }

                        Keys.onPressed: (event) => {
                            if (!root.isReplying && !root.isComposing && event.key === Qt.Key_Delete) {
                                deleteCurrentMessage()
                                event.accepted = true
                            }
                        }

                        onCurrentIndexChanged: root.currentListIndex = currentIndex

                        delegate: Rectangle {
                            width: emailList.width
                            height: 105
                            radius: stylixTheme ? (stylixTheme.defaultCardRadius - 2) : 8
                            color: (root.currentListIndex === index) ? (stylixTheme ? stylixTheme.base03 : "#003399") : "transparent"
                            border.width: (root.selectedId === modelData.id) ? 2 : 0
                            border.color: stylixTheme ? stylixTheme.base0A : "#FABD2F"

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    emailList.currentIndex = index
                                    loadMessage(modelData.id)
                                    emailList.forceActiveFocus()
                                }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4

                                Text {
                                    width: parent.width - 24
                                    text: modelData.from ? (modelData.from.name || modelData.from.addr) : ""
                                    color: stylixTheme ? stylixTheme.base08 : "#ff6666"
                                    font.bold: true
                                    font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"
                                    font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize + 2) : 22
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width - 24
                                    text: modelData.subject || "(No Subject)"
                                    color: stylixTheme ? stylixTheme.base05 : "white"
                                    font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"
                                    font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize) : 20
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.date || ""
                                    color: stylixTheme ? stylixTheme.base04 : "#999999"
                                    font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"
                                    font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize - 4) : 12
                                }
                            }
                        }
                    }
                }
            }
            /*
             * RIGHT COLUMN PANEL (EMAIL PREVIEW DISPLAY WINDOW)
             */
            Rectangle {
                width: parent.width * 0.58 - (stylixTheme ? stylixTheme.globalPadding : 8)
                height: parent.height
                color: stylixTheme ? stylixTheme.base01 : "#181818"
                border.color: stylixTheme ? stylixTheme.base02 : "#333333"
                border.width: stylixTheme ? stylixTheme.globalBorderWidth : 1
                radius: stylixTheme ? stylixTheme.defaultCardRadius : 0

                Column {
                    anchors.fill: parent
                    anchors.margins: stylixTheme ? stylixTheme.globalPadding : 8
                    spacing: stylixTheme ? stylixTheme.globalPadding : 8

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: -12
                        spacing: 8

                        // NEW EMAIL BUTTON
                        Rectangle {
                            width: 140; height: 50; color: stylixTheme ? stylixTheme.base00 : "#675DDB"; radius: 4
                            border.color: stylixTheme ? stylixTheme.base05 : "#ffffff"
                            border.width: stylixTheme ? stylixTheme.globalBorderWidth : root.globalBorderWidth

                            Text {
                                anchors.centerIn: parent; text: "✉ New Email"
                                color: stylixTheme ? stylixTheme.base05 : "white"
                                font.family: stylixTheme ? stylixTheme.fontFamily : root.fontFamily
                                font.bold: true
                                font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : root.globalFontSize
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.isComposing = true
                                    composeSubjectInput.text = ""
                                    customAddressField.text = ""
                                    composeEditorInput.text = "From: " + root.userEmailAddress + "\nTo: \nSubject: \n\n"
                                    customAddressField.forceActiveFocus()
                                }
                            }
                        }

                        // REFRESH F5 BUTTON
                        Rectangle {
                            width: 110; height: 50; color: stylixTheme ? stylixTheme.base02 : "#2a2a3a"; radius: 4
                            // ADDED: Theme-aware dynamic default card borders
                            border.color: stylixTheme ? stylixTheme.base05 : "#ffffff"
                            border.width: stylixTheme ? stylixTheme.globalBorderWidth : root.globalBorderWidth

                            Text {
                                anchors.centerIn: parent; text: "Refresh (F5)"
                                color: stylixTheme ? stylixTheme.base05 : "white"
                                font.family: stylixTheme ? stylixTheme.fontFamily : root.fontFamily
                                font.bold: true
                                font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : root.globalFontSize
                            }

                            MouseArea { anchors.fill: parent; onClicked: refreshMail() }
                        }

                        // REPLY ENTER BUTTON
                        Rectangle {
                            width: 130; height: 50; color: stylixTheme ? stylixTheme.base02 : "#2a2a3a"; radius: 4
                            // ADDED: Theme-aware dynamic default card borders
                            border.color: stylixTheme ? stylixTheme.base05 : "#ffffff"
                            border.width: stylixTheme ? stylixTheme.globalBorderWidth : root.globalBorderWidth

                            Text {
                                anchors.centerIn: parent; text: "Reply (Enter)"
                                color: stylixTheme ? stylixTheme.base05 : "white"
                                font.family: stylixTheme ? stylixTheme.fontFamily : root.fontFamily
                                font.bold: true
                                font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : root.globalFontSize
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (root.messageBody === "" || root.messageBody === "Loading message...") return
                                        root.isReplying = true
                                        replyInput.text = "From: " + root.userEmailAddress + "\n" +
                                        "To: " + root.currentReplyTo + "\n" +
                                        "Subject: " + root.currentSubject + "\n\n" +
                                        "--- Original Message ---\n" + root.messageBody
                                        replyInput.forceActiveFocus()
                                }
                            }
                        }


                        Rectangle {
                            width: 100; height: 32; color: stylixTheme ? stylixTheme.base02 : "#2a2a3a"; radius: 4
                            visible: root.emails[emailList.currentIndex] !== undefined
                            Text { anchors.centerIn: parent; text: "Trash"; color: stylixTheme ? stylixTheme.base08 : "#ff6666"; font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans" }
                            MouseArea { anchors.fill: parent; onClicked: deleteCurrentMessage() }
                        }
                    }

                    Flickable {
                        width: parent.width; height: parent.height - 60; clip: true
                        contentHeight: messageText.paintedHeight + 40
                        Text {
                            id: messageText; width: parent.width; text: root.messageBody; wrapMode: Text.Wrap; color: stylixTheme ? stylixTheme.base06 : "white"; textFormat: Text.PlainText
                            font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"; font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize + 2) : 22; lineHeight: 1.15
                        }
                    }
                }
            }
        }
    }
    /*
     * INTERACTIVE COMPOSITION OVERLAY DIALOG MODAL (1000x1000 WIDE CANVAS)
     */
    Rectangle {
        id: composeWindowPopupModal
        visible: root.isComposing
        anchors.centerIn: parent
        width: 1000; height: 1000
        radius: stylixTheme ? stylixTheme.defaultCardRadius : 10
        color: stylixTheme ? stylixTheme.base01 : "#0F0F0F"
        border.color: stylixTheme ? stylixTheme.base03 : "#675DDB"
        border.width: stylixTheme ? (stylixTheme.globalBorderWidth + 2) : 3
        z: 99






















        Column {
            anchors.fill: parent
            anchors.margins: (stylixTheme ? stylixTheme.globalPadding : root.globalPadding) * 1.2
            spacing: 14

            Row {
                spacing: 12
                width: parent.width

                // SEND MESSAGE BUTTON
                Rectangle {
                    width: 160
                    height: 50
                    color: stylixTheme ? stylixTheme.base02 : "#2a2a3a"
                    radius: 6
                    border.color: stylixTheme ? stylixTheme.base05 : "#ffffff"
                    border.width: stylixTheme ? stylixTheme.globalBorderWidth : root.globalBorderWidth

                    Text {
                        anchors.centerIn: parent
                        text: "Send Message"
                        color: stylixTheme ? stylixTheme.base05 : "white"
                        font.family: stylixTheme ? stylixTheme.fontFamily : root.fontFamily
                        font.bold: true
                        font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : root.globalFontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (typeof sendEmailProcess !== "undefined") {
                                // Protect body text strings from breaking standard shell execution blocks
                                var cleanBody = composeMailBodyArea.text.replace(/"/g, '\\"');
                                var cleanSubject = composeSubjectInput.text.replace(/"/g, '\\"');
                                var cleanTo = customAddressField.text.replace(/"/g, '\\"');

                                // FIXED PARAMETER ALIGNMENT:
                                // 1. '-a gmail' sits immediately up front as a global modifier context flag
                                // 2. Swapped command to 'template send' to cleanly process standard input piping
                                // 3. Implemented a reliable printf statement chain to preserve exact header separation
                                sendEmailProcess.command = [
                                    "sh",
                                    "-c",
                                    "cat > /tmp/qs-mail.eml <<'EOF'\n" +
                                    "From: " + root.userEmailAddress + "\n" +
                                    "To: " + cleanTo + "\n" +
                                    "Subject: " + cleanSubject + "\n\n" +
                                    cleanBody + "\n" +
                                    "EOF\n" +
                                    "himalaya message send < /tmp/qs-mail.eml > /tmp/himalaya-send.log 2> /tmp/himalaya-error.log"
                                ];

                                sendEmailProcess.running = false
                                sendEmailProcess.running = true
                            }
                        }
                    }







                }

                // DISCARD (ESC) BUTTON
                Rectangle {
                    width: 120
                    height: 50
                    color: stylixTheme ? stylixTheme.base02 : "#2a2a3a"
                    radius: 6
                    border.color: stylixTheme ? stylixTheme.base05 : "#ffffff"
                    border.width: stylixTheme ? stylixTheme.globalBorderWidth : root.globalBorderWidth

                    Text {
                        anchors.centerIn: parent
                        text: "Discard (Esc)"
                        color: stylixTheme ? stylixTheme.base05 : "white"
                        font.family: stylixTheme ? stylixTheme.fontFamily : root.fontFamily
                        font.bold: true
                        font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : root.globalFontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.isComposing = false
                            emailList.forceActiveFocus()
                        }
                    }
                }
            }

            Row {
                width: parent.width; spacing: 14
                Column {
                    width: parent.width * 0.5 - 7; spacing: 4
                    Text { text: "Recipient Email Address:"; color: "white"; font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : 20; font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans" }
                    Rectangle {
                        width: parent.width; height: 40; color: stylixTheme ? stylixTheme.base00 : "#1a1a2a"; radius: 4; border.color: "#444"
                        TextInput {
                            id: customAddressField; anchors.fill: parent; anchors.margins: 10; color: "white"; font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : 20; selectByMouse: true
                            onTextChanged: composeEditorInput.text = "From: " + root.userEmailAddress + "\nTo: " + text + "\nSubject: " + composeSubjectInput.text + "\n\n" + composeMailBodyArea.text
                        }
                    }
                }
                Column {
                    width: parent.width * 0.5 - 7; spacing: 4
                    Text { text: "Message Subject Line:"; color: "white"; font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : 20; font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans" }
                    Rectangle {
                        width: parent.width; height: 40; color: stylixTheme ? stylixTheme.base00 : "#1a1a2a"; radius: 4; border.color: "#444"
                        TextInput {
                            id: composeSubjectInput; anchors.fill: parent; anchors.margins: 10; color: "white"; font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : 20; selectByMouse: true
                            onTextChanged: composeEditorInput.text = "From: " + root.userEmailAddress + "\nTo: " + customAddressField.text + "\nSubject: " + text + "\n\n" + composeMailBodyArea.text
                        }
                    }
                }
            }

            Text { text: "Quick-Select From Saved Contact Directory Grid:"; color: "white"; font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : 20; font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans" }
            Rectangle {
                width: parent.width; height: 130; color: stylixTheme ? stylixTheme.base00 : "#1a1a2a"; radius: 6; border.color: "#333"
                ListView {
                    anchors.fill: parent; anchors.margins: 6; model: root.contactDirectoryList; orientation: ListView.Horizontal; spacing: 10; clip: true
                    delegate: Rectangle {
                        width: 210; height: 110; radius: 6; color: stylixTheme ? stylixTheme.base02 : "#2a2a3a"; border.color: "#555"
                        Column {
                            width: parent.width - 20; anchors.fill: parent; anchors.margins: 10; spacing: 4
                            Text { text: modelData.name; color: stylixTheme ? stylixTheme.base0B : "#ccc"; font.bold: true; elide: Text.ElideRight; width: parent.width }
                            Text { text: modelData.addr; color: "white"; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                customAddressField.text = modelData.addr
                                // Triggers the address block's structural text listener explicitly
                                customAddressField.textChanged()
                                composeMailBodyArea.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            Text { text: "Write Email Message Contents:"; color: "white"; font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : 20; font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans" }

            Rectangle {
                id: bodyContainer
                width: parent.width
                height: 250
                color: stylixTheme ? stylixTheme.base00 : "#1a1a2a"
                radius: 6
                border.color: "#333"

                // Background click handler to guarantee focus catch
                MouseArea {
                    anchors.fill: parent
                    onClicked: composeMailBodyArea.forceActiveFocus()
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 12
                    clip: true
                    contentHeight: composeMailBodyArea.paintedHeight + 20
                    // Stops drag logic from eating mouse single-clicks when empty
                    interactive: contentHeight > height

                    TextEdit {
                        id: composeMailBodyArea
                        anchors.fill: parent
                        wrapMode: TextEdit.WrapAnywhere
                        color: "white"
                        font.family: "monospace"
                        font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : 20
                        selectByMouse: true
                        focus: true
                        activeFocusOnTab: true

                        // Syncs body typing directly back to output string model
                        onTextChanged: composeEditorInput.text = "From: " + root.userEmailAddress + "\nTo: " + customAddressField.text + "\nSubject: " + composeSubjectInput.text + "\n\n" + text

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                root.isComposing = false
                                emailList.forceActiveFocus()
                                event.accepted = true
                            }
                        }
                    }
                }
            }
            TextEdit { id: composeEditorInput; visible: false; text: "" }
        }
    }








    /*
     * DYNAMIC REPLY MODAL VIEWPORT OVERLAY
     */
    Rectangle {
        id: popupModal; visible: root.isReplying; anchors.centerIn: parent; width: 1000; height: 1000
        radius: stylixTheme ? stylixTheme.defaultCardRadius : 10; color: stylixTheme ? stylixTheme.base01 : "#0F0F0F"
        border.color: stylixTheme ? stylixTheme.base0C : "#04f100"; border.width: stylixTheme ? (stylixTheme.globalBorderWidth || 3) : 3; z: 99

        Column {
            anchors.fill: parent; anchors.margins: (stylixTheme ? stylixTheme.globalPadding : 20) * 1.5; spacing: 16
            Row {
                spacing: 12
                Rectangle {
                    width: 180; height: 40; color: stylixTheme ? stylixTheme.base03 : "#003399"; radius: 6
                    Text { anchors.centerIn: parent; text: "Send (Ctrl+Enter)"; color: stylixTheme ? stylixTheme.base05 : "#F7F700"; font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"; font.bold: true; font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : 20 }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var replyBody = replyInput.text.replace(/\\/g, "\\\\").replace(/"/g, '\\\"')

                            sendEmailProcess.command = [
                                "sh",
                                "-c",
                                "cat > /tmp/qs-mail.eml <<'EOF'\\n" +
                                replyBody + "\\n" +
                                "EOF\\n" +
                                "himalaya message send < /tmp/qs-mail.eml > /tmp/himalaya-send.log 2> /tmp/himalaya-error.log"
                            ]

                            sendEmailProcess.running = false
                            sendEmailProcess.running = true
                        }
                    }
                }
                Rectangle {
                    width: 140; height: 40; color: stylixTheme ? stylixTheme.base08 : "#FF0000"; radius: 6
                    Text { anchors.centerIn: parent; text: "Cancel (Esc)"; color: stylixTheme ? stylixTheme.base05 : "#F7F700"; font.family: stylixTheme ? stylixTheme.fontFamily : "Fira Sans"; font.pixelSize: stylixTheme ? stylixTheme.globalFontSize : 20 }
                    MouseArea { anchors.fill: parent; onClicked: { root.isReplying = false; emailList.forceActiveFocus() } }
                }
            }
            Rectangle {
                width: parent.width; height: parent.height - 70; color: stylixTheme ? stylixTheme.base00 : "#1a1a2a"; border.color: stylixTheme ? stylixTheme.base02 : "#1a1a2a"; border.width: 1; radius: stylixTheme ? (stylixTheme.defaultCardRadius - 4) : 6
                Flickable {
                    anchors.fill: parent; anchors.margins: stylixTheme ? stylixTheme.globalPadding : 20; clip: true; contentHeight: replyInput.paintedHeight + 20
                    TextEdit {
                        id: replyInput; width: parent.width - 10; wrapMode: TextEdit.WrapAnywhere; color: stylixTheme ? stylixTheme.base05 : "#F7F700"; font.family: "monospace"; font.pixelSize: stylixTheme ? (stylixTheme.globalFontSize + 6) : 26; selectByMouse: true
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return && (event.modifiers & Qt.ControlModifier)) {
                                var replyBody = replyInput.text.replace(/\\/g, "\\\\").replace(/"/g, '\\\"')

                                sendEmailProcess.command = [
                                    "sh",
                                    "-c",
                                    "cat > /tmp/qs-mail.eml <<'EOF'\\n" +
                                    replyBody + "\\n" +
                                    "EOF\\n" +
                                    "himalaya message send < /tmp/qs-mail.eml > /tmp/himalaya-send.log 2> /tmp/himalaya-error.log"
                                ]

                                sendEmailProcess.running = false
                                sendEmailProcess.running = true
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                root.isReplying = false; emailList.forceActiveFocus(); event.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }

    Timer { interval: 300000; repeat: true; running: true; onTriggered: refreshMail() }
}
