import QtQuick
import QtQuick.LocalStorage

Rectangle {
    id: composeComp

    // Explicitly initialize as hidden to prevent startup visibility focus glitches
    visible: false

    // ============================================================================
    // SAFE VARIABLE CHECKS AGAINST THE CENTRAL THEME OBJECT
    // ============================================================================
    property color overlayBgColor: "#F40F0F0F"
    property color modalBoxBg: (typeof theme !== 'undefined') ? theme.base00 : "#121212"
    property color fieldBg: (typeof theme !== 'undefined') ? theme.base00 : "#121212"
    property color placeholderTextColor: (typeof theme !== 'undefined') ? theme.base0B : "#545454"
    property color textWriteColor: (typeof theme !== 'undefined') ? theme.base06 : "#ebdbb2"
    property int modalPadding: (typeof theme !== 'undefined') ? theme.globalPadding : 20
    property int inputFontSize: (typeof theme !== 'undefined') ? theme.globalFontSize : 20
    property string composeFontFamily: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"

    // Core Outer Large Container Border Configuration
    property color outerBorderColor: (typeof theme !== 'undefined') ? theme.outerBorderColor : "#003399"
    property int outerBorderThickness: 5

    // Inner Active (Focused) Element Border Configuration
    property color innerCardActiveBorder: (typeof theme !== 'undefined') ? theme.innerBorderColor : "#fabd2f"
    property int innerCardActiveThickness: 5

    // Inner Inactive (Unfocused) Element Border Configuration (base03)
    property color innerCardInactiveBorder: (typeof theme !== 'undefined') ? theme.base03 : "#3c3836"
    property int innerCardInactiveThickness: 2

    // Contacts Auto-Complete Data States
    property var contactsList: []
    property string currentSuggestion: ""
    property var quickshellContext: null

    // Draft State Handlers for Tracking Alterations
    property string initialTo: ""
    property string initialSubject: ""
    property string initialBody: ""
    property bool wasSent: false

    // Automated Email Signature
    property string mailSignature: "\n\n--\nSeekers of light..
    Believe not in justice...
    Believe not in truth...
    For they are empty and inconsistent, as are all things..."

    // Exposed alias to let root window file dialog append attachments
    property alias bodyInput: bodyInput

    signal dispatchMailRequested(string to, string subject, string body)
    signal escapeDismissRequested()
    signal attachmentRequested() // Restored to maintain backward-compatibility with Email.qml instantiation

    anchors.fill: parent; color: overlayBgColor
    MouseArea { anchors.fill: parent }

    // ============================================================================
    // GLOBAL HOTKEY SHORTCUTS (ACTIVE ONLY WHEN COMPOSING)
    // ============================================================================
    Shortcut {
        sequence: "Ctrl+Return"
        enabled: composeComp.visible
        onActivated: {
            composeComp.wasSent = true;
            composeComp.dispatchMailRequested(toInput.text, subjectInput.text, bodyInput.text);
        }
    }

    Shortcut {
        sequence: "Ctrl+Enter"
        enabled: composeComp.visible
        onActivated: {
            composeComp.wasSent = true;
            composeComp.dispatchMailRequested(toInput.text, subjectInput.text, bodyInput.text);
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: composeComp.visible
        onActivated: {
            // Force the draft save check immediately before emitting the exit signal to the parent
            console.log("[ComposeModal] Escape key pressed. Validating unsaved modifications...");
            composeComp.checkAndSaveDraft();
            composeComp.escapeDismissRequested();
        }
    }

    // ============================================================================
    // REACTIONARY INITIAL WORKFLOW FOCUS LINKER WITH AUTOMATED SIGNATURE
    // ============================================================================
    function prepopulateForm(toField, subjectField, historyLog) {
        composeComp.wasSent = false;
        toInput.text = toField;
        subjectInput.text = subjectField;

        // Append signature block automatically
        if (historyLog !== "") {
            bodyInput.text = "\n\n" + composeComp.mailSignature + "\n\n" + historyLog;
        } else {
            bodyInput.text = composeComp.mailSignature;
        }

        // Cache baseline values to monitor changes
        composeComp.initialTo = toInput.text;
        composeComp.initialSubject = subjectInput.text;
        composeComp.initialBody = bodyInput.text;

        if (toField !== "") {
            bodyInput.forceActiveFocus();
            bodyInput.cursorPosition = 0; // Places typing cursor precisely at the top, before the signature
        } else {
            toInput.forceActiveFocus();
        }
    }

    // ============================================================================
    // RESTORE EXISTING DRAFT FORM (NO SIGNATURE DOUBLE-APPENDING)
    // ============================================================================
    function restoreDraftForm(toField, subjectField, draftBody) {
        composeComp.wasSent = false;
        toInput.text = toField;
        subjectInput.text = subjectField;
        bodyInput.text = draftBody;

        // Cache baseline values to monitor changes exactly as they are restored
        composeComp.initialTo = toInput.text;
        composeComp.initialSubject = subjectInput.text;
        composeComp.initialBody = bodyInput.text;

        bodyInput.forceActiveFocus();
        bodyInput.cursorPosition = 0; // Let the user resume typing smoothly
    }

    Component.onCompleted: {
        loadContactsDatabase();
    }

    onVisibleChanged: {
        if (visible) {
            composeComp.wasSent = false;
            if (toInput.text === "") {
                loadContactsDatabase();
                toInput.forceActiveFocus();
            }
            // Capture baseline state in case prepopulateForm wasn't run
            composeComp.initialTo = toInput.text;
            composeComp.initialSubject = subjectInput.text;
            composeComp.initialBody = bodyInput.text;
        } else {
            // Screen closing event - check if changes need saving to draft database
            checkAndSaveDraft();
        }
    }

    // Capture component destruction (e.g. if unloaded by a Loader) to guarantee saves
    Component.onDestruction: {
        checkAndSaveDraft();
    }

    // --- Draft Saving Business Logic ---
    function checkAndSaveDraft() {
        var isDirty = (toInput.text !== composeComp.initialTo) ||
        (subjectInput.text !== composeComp.initialSubject) ||
        (bodyInput.text !== composeComp.initialBody);

        if (isDirty && !composeComp.wasSent) {
            console.log("[ComposeModal] Changes detected. Saving draft to local queue...");
            saveDraftOffline(toInput.text, subjectInput.text, bodyInput.text);

            // Re-align the baseline state to mark as clean and prevent duplicate writes
            composeComp.initialTo = toInput.text;
            composeComp.initialSubject = subjectInput.text;
            composeComp.initialBody = bodyInput.text;
        }
    }

    function saveDraftOffline(recipient, subject, bodyContent) {
        try {
            var db = LocalStorage.openDatabaseSync("QMailQueue", "1.0", "Offline QMail Queue", 1000000);
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS queue (id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT, arg1 TEXT, arg2 TEXT, arg3 TEXT)');
                tx.executeSql(
                    'INSERT INTO queue (action, arg1, arg2, arg3) VALUES (?, ?, ?, ?)',
                              ['DRAFT', recipient, subject, bodyContent]
                );
            });
            console.log("[ComposeModal] Draft successfully written to shared SQLite queue.");
        } catch (err) {
            console.error("[ComposeModal Error] Failed to write draft to SQLite database: ", err);
        }
    }

    function loadContactsDatabase() {
        var activeUser = "moonburst";
        if (quickshellContext && quickshellContext.env) {
            activeUser = quickshellContext.env("USER");
        }
        var xhr = new XMLHttpRequest();
        var contactsUrl = "file:///home/" + activeUser + "/Documents/Contacts";

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    var lines = xhr.responseText.split("\n");
                    var loadedContacts = [];
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim();
                        if (line !== "" && !line.startsWith("#")) {
                            loadedContacts.push(line);
                        }
                    }
                    composeComp.contactsList = loadedContacts;
                }
            }
        }
        xhr.open("GET", contactsUrl, true);
        xhr.send();
    }

    function checkAutocompleteSuggestions(currentText) {
        if (!currentText || currentText.trim() === "") {
            currentSuggestion = "";
            return;
        }
        var txt = currentText.toLowerCase();
        var match = contactsList.find(contact => contact.toLowerCase().startsWith(txt));
        currentSuggestion = match || "";
    }

    Rectangle {
        anchors.fill: parent; color: composeComp.modalBoxBg
        border.color: outerBorderColor; border.width: outerBorderThickness; radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10

        Column {
            anchors.fill: parent; anchors.margins: composeComp.modalPadding; spacing: 15

            // Header Container (Title on the Left, Attachment request button on the Right)
            Item {
                width: parent.width
                height: 35

                Text {
                    text: "NEW MAIL COMPOSITION"
                    font.family: composeComp.composeFontFamily
                    font.pixelSize: composeComp.inputFontSize
                    font.bold: true
                    color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 140; height: 32; color: composeComp.fieldBg; radius: 6
                    border.color: composeComp.innerCardInactiveBorder; border.width: composeComp.innerCardInactiveThickness
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "📎 + Attach"
                        font.family: composeComp.composeFontFamily
                        font.pixelSize: composeComp.inputFontSize - 4
                        font.bold: true
                        color: composeComp.placeholderTextColor
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            composeComp.attachmentRequested();
                        }
                    }
                }
            }

            // Grouped Recipient and Subject Fields (Sit compactly together)
            Column {
                width: parent.width; spacing: 8

                // 1. RECIPIENT FIELD
                Rectangle {
                    width: parent.width; height: (typeof theme !== 'undefined' ? theme.defaultCardHeight : 140) - 45; color: composeComp.fieldBg
                    radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10
                    border.color: toInput.activeFocus ? composeComp.innerCardActiveBorder : composeComp.innerCardInactiveBorder
                    border.width: toInput.activeFocus ? composeComp.innerCardActiveThickness : composeComp.innerCardInactiveThickness

                    Item {
                        anchors.fill: parent; anchors.margins: 12

                        Text {
                            text: composeComp.currentSuggestion; font.family: composeComp.composeFontFamily; font.pixelSize: composeComp.inputFontSize; color: (typeof theme !== 'undefined') ? theme.base0B : "#545454"
                            anchors.fill: parent; visible: toInput.text !== "" && composeComp.currentSuggestion.toLowerCase().startsWith(toInput.text.toLowerCase())
                        }

                        TextInput {
                            id: toInput; anchors.fill: parent; font.family: composeComp.composeFontFamily; font.pixelSize: composeComp.inputFontSize; color: composeComp.textWriteColor
                            onTextChanged: composeComp.checkAutocompleteSuggestions(text)

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Tab) {
                                    if (composeComp.currentSuggestion !== "" && toInput.text !== composeComp.currentSuggestion) {
                                        toInput.text = composeComp.currentSuggestion;
                                        toInput.cursorPosition = toInput.text.length;
                                    } else {
                                        subjectInput.forceActiveFocus();
                                    }
                                    event.accepted = true;
                                }
                            }
                            Text {
                                text: "To: (Type name... [Tab] to auto-complete or hop to subject)"
                                color: composeComp.placeholderTextColor
                                visible: parent.text === ""
                                anchors.fill: parent
                                font.pixelSize: composeComp.inputFontSize
                            }
                        }
                    }
                }

                // 2. SUBJECT FIELD
                Rectangle {
                    width: parent.width; height: (typeof theme !== 'undefined' ? theme.defaultCardHeight : 140) - 45; color: composeComp.fieldBg; radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10
                    border.color: subjectInput.activeFocus ? composeComp.innerCardActiveBorder : composeComp.innerCardInactiveBorder
                    border.width: subjectInput.activeFocus ? composeComp.innerCardActiveThickness : composeComp.innerCardInactiveThickness

                    Item {
                        anchors.fill: parent; anchors.margins: 12

                        TextInput {
                            id: subjectInput; anchors.fill: parent; font.family: composeComp.composeFontFamily; font.pixelSize: composeComp.inputFontSize; color: composeComp.textWriteColor

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Tab) {
                                    bodyInput.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }

                            Text { text: "Subject:"; color: composeComp.placeholderTextColor; visible: parent.text === ""; anchors.fill: parent; font.pixelSize: composeComp.inputFontSize }
                        }
                    }
                }
            }

            // 3. BODY MESSAGE CONTENT CANVAS
            Rectangle {
                width: parent.width; height: parent.height - 290; color: composeComp.fieldBg
                radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10
                border.color: bodyInput.activeFocus ? composeComp.innerCardActiveBorder : composeComp.innerCardInactiveBorder
                border.width: bodyInput.activeFocus ? composeComp.innerCardActiveThickness : composeComp.innerCardInactiveThickness

                Flickable {
                    id: bodyFlickableCanvas; anchors.fill: parent; anchors.margins: 12; contentWidth: width; contentHeight: bodyInput.height; clip: true; boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                        id: bodyInput; width: parent.width; font.family: composeComp.composeFontFamily; font.pixelSize: composeComp.inputFontSize; color: composeComp.textWriteColor; wrapMode: TextEdit.Wrap

                        // Automatically slide the viewport to track the active typing cursor
                        onCursorPositionChanged: {
                            var rect = cursorRectangle;
                            if (rect.y < bodyFlickableCanvas.contentY) {
                                bodyFlickableCanvas.contentY = rect.y;
                            } else if (rect.y + rect.height > bodyFlickableCanvas.contentY + bodyFlickableCanvas.height) {
                                bodyFlickableCanvas.contentY = rect.y + rect.height - bodyFlickableCanvas.height;
                            }
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Tab) {
                                toInput.forceActiveFocus();
                                event.accepted = true;
                            }
                        }

                        Text {
                            text: "Write message content here..."; color: composeComp.placeholderTextColor; visible: parent.text === ""; anchors.fill: parent; font.pixelSize: composeComp.inputFontSize
                        }
                    }
                }
            }

            // Bottom bar row containing keyboard helper (Shifted higher)
            Text {
                text: "Press [Ctrl + Enter] to Send  •  [ESC] to Dismiss  •  [Tab] to Navigate Fields"
                font.family: composeComp.composeFontFamily
                font.pixelSize: composeComp.inputFontSize - 3
                color: composeComp.placeholderTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ============================================================================
    // GENTLE MULTI DRAG & DROP AREA
    // ============================================================================
    DropArea {
        id: dropArea
        anchors.fill: parent

        onEntered: (drag) => {
            if (drag.hasUrls) {
                drag.acceptProposedAction();
                dropOverlay.visible = true;
            }
        }

        onExited: {
            dropOverlay.visible = false;
        }

        onDropped: (drop) => {
            if (drop.hasUrls) {
                for (var i = 0; i < drop.urls.length; i++) {
                    var path = drop.urls[i].toString();
                    if (path.startsWith("file://")) {
                        path = path.substring(7);
                    }
                    path = decodeURIComponent(path);
                    bodyInput.text += "\n<#part filename=\"" + path + "\">\n<#/part>\n";
                }
                drop.acceptProposedAction();
            }
            dropOverlay.visible = false;
        }
    }

    // Visual drag-and-drop feedback overlay
    Rectangle {
        id: dropOverlay
        anchors.fill: parent
        color: "#E00f0f0f"
        visible: false
        z: 100

        Rectangle {
            width: parent.width - 80
            height: parent.height - 80
            color: "transparent"
            border.color: composeComp.innerCardActiveBorder
            border.width: 4
            radius: 10
            anchors.centerIn: parent

            Column {
                anchors.centerIn: parent
                spacing: 15

                Text { text: "📥"; font.pixelSize: 64; anchors.horizontalCenter: parent.horizontalCenter }
                Text {
                    text: "DROP FILES HERE TO ATTACH"
                    font.family: composeComp.composeFontFamily
                    font.pixelSize: composeComp.inputFontSize + 4
                    font.bold: true
                    color: composeComp.textWriteColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
