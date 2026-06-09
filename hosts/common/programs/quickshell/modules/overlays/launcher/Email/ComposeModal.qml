import QtQuick

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

    property color outerBorderColor: (typeof theme !== 'undefined') ? theme.outerBorderColor : "#003399"
    property int outerBorderThickness: 5
    property color innerCardActiveBorder: (typeof theme !== 'undefined') ? theme.innerBorderColor : "#fabd2f"
    property int innerCardActiveThickness: 5
    property color innerCardInactiveBorder: (typeof theme !== 'undefined') ? theme.base03 : "#3c3836"
    property int innerCardInactiveThickness: 2

    property var contactsList: []
    property string currentSuggestion: ""
    property var quickshellContext: null

    signal dispatchMailRequested(string to, string subject, string body)
    signal escapeDismissRequested()

    anchors.fill: parent; color: overlayBgColor
    MouseArea { anchors.fill: parent }

    // ============================================================================
    // GLOBAL HOTKEY SHORTCUTS
    // ============================================================================
    Shortcut { sequence: "Ctrl+Return"; enabled: composeComp.visible; onActivated: composeComp.dispatchMailRequested(toInput.text, subjectInput.text, bodyInput.text) }
    Shortcut { sequence: "Ctrl+Enter"; enabled: composeComp.visible; onActivated: composeComp.dispatchMailRequested(toInput.text, subjectInput.text, bodyInput.text) }
    Shortcut { sequence: "Escape"; enabled: composeComp.visible; onActivated: composeComp.escapeDismissRequested() }

    function prepopulateForm(toField, subjectField, historyLog) {
        toInput.text = toField; subjectInput.text = subjectField; bodyInput.text = historyLog;
        if (toField !== "") { bodyInput.forceActiveFocus(); bodyInput.cursorPosition = 0; }
        else { toInput.forceActiveFocus(); }
    }

    Component.onCompleted: loadContactsDatabase()

    onVisibleChanged: {
        if (visible && toInput.text === "") {
            loadContactsDatabase(); toInput.forceActiveFocus();
        }
    }

    function loadContactsDatabase() {
        var activeUser = quickshellContext && quickshellContext.env ? quickshellContext.env("USER") : "moonburst";
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && (xhr.status === 200 || xhr.status === 0)) {
                // Functional pipeline (replaces 15 lines of raw loops)
                composeComp.contactsList = xhr.responseText.split("\n")
                .map(line => line.trim())
                .filter(line => line !== "" && !line.startsWith("#"));
            }
        }
        xhr.open("GET", "file:///home/" + activeUser + "/Documents/Contacts", true);
        xhr.send();
    }

    function checkAutocompleteSuggestions(currentText) {
        if (!currentText || currentText.trim() === "") { currentSuggestion = ""; return; }
        var txt = currentText.toLowerCase();
        // Standard ES6 .find() statement replaces the old multi-line loop
        var match = contactsList.find(contact => contact.toLowerCase().startsWith(txt));
        currentSuggestion = match || "";
    }

    Rectangle {
        anchors.fill: parent; color: composeComp.modalBoxBg
        border.color: outerBorderColor; border.width: outerBorderThickness; radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10

        Column {
            anchors.fill: parent; anchors.margins: composeComp.modalPadding; spacing: 20

            Text { text: "NEW MAIL COMPOSITION"; font.family: composeComp.composeFontFamily; font.pixelSize: composeComp.inputFontSize; font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700" }

            // 1. RECIPIENT FIELD
            Rectangle {
                width: parent.width; height: (typeof theme !== 'undefined' ? theme.defaultCardHeight : 140) - 70; color: composeComp.fieldBg; radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10
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
                                if (composeComp.currentSuggestion !== "" && text !== composeComp.currentSuggestion) { text = composeComp.currentSuggestion; cursorPosition = text.length; }
                                else { subjectInput.forceActiveFocus(); }
                                event.accepted = true;
                            }
                        }
                        Text { text: "To: (Type name... [Tab] to auto-complete or hop to subject)"; color: composeComp.placeholderTextColor; visible: parent.text === ""; anchors.fill: parent; font.pixelSize: composeComp.inputFontSize }
                    }
                }
            }

            // 2. SUBJECT FIELD
            Rectangle {
                width: parent.width; height: (typeof theme !== 'undefined' ? theme.defaultCardHeight : 140) - 50; color: composeComp.fieldBg; radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10
                border.color: subjectInput.activeFocus ? composeComp.innerCardActiveBorder : composeComp.innerCardInactiveBorder
                border.width: subjectInput.activeFocus ? composeComp.innerCardActiveThickness : composeComp.innerCardInactiveThickness

                Item {
                    anchors.fill: parent; anchors.margins: 12
                    TextInput {
                        id: subjectInput; anchors.fill: parent; font.family: composeComp.composeFontFamily; font.pixelSize: composeComp.inputFontSize; color: composeComp.textWriteColor
                        Keys.onPressed: (event) => { if (event.key === Qt.Key_Tab) { bodyInput.forceActiveFocus(); event.accepted = true; } }
                        Text { text: "Subject:"; color: composeComp.placeholderTextColor; visible: parent.text === ""; anchors.fill: parent; font.pixelSize: composeComp.inputFontSize }
                    }
                }
            }

            // 3. BODY MESSAGE CONTENT CANVAS
            Rectangle {
                width: parent.width; height: parent.height - 240; color: composeComp.fieldBg; radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10
                border.color: bodyInput.activeFocus ? composeComp.innerCardActiveBorder : composeComp.innerCardInactiveBorder
                border.width: bodyInput.activeFocus ? composeComp.innerCardActiveThickness : composeComp.innerCardInactiveThickness

                Flickable {
                    id: bodyFlickableCanvas; anchors.fill: parent; anchors.margins: 12; contentWidth: width; contentHeight: bodyInput.height; clip: true; boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                        id: bodyInput; width: parent.width; font.family: composeComp.composeFontFamily; font.pixelSize: composeComp.inputFontSize; color: composeComp.textWriteColor; wrapMode: TextEdit.Wrap

                        onCursorPositionChanged: {
                            var rect = cursorRectangle;
                            if (rect.y < bodyFlickableCanvas.contentY) { bodyFlickableCanvas.contentY = rect.y; }
                            else if (rect.y + rect.height > bodyFlickableCanvas.contentY + bodyFlickableCanvas.height) { bodyFlickableCanvas.contentY = rect.y + rect.height - bodyFlickableCanvas.height; }
                        }
                        Keys.onPressed: (event) => { if (event.key === Qt.Key_Tab) { toInput.forceActiveFocus(); event.accepted = true; } }
                        Text { text: "Write message content here..."; color: composeComp.placeholderTextColor; visible: parent.text === ""; anchors.fill: parent; font.pixelSize: composeComp.inputFontSize }
                    }
                }
            }

            Text { text: "Press [Ctrl + Enter] to Send  •  [ESC] to Dismiss  •  [Tab] to Navigate Fields"; font.family: composeComp.composeFontFamily; font.pixelSize: composeComp.inputFontSize - 3; color: composeComp.placeholderTextColor; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }
}
