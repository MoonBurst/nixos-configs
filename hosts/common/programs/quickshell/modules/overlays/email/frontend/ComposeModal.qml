import Quickshell
import QtQuick
import QtQuick.LocalStorage
import QtQuick.Layouts
import "../../../style" as Style

Rectangle {
    id: composeComp

    visible: false

    property color overlayBgColor: "#F40F0F0F"
    property color modalBoxBg: (typeof theme !== 'undefined' && theme) ? theme.base00 : "#121212"
    property color fieldBg: (typeof theme !== 'undefined' && theme) ? theme.base00 : "#121212"
    property color placeholderTextColor: (typeof theme !== 'undefined' && theme) ? theme.base0B : "#545454"
    property color textWriteColor: (typeof theme !== 'undefined' && theme) ? theme.base06 : "#ebdbb2"
    property int modalPadding: (typeof theme !== 'undefined' && theme) ? theme.globalPadding : 20
    property int inputFontSize: (typeof theme !== 'undefined' && theme) ? theme.globalFontSize : 16
    property string composeFontFamily: (typeof theme !== 'undefined' && theme) ? theme.fontFamily : "monospace"

    property color outerBorderColor: (typeof theme !== 'undefined' && theme) ? theme.outerBorderColor : "#003399"
    property int outerBorderThickness: 5

    property color innerCardActiveBorder: (typeof theme !== 'undefined' && theme) ? theme.innerBorderColor : "#fabd2f"
    property int innerCardActiveThickness: 5

    property color innerCardInactiveBorder: (typeof theme !== 'undefined' && theme) ? theme.base03 : "#3c3836"
    property int innerCardInactiveThickness: 2

    property var contactsList: []
    property string currentSuggestion: ""
    property var quickshellContext: null

    property string initialTo: ""
    property string initialSubject: ""
    property string initialBody: ""
    property bool wasSent: false

    readonly property int fieldInputHeight: (typeof shell !== 'undefined' && shell && shell.settingsManager && shell.settingsManager.globalFieldHeight > 0)
    ? shell.settingsManager.globalFieldHeight : 44

    property string mailSignature: (typeof shell !== "undefined" && shell && shell.settingsManager && shell.settingsManager.emailSignature)
    ? shell.settingsManager.emailSignature
    : "\n\n--\nSeekers of light..\nBelieve not in justice...\nBelieve not in truth...\nFor they are empty and inconsistent, as are all things..."

    property alias bodyInput: bodyInput

    signal dispatchMailRequested(string to, string subject, string body)
    signal escapeDismissRequested()
    signal attachmentRequested()

    anchors.fill: parent
    color: overlayBgColor

    MouseArea { anchors.fill: parent }

    function dismissSelf() {
        composeComp.checkAndSaveDraft();
        composeComp.escapeDismissRequested();
    }

    Shortcut {
        sequence: "Escape"
        enabled: composeComp.visible
        onActivated: composeComp.dismissSelf()
    }

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

    function prepopulateForm(toField, subjectField, historyLog) {
        composeComp.wasSent = false;
        toInput.text = toField;
        subjectInput.text = subjectField;

        if (historyLog !== "") {
            bodyInput.text = "\n\n" + composeComp.mailSignature + "\n\n" + historyLog;
        } else {
            bodyInput.text = composeComp.mailSignature;
        }

        composeComp.initialTo = toInput.text;
        composeComp.initialSubject = subjectInput.text;
        composeComp.initialBody = bodyInput.text;

        if (toField !== "") {
            bodyInput.forceActiveFocus();
            bodyInput.cursorPosition = 0;
        } else {
            toInput.forceActiveFocus();
        }
    }

    function restoreDraftForm(toField, subjectField, draftBody) {
        composeComp.wasSent = false;
        toInput.text = toField;
        subjectInput.text = subjectField;
        bodyInput.text = draftBody;

        composeComp.initialTo = toInput.text;
        composeComp.initialSubject = subjectInput.text;
        composeComp.initialBody = bodyInput.text;

        bodyInput.forceActiveFocus();
        bodyInput.cursorPosition = 0;
    }

    Component.onCompleted: loadContactsDatabase()

    onVisibleChanged: {
        if (visible) {
            composeComp.wasSent = false;
            if (toInput.text === "") {
                loadContactsDatabase();
                toInput.forceActiveFocus();
            }
            composeComp.initialTo = toInput.text;
            composeComp.initialSubject = subjectInput.text;
            composeComp.initialBody = bodyInput.text;
        } else {
            checkAndSaveDraft();
        }
    }

    Component.onDestruction: checkAndSaveDraft()

    function checkAndSaveDraft() {
        var isDirty = (toInput.text !== composeComp.initialTo) ||
        (subjectInput.text !== composeComp.initialSubject) ||
        (bodyInput.text !== composeComp.initialBody);

        if (isDirty && !composeComp.wasSent) {
            saveDraftOffline(toInput.text, subjectInput.text, bodyInput.text);
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
        } catch (err) {}
    }

    function loadContactsDatabase() {
        var homeDir = Quickshell.env("HOME") || "";
        var xhr = new XMLHttpRequest();
        var contactsUrl = "file://" + homeDir + "/Documents/Contacts";

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
        var txt = currentText.toLowerCase().trim();
        var match = contactsList.find(contact => {
            var cLower = contact.toLowerCase();
            return cLower.startsWith(txt) && cLower !== txt;
        });
        currentSuggestion = match || "";
    }

    Item {
        anchors.fill: parent

        Style.ShapeBox {
            anchors.fill: parent
            role: "card"
            color: composeComp.modalBoxBg
            borderColor: composeComp.outerBorderColor
            borderWidth: composeComp.outerBorderThickness
        }

        Column {
            anchors.fill: parent
            anchors.margins: composeComp.modalPadding
            spacing: 12

            RowLayout {
                width: parent.width
                height: 35

                Text {
                    text: "NEW MAIL COMPOSITION"
                    font.family: composeComp.composeFontFamily
                    font.pixelSize: composeComp.inputFontSize
                    font.bold: true
                    color: (typeof theme !== 'undefined' && theme) ? theme.base05 : "#f7f700"
                    Layout.fillWidth: true
                }

                Item {
                    width: 120; height: 30

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 8
                        color: composeComp.fieldBg
                        borderColor: composeComp.innerCardInactiveBorder
                        borderWidth: 1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "📎 + Attach"
                        font.family: composeComp.composeFontFamily
                        font.pixelSize: composeComp.inputFontSize - 3
                        font.bold: true
                        color: composeComp.placeholderTextColor
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: composeComp.attachmentRequested()
                    }
                }

                Rectangle {
                    width: 30; height: 30; radius: 4
                    color: "transparent"; border.color: "#ff5555"; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.bold: true; font.pixelSize: 13
                        color: "#ff5555"
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: composeComp.dismissSelf()
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8

                // 1. RECIPIENT FIELD
                Item {
                    width: parent.width; height: composeComp.fieldInputHeight

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 10
                        color: composeComp.fieldBg
                        borderColor: toInput.activeFocus ? composeComp.innerCardActiveBorder : composeComp.innerCardInactiveBorder
                        borderWidth: toInput.activeFocus ? 2 : 1
                    }

                    Item {
                        anchors.fill: parent; anchors.margins: 10

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            font.family: composeComp.composeFontFamily
                            font.pixelSize: composeComp.inputFontSize
                            color: "#545454"
                            text: composeComp.currentSuggestion
                            visible: toInput.text !== "" && composeComp.currentSuggestion !== "" && composeComp.currentSuggestion.toLowerCase().startsWith(toInput.text.toLowerCase()) && (composeComp.currentSuggestion.toLowerCase() !== toInput.text.toLowerCase())
                        }

                        TextInput {
                            id: toInput
                            anchors.fill: parent
                            font.family: composeComp.composeFontFamily
                            font.pixelSize: composeComp.inputFontSize
                            color: composeComp.textWriteColor
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            clip: true
                            onTextChanged: composeComp.checkAutocompleteSuggestions(text)

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Escape) {
                                    composeComp.dismissSelf();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab) {
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
                                text: "To: [Tab to complete/next]"
                                color: composeComp.placeholderTextColor
                                visible: parent.text === "" && !parent.activeFocus
                                anchors.fill: parent
                                font.pixelSize: composeComp.inputFontSize
                                font.family: composeComp.composeFontFamily
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                // 2. SUBJECT FIELD
                Item {
                    width: parent.width; height: composeComp.fieldInputHeight

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 10
                        color: composeComp.fieldBg
                        borderColor: subjectInput.activeFocus ? composeComp.innerCardActiveBorder : composeComp.innerCardInactiveBorder
                        borderWidth: subjectInput.activeFocus ? 2 : 1
                    }

                    Item {
                        anchors.fill: parent; anchors.margins: 10

                        TextInput {
                            id: subjectInput; anchors.fill: parent; font.family: composeComp.composeFontFamily; font.pixelSize: composeComp.inputFontSize; color: composeComp.textWriteColor
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Escape) {
                                    composeComp.dismissSelf();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab) {
                                    bodyInput.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }

                            Text {
                                text: "Subject:"
                                color: composeComp.placeholderTextColor
                                visible: parent.text === "" && !parent.activeFocus
                                anchors.fill: parent
                                font.pixelSize: composeComp.inputFontSize
                                font.family: composeComp.composeFontFamily
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            // 3. BODY MESSAGE CONTENT CANVAS
            Item {
                width: parent.width
                height: Math.max(140, parent.height - (composeComp.fieldInputHeight * 2) - 150)

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    slantWidth: 12
                    color: composeComp.fieldBg
                    borderColor: bodyInput.activeFocus ? composeComp.innerCardActiveBorder : composeComp.innerCardInactiveBorder
                    borderWidth: bodyInput.activeFocus ? 2 : 1
                }

                Flickable {
                    id: bodyFlickableCanvas; anchors.fill: parent; anchors.margins: 12; contentWidth: width; contentHeight: bodyInput.height; clip: true

                    TextEdit {
                        id: bodyInput
                        width: parent.width
                        font.family: composeComp.composeFontFamily
                        font.pixelSize: composeComp.inputFontSize
                        color: composeComp.textWriteColor
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                composeComp.dismissSelf();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab) {
                                toInput.forceActiveFocus();
                                event.accepted = true;
                            }
                        }

                        Text {
                            text: "Write message content here..."
                            color: composeComp.placeholderTextColor
                            visible: parent.text === "" && !parent.activeFocus
                            anchors.fill: parent
                            font.pixelSize: composeComp.inputFontSize
                            font.family: composeComp.composeFontFamily
                        }
                    }
                }
            }

            Text {
                text: "Press [Ctrl + Enter] to Send  •  [ESC] to Dismiss"
                font.family: composeComp.composeFontFamily
                font.pixelSize: composeComp.inputFontSize - 3
                color: composeComp.placeholderTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
