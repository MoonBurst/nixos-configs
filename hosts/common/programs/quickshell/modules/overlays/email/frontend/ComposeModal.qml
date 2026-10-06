import Quickshell
import QtQuick
import QtQuick.LocalStorage
import QtQuick.Layouts
import "../../../style" as Style

Rectangle {
    id: composeComp

    visible: false

    property var engine: null

    property color overlayBgColor: "#F40F0F0F"
    property color modalBoxBg: (typeof theme !== 'undefined' && theme) ? theme.base00 : "#121212"
    property color fieldBg: (typeof theme !== 'undefined' && theme) ? theme.base00 : "#121212"
    property color placeholderTextColor: (typeof theme !== 'undefined' && theme) ? theme.base0B : "#545454"
    property color textWriteColor: (typeof theme !== 'undefined' && theme) ? theme.base06 : "#ebdbb2"
    property int modalPadding: (typeof theme !== 'undefined' && theme) ? theme.globalPadding : 20
    property int inputFontSize: (typeof theme !== 'undefined' && theme) ? theme.globalFontSize : 16
    property string composeFontFamily: (typeof theme !== 'undefined' && theme) ? theme.fontFamily : "monospace"
    property int controlBorderWidth: (typeof theme !== 'undefined' && theme && theme.controlBorderWidth !== undefined) ? theme.controlBorderWidth : 2
    property color outerBorderColor: (typeof theme !== 'undefined' && theme) ? theme.outerBorderColor : "#003399"
    property int outerBorderThickness: 5

    property color innerCardActiveBorder: (typeof theme !== 'undefined' && theme) ? theme.innerBorderColor : "#fabd2f"
    property int innerCardActiveThickness: 5

    property color innerCardInactiveBorder: (typeof theme !== 'undefined' && theme) ? theme.base03 : "#3c3836"
    property int innerCardInactiveThickness: 2

    property var contactsList: []
    property string currentSuggestion: ""

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

    anchors.fill: parent
    color: overlayBgColor

    MouseArea { anchors.fill: parent }

    // Evaluates content, saves draft, and closes composing
    function dismissSelf() {
        var toText = toInput.text.trim();
        var subText = subjectInput.text.trim();
        var bodyText = bodyInput.text.trim();
        var sigText = composeComp.mailSignature.trim();

        var hasBodyContent = (bodyText !== "" && bodyText !== sigText);
        var hasContent = (toText !== "") || (subText !== "") || hasBodyContent;

        if (hasContent && !composeComp.wasSent && composeComp.engine) {
            composeComp.engine.saveDraft(toInput.text, subjectInput.text, bodyInput.text);
        }

        if (composeComp.engine) {
            composeComp.engine.isComposing = false;
        }

        composeComp.escapeDismissRequested();
    }

    // Connects to window-level Escape signal dispatched from EmailWindow
    Connections {
        target: composeComp.engine
        function onRequestDismissCompose() {
            composeComp.dismissSelf();
        }
    }

    // Direct Wayland Drag-and-Drop Area covering the entire modal
    DropArea {
        anchors.fill: parent
        z: 99
        onEntered: (drag) => {
            drag.acceptProposedAction();
        }
        onPositionChanged: (drag) => {
            drag.acceptProposedAction();
        }
        onDropped: (drop) => {
            if (drop.hasUrls) {
                var added = [];
                for (var i = 0; i < drop.urls.length; i++) {
                    var localPath = drop.urls[i].toString().replace(/^file:\/\//, "");
                    var cleanPath = decodeURIComponent(localPath);
                    bodyInput.text += "\n<#part filename=\"" + cleanPath + "\">\n<#/part>\n";
                    added.push(cleanPath.split("/").pop());
                }
                drop.acceptProposedAction();
                if (added.length > 0) {
                    Quickshell.execDetached([
                        "notify-send", "-a", "Email", "-i", "mail-attachment",
                        "📎 File(s) Attached",
                                            added.join(", ")
                    ]);
                }
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+Return"
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
        }
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
        };
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
            id: composeBg
            anchors.fill: parent
            role: "card"
            color: composeComp.modalBoxBg
            borderColor: composeComp.outerBorderColor
            borderWidth: composeComp.outerBorderThickness
        }

        Column {
            anchors.fill: parent
            anchors.leftMargin:   composeBg.leftPadding
            anchors.rightMargin:  composeBg.rightPadding
            anchors.topMargin:    composeBg.topPadding
            anchors.bottomMargin: composeBg.bottomPadding
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

                Text {
                    text: "📎 Drag & drop files to attach"
                    font.family: composeComp.composeFontFamily
                    font.pixelSize: composeComp.inputFontSize - 3
                    color: composeComp.placeholderTextColor
                }
            }

            Column {
                width: parent.width
                spacing: 8

                // Recipient Field
                Item {
                    Layout.fillWidth: true
                    width: parent.width; height: composeComp.fieldInputHeight

                    Style.ShapeBox {
                        id: toFieldBg
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 10
                        color: composeComp.fieldBg
                        borderColor: toInput.activeFocus ? composeComp.innerCardActiveBorder : composeComp.innerCardInactiveBorder
                        borderWidth: controlBorderWidth
                    }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin:   toFieldBg.leftPadding
                        anchors.rightMargin:  toFieldBg.rightPadding
                        anchors.topMargin:    toFieldBg.topPadding
                        anchors.bottomMargin: toFieldBg.bottomPadding

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
                                anchors.leftMargin: 0
                                anchors.rightMargin: 0
                                font.pixelSize: composeComp.inputFontSize
                                font.family: composeComp.composeFontFamily
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                // Subject Field
                Item {
                    width: parent.width; height: composeComp.fieldInputHeight

                    Style.ShapeBox {
                        id: subjectFieldBg
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 10
                        color: composeComp.fieldBg
                        borderColor: subjectInput.activeFocus ? composeComp.innerCardActiveBorder : composeComp.innerCardInactiveBorder
                        borderWidth: controlBorderWidth
                    }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin:   subjectFieldBg.leftPadding
                        anchors.rightMargin:  subjectFieldBg.rightPadding
                        anchors.topMargin:    subjectFieldBg.topPadding
                        anchors.bottomMargin: subjectFieldBg.bottomPadding

                        TextInput {
                            id: subjectInput
                            anchors.fill: parent
                            font.family: composeComp.composeFontFamily
                            font.pixelSize: composeComp.inputFontSize
                            color: composeComp.textWriteColor
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            clip: true

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
                                anchors.leftMargin: 0
                                anchors.rightMargin: 0
                                font.pixelSize: composeComp.inputFontSize
                                font.family: composeComp.composeFontFamily
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            // Message Body Canvas
            Item {
                Layout.fillWidth: true
                width: parent.width
                height: Math.max(140, parent.height - (composeComp.fieldInputHeight * 2) - 150)

                Style.ShapeBox {
                    id: bodyFieldBg
                    anchors.fill: parent
                    role: "input"
                    slantWidth: 14
                    color: composeComp.fieldBg
                    borderColor: bodyInput.activeFocus ? composeComp.innerCardActiveBorder : composeComp.innerCardInactiveBorder
                    borderWidth: controlBorderWidth
                }

                Flickable {
                    id: bodyFlickableCanvas
                    anchors.fill: parent
                    anchors.leftMargin:   toFieldBg.leftPadding
                    anchors.rightMargin:  toFieldBg.rightPadding
                    anchors.topMargin:    12
                    anchors.bottomMargin: 12
                    contentWidth: width
                    contentHeight: bodyInput.height
                    clip: true

                    TextEdit {
                        id: bodyInput
                        anchors.fill: parent
                        anchors.topMargin: 14
                        anchors.bottomMargin: 14
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
                            text: "Write message content here (or drag & drop files anywhere)..."
                            color: composeComp.placeholderTextColor
                            visible: parent.text === "" && !parent.activeFocus
                            anchors.fill: parent
                            anchors.leftMargin: 0
                            anchors.topMargin: 0
                            font.pixelSize: composeComp.inputFontSize
                            font.family: composeComp.composeFontFamily
                        }
                    }
                }
            }

            Text {
                text: "Press [Ctrl + Enter] to Send  •  [ESC] to Save Draft & Exit"
                font.family: composeComp.composeFontFamily
                font.pixelSize: composeComp.inputFontSize - 3
                color: composeComp.placeholderTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
