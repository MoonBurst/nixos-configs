import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: geminiView

    property var shell
    property string apiKey: ""
    property var conversationHistory: []
    property bool isLoading: false
    property string lastUserPrompt: ""

    readonly property color yellowAccent: shell && shell.theme && shell.theme.base0A ? shell.theme.base0A : "#f9e2af"
    readonly property color bgCard: shell && shell.theme && shell.theme.base01 ? shell.theme.base01 : "#1e1e2e"
    readonly property color errorColor: shell && shell.theme && shell.theme.base08 ? shell.theme.base08 : "#f38ba8"

    color: "transparent"

    function loadApiKey() {
        const fileXhr = new XMLHttpRequest();
        fileXhr.open("GET", "file:///run/secrets/gemini_token");
        fileXhr.onreadystatechange = function() {
            if (fileXhr.readyState === XMLHttpRequest.DONE) {
                if (fileXhr.status === 200 || fileXhr.status === 0) {
                    let token = fileXhr.responseText.trim();
                    if (token.length > 0) {
                        geminiView.apiKey = token;
                    }
                }
            }
        };
        fileXhr.send();
    }

    Component.onCompleted: {
        loadApiKey();
    }

    function clearContext() {
        conversationHistory = [];
        chatModel.clear();
        isLoading = false;
        lastUserPrompt = "";
    }

    // Extracts ONLY code from markdown
    function extractCodeOnly(rawText) {
        if (!rawText) return "";

        const codeBlockRegex = /```(?:[a-zA-Z0-9_\-\+]+)?\n([\s\S]*?)```/g;
        let matches = [];
        let match;

        while ((match = codeBlockRegex.exec(rawText)) !== null) {
            matches.push(match[1].trim());
        }

        if (matches.length > 0) return matches.join("\n\n");

        const inlineCodeRegex = /`([^`]+)`/g;
        let inlineMatches = [];
        while ((match = inlineCodeRegex.exec(rawText)) !== null) {
            inlineMatches.push(match[1].trim());
        }

        if (inlineMatches.length > 0) return inlineMatches.join("\n");

        return rawText.trim();
    }

    function hasCodeBlock(rawText) {
        return /```[\s\S]*?```|`[^`]+`/.test(rawText);
    }

    function retryLastMessage() {
        if (!lastUserPrompt || isLoading) return;

        // Remove the error message bubble from the chat view
        if (chatModel.count > 0 && chatModel.get(chatModel.count - 1).role === "error") {
            chatModel.remove(chatModel.count - 1);
        }

        // Re-send the last question
        conversationHistory.push({ role: "user", parts: [{ text: lastUserPrompt }] });
        isLoading = true;
        callGemini("gemini-flash-latest");
    }

    function sendMessage(text) {
        if (!text || text.trim() === "" || isLoading) return;

        if (!apiKey || apiKey === "") {
            loadApiKey();
            chatModel.append({ role: "error", text: "API token loading from sops... please try again." });
            return;
        }

        let userText = text.trim();
        lastUserPrompt = userText;
        chatModel.append({ role: "user", text: userText });
        conversationHistory.push({ role: "user", parts: [{ text: userText }] });
        isLoading = true;

        callGemini("gemini-flash-latest");
    }

    function callGemini(modelName) {
        const xhr = new XMLHttpRequest();
        const url = "https://generativelanguage.googleapis.com/v1beta/models/" + modelName + ":generateContent";

        xhr.open("POST", url);
        xhr.timeout = 20000;
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("X-goog-api-key", apiKey);

        xhr.ontimeout = function() {
            geminiView.isLoading = false;
            if (conversationHistory.length > 0) conversationHistory.pop();
            chatModel.append({ role: "error", text: "Request timed out. Google servers did not respond in time." });
        };

        xhr.onerror = function() {
            geminiView.isLoading = false;
            if (conversationHistory.length > 0) conversationHistory.pop();
            chatModel.append({ role: "error", text: "Network error occurred." });
        };

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                geminiView.isLoading = false;

                if (xhr.status === 200) {
                    try {
                        const res = JSON.parse(xhr.responseText);
                        if (res.candidates && res.candidates.length > 0 && res.candidates[0].content) {
                            const answer = res.candidates[0].content.parts[0].text;
                            chatModel.append({ role: "model", text: answer });
                            conversationHistory.push({ role: "model", parts: [{ text: answer }] });
                        } else {
                            chatModel.append({ role: "error", text: "Received empty candidate response from Gemini." });
                        }
                    } catch(e) {
                        chatModel.append({ role: "error", text: "Failed to parse API response: " + e.message });
                    }
                } else if (xhr.status !== 0) {
                    // Pop failed user question so history stays pure
                    if (conversationHistory.length > 0) conversationHistory.pop();

                    let errorMsg = "Error " + xhr.status + ": " + xhr.statusText;
                    if (xhr.status === 503) {
                        errorMsg = "Temporary High Demand (503): Google's free tier is experiencing a momentary spike. Click Retry to try again.";
                    } else if (xhr.responseText) {
                        try {
                            const errObj = JSON.parse(xhr.responseText);
                            if (errObj.error && errObj.error.message) {
                                errorMsg = "Error " + xhr.status + ": " + errObj.error.message;
                            }
                        } catch(e) {}
                    }
                    chatModel.append({ role: "error", text: errorMsg });
                }
            }
        };

        try {
            xhr.send(JSON.stringify({ contents: conversationHistory }));
        } catch(e) {
            geminiView.isLoading = false;
            if (conversationHistory.length > 0) conversationHistory.pop();
            chatModel.append({ role: "error", text: "Send error: " + e.message });
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Subheader Toolbar
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Session Context: " + conversationHistory.length + " turns"
                color: geminiView.yellowAccent
                font.bold: true
                font.pixelSize: 15
                Layout.fillWidth: true
            }

            Rectangle {
                width: 130
                height: 34
                radius: 6
                color: clearHover.hovered ? geminiView.yellowAccent : "transparent"
                border.color: geminiView.yellowAccent
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: "Clear Context"
                    color: clearHover.hovered ? "#11111b" : geminiView.yellowAccent
                    font.bold: true
                    font.pixelSize: 13
                }

                HoverHandler { id: clearHover }
                TapHandler { onTapped: geminiView.clearContext() }
            }
        }

        // Chat View
        ListView {
            id: chatList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 16
            model: ListModel { id: chatModel }

            onCountChanged: chatList.positionViewAtEnd()

            delegate: RowLayout {
                width: chatList.width
                spacing: 8
                layoutDirection: model.role === "user" ? Qt.RightToLeft : Qt.LeftToRight

                Rectangle {
                    id: bubbleRect
                    Layout.maximumWidth: chatList.width * 0.92
                    implicitWidth: Math.max(messageText.implicitWidth + 40, 160)
                    implicitHeight: messageText.implicitHeight + (model.role === "user" ? 28 : 50)
                    radius: 12

                    color: {
                        if (model.role === "user") return "#2a2818";
                        if (model.role === "error") return "#33161c";
                        return geminiView.bgCard;
                    }
                    border.color: model.role === "error" ? geminiView.errorColor : geminiView.yellowAccent
                    border.width: 2

                    // Message Content
                    TextEdit {
                        id: messageText
                        anchors.fill: parent
                        anchors.topMargin: (model.role === "user") ? 12 : 36
                        anchors.bottomMargin: 14
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16

                        text: model.text
                        color: model.role === "error" ? geminiView.errorColor : geminiView.yellowAccent
                        font.pixelSize: 20
                        font.family: "JetBrains Mono, monospace"
                        wrapMode: Text.Wrap
                        readOnly: true
                        selectByMouse: true
                        textFormat: TextEdit.MarkdownText
                        selectionColor: geminiView.yellowAccent
                        selectedTextColor: "#11111b"
                    }

                    // RETRY BUTTON (Only visible on error cards)
                    Rectangle {
                        id: retryBtn
                        visible: model.role === "error" && !geminiView.isLoading
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8
                        width: 80
                        height: 26
                        radius: 5
                        color: retryHover.hovered ? geminiView.errorColor : "transparent"
                        border.color: geminiView.errorColor
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "↻ Retry"
                            color: retryHover.hovered ? "#11111b" : geminiView.errorColor
                            font.pixelSize: 13
                            font.bold: true
                        }

                        HoverHandler { id: retryHover }
                        TapHandler {
                            onTapped: geminiView.retryLastMessage()
                        }
                    }

                    // COPY BUTTON (Visible on model cards)
                    Rectangle {
                        id: copyBtn
                        visible: model.role === "model"
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8
                        width: copyLabel.implicitWidth + 16
                        height: 26
                        radius: 5
                        color: copyHover.hovered || copyBtn.copied ? geminiView.yellowAccent : "transparent"
                        border.color: geminiView.yellowAccent
                        border.width: 1

                        property bool copied: false
                        readonly property bool containsCode: geminiView.hasCodeBlock(model.text)

                        Timer {
                            id: resetCopiedTimer
                            interval: 1500
                            repeat: false
                            onTriggered: copyBtn.copied = false
                        }

                        Text {
                            id: copyLabel
                            anchors.centerIn: parent
                            text: {
                                if (copyBtn.copied) return "✓ Copied!";
                                return copyBtn.containsCode ? "Copy Code" : "Copy";
                            }
                            color: copyBtn.copied || copyHover.hovered ? "#11111b" : geminiView.yellowAccent
                            font.pixelSize: 13
                            font.bold: true
                        }

                        HoverHandler { id: copyHover }

                        TapHandler {
                            onTapped: {
                                const cleanCode = geminiView.extractCodeOnly(model.text);
                                Quickshell.clipboardText = cleanCode;
                                copyBtn.copied = true;
                                resetCopiedTimer.restart();
                            }
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 8
            }
        }

        // Thinking Indicator
        Text {
            visible: geminiView.isLoading
            text: "✦ Gemini is thinking..."
            color: geminiView.yellowAccent
            font.italic: true
            font.bold: true
            font.pixelSize: 16
        }
    }
}
