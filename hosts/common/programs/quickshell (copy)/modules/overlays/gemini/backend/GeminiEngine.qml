import QtQuick
import Quickshell

QtObject {
    id: engine

    property string apiKey: ""
    property var conversationHistory: []
    property bool isLoading: false
    property string lastUserPrompt: ""
    property string modelName: "gemini-flash-latest"

    property var chatModel: ListModel { id: cModel }

    Component.onCompleted: loadApiKey()

    function loadApiKey() {
        var envKey = Quickshell.env("GEMINI_API_KEY");
        if (envKey && envKey.trim().length > 0) { engine.apiKey = envKey.trim(); return; }
        var localKeyPath = "file://" + (Quickshell.env("HOME") || "") + "/.config/quickshell/gemini_key";
        var localXhr = new XMLHttpRequest();
        localXhr.open("GET", localKeyPath);
        localXhr.onreadystatechange = function() {
            if (localXhr.readyState === XMLHttpRequest.DONE) {
                if ((localXhr.status === 200 || localXhr.status === 0) && localXhr.responseText.trim().length > 0) {
                    engine.apiKey = localXhr.responseText.trim();
                } else {
                    var secretXhr = new XMLHttpRequest();
                    secretXhr.open("GET", "file:///run/secrets/gemini_token");
                    secretXhr.onreadystatechange = function() {
                        if (secretXhr.readyState === XMLHttpRequest.DONE && (secretXhr.status === 200 || secretXhr.status === 0)) {
                            let token = secretXhr.responseText.trim();
                            if (token.length > 0) engine.apiKey = token;
                        }
                    };
                    secretXhr.send();
                }
            }
        };
        localXhr.send();
    }

    function saveUserKey(keyText) {
        if (!keyText || keyText.trim().length === 0) return;
        var cleanKey = keyText.trim();
        engine.apiKey = cleanKey;
        Quickshell.execDetached([
            "sh", "-c",
            'mkdir -p "$HOME/.config/quickshell" && install -m 600 /dev/null "$HOME/.config/quickshell/gemini_key" && printf "%s" "$1" > "$HOME/.config/quickshell/gemini_key"',
            "sh", cleanKey
        ]);
    }

    function clearContext() {
        conversationHistory = [];
        cModel.clear();
        isLoading = false;
        lastUserPrompt = "";
    }

    function extractCodeOnly(rawText) {
        if (!rawText) return "";
        const codeBlockRegex = /```(?:[a-zA-Z0-9_\-\+]+)?\n([\s\S]*?)```/g;
        let matches = [];
        let match;
        while ((match = codeBlockRegex.exec(rawText)) !== null) matches.push(match[1].trim());
        if (matches.length > 0) return matches.join("\n\n");
        return rawText.trim();
    }

    function sendMessage(text) {
        if (!text || text.trim() === "" || isLoading) return;
        if (!apiKey || apiKey === "") {
            loadApiKey();
            cModel.append({ role: "error", text: "Please configure your Gemini API key." });
            return;
        }
        let userText = text.trim();
        lastUserPrompt = userText;
        cModel.append({ role: "user", text: userText });
        conversationHistory.push({ role: "user", parts: [{ text: userText }] });
        isLoading = true;

        const xhr = new XMLHttpRequest();
        const url = "https://generativelanguage.googleapis.com/v1beta/models/" + modelName + ":generateContent";
        xhr.open("POST", url);
        xhr.timeout = 20000;
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("X-goog-api-key", apiKey);

        xhr.ontimeout = function() {
            engine.isLoading = false;
            if (conversationHistory.length > 0) conversationHistory.pop();
            cModel.append({ role: "error", text: "Request timed out." });
        };
        xhr.onerror = function() {
            engine.isLoading = false;
            if (conversationHistory.length > 0) conversationHistory.pop();
            cModel.append({ role: "error", text: "Network connection error." });
        };
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                engine.isLoading = false;
                if (xhr.status === 200) {
                    try {
                        const res = JSON.parse(xhr.responseText);
                        if (res.candidates && res.candidates.length > 0 && res.candidates[0].content) {
                            const answer = res.candidates[0].content.parts[0].text;
                            cModel.append({ role: "model", text: answer });
                            conversationHistory.push({ role: "model", parts: [{ text: answer }] });
                        }
                    } catch(e) { cModel.append({ role: "error", text: "Parse error: " + e.message }); }
                } else if (xhr.status !== 0) {
                    if (conversationHistory.length > 0) conversationHistory.pop();
                    cModel.append({ role: "error", text: "API Error " + xhr.status + ": " + xhr.statusText });
                }
            }
        };
        xhr.send(JSON.stringify({ contents: conversationHistory }));
    }
}
