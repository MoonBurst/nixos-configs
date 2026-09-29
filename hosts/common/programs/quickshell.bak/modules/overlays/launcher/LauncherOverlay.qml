import QtQuick
import QtQuick.Layouts 1.15
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "." as LauncherModule
import "../../common/Utils.js" as Utils

Rectangle {
    id: launcherRoot

    property var shell
    property var launcherWindow
    property var settingsManager: null
    property string currentDefinition: ""
    property string mode: "apps"

    property string mathResultString: ""
    property int mathSelectedIndex: 0
    onMathResultStringChanged: mathSelectedIndex = 0

    function runCalculator(query) {
        var res = Utils.evaluate(query, launcherRoot.mode === "math");
        if (res !== null) {
            if (res !== "") launcherRoot.mathResultString = res;
            return true;
        }
        return false;
    }

    readonly property bool isStartPageOpen: mode === "startPage"
    readonly property bool isAppsOpen: mode === "apps"
    readonly property bool isClipboardOpen: mode === "clipboard"
    readonly property bool isEmailOpen: mode === "Email"
    readonly property bool isTodoOpen: mode === "todo"
    readonly property bool isPassOpen: mode === "pass"
    readonly property bool isGeminiOpen: mode === "gemini"
    readonly property bool isSettingsOpen: mode === "settings"
    readonly property bool isNotesOpen: mode === "notes"
    readonly property bool isAmogusOpen: mode === "amogus"

    readonly property var ctrl: LauncherModule.LauncherController
    property var activeController: null

    Binding {
        target: launcherRoot
        property: "activeController"
        value: {
            if (launcherRoot.mode === "apps") return launcherRoot.ctrl.appLauncher
            if (launcherRoot.mode === "clipboard") return launcherRoot.ctrl.clipboard
            if (launcherRoot.mode === "dictionary") return launcherRoot.ctrl.dictionary
            if (launcherRoot.mode === "math") return null
            if (launcherRoot.mode === "unicode") return launcherRoot.ctrl.unicodeSearch
            if (launcherRoot.mode.toLowerCase() === "startpage") return launcherRoot.ctrl.startPage
            if (launcherRoot.mode.toLowerCase() === "email") return launcherRoot.ctrl.email
            if (launcherRoot.mode === "todo") return launcherRoot.ctrl.todo
            if (launcherRoot.mode === "pass") return (passLoader.item || launcherRoot.ctrl.pass)
            return null
        }
    }

    // Resolves currently highlighted or top matching key from the active visual list
    readonly property string topPassKey: {
        if (launcherRoot.mode !== "pass") return "";
        var passObj = passLoader.item || (launcherRoot.ctrl ? launcherRoot.ctrl.pass : null);
        if (passObj && passObj.filteredModelCount > 0) {
            if (typeof passObj.getKeyAt === "function") {
                return passObj.getKeyAt(passObj.selectedIndex);
            }
            return passObj.firstMatchedKey || "";
        }
        return "";
    }

    // Full target string including "pass " prefix if user typed it
    function getCompletedPassText() {
        var key = launcherRoot.topPassKey;
        if (!key) return "";
        var raw = searchField.text.trim();
        if (raw.toLowerCase().startsWith("pass ")) {
            return "pass " + key;
        } else if (raw.toLowerCase().startsWith("password ")) {
            return "password " + key;
        }
        return key;
    }

    anchors.fill: parent
    color: mode !== "" ? "#00000088" : "transparent"
    visible: true
    focus: true

    Timer {
        id: searchDebounceTimer
        interval: 35
        repeat: false
        property string pendingText: ""
        onTriggered: {
            const raw = pendingText;
            const trimmed = raw.trim();
            const lower = trimmed.toLowerCase();
            const currentMode = launcherRoot.mode;

            if (currentMode === "gemini") return;

            const cfgTriggers = ["settings", "setting", "config", "cfg", "options", "opt"];
            if (cfgTriggers.includes(lower) || raw.startsWith("set ") || raw.startsWith("cfg ")) {
                launcherRoot.mode = "settings";
                return;
            }

            const pwrTriggers = ["power", "pwr", "session", "sys", "reboot", "restart", "shutdown", "poweroff", "sleep", "suspend", "logout"];
            if (pwrTriggers.includes(lower) || raw.startsWith("pwr ") || raw.startsWith("power ")) {
                launcherRoot.mode = "power";
                return;
            }

            if (lower === "em" || lower === "email" || lower === "mail" || raw.startsWith("em ") || raw.startsWith("email ")) {
                launcherRoot.mode = "Email";
                var emQuery = (raw.indexOf(" ") !== -1) ? raw.slice(raw.indexOf(" ") + 1).trim() : "";
                if (ctrl.email && typeof ctrl.email.refreshFilter === "function") {
                    ctrl.email.refreshFilter(emQuery);
                }
                return;
            }

            if (lower === "def" || lower === "dict" || lower === "dictionary" || raw.startsWith("def ") || raw.startsWith("dict ")) {
                launcherRoot.mode = "dictionary";
                var defQuery = (raw.indexOf(" ") !== -1) ? raw.slice(raw.indexOf(" ") + 1).trim() : "";
                ctrl.dictionary.fetch(defQuery);
                return;
            }

            if (lower === "pass" || lower === "password" || lower === "passwords" || raw.startsWith("pass ") || raw.startsWith("password ")) {
                launcherRoot.mode = "pass";
                var passQuery = (raw.indexOf(" ") !== -1) ? raw.slice(raw.indexOf(" ") + 1).trim() : "";
                if (passLoader.item) passLoader.item.searchQuery = passQuery;
                if (ctrl.pass) ctrl.pass.searchQuery = passQuery;
                return;
            }

            if (lower === "td" || lower === "todo" || raw.startsWith("td ") || raw.startsWith("todo ")) {
                launcherRoot.mode = "todo";
                return;
            }

                        const amogusTriggers = ["amogus", "amongus", "sus", "impostor", "imposter", "crewmate"];
            if (amogusTriggers.includes(lower) || raw.startsWith("amogus ") || raw.startsWith("sus ")) {
                searchField.clear();
                launcherRoot.closeOverlay();
                if (shell && shell.amogusWindowInstance) {
                    shell.amogusWindowInstance.showWindow();
                }
                return;
            }

            if (lower === "note" || lower === "notes" || raw.startsWith("note ") || raw.startsWith("notes ")) {
                launcherRoot.mode = "notes";
                return;
            }

            if (searchField.text.trim() === "") {
                if (currentMode === "clipboard") ctrl.clipboard.refreshFilter("");
                else if (currentMode === "pass") {
                    if (passLoader.item) passLoader.item.searchQuery = "";
                    if (ctrl.pass) ctrl.pass.searchQuery = "";
                }
                else if (currentMode === "unicode") ctrl.unicodeSearch.refreshFilter("");
                else if (currentMode === "dictionary") ctrl.dictionary.fetch("");
                else if (currentMode === "Email" && ctrl.email && typeof ctrl.email.refreshFilter === "function") ctrl.email.refreshFilter("");
                else if (currentMode === "apps") ctrl.appLauncher.refreshFilter("");
                return;
            }

            if (currentMode === "notes") return;
            if (currentMode === "clipboard") { ctrl.clipboard.refreshFilter(searchField.text.trim()); return; }
            if (currentMode === "pass") {
                var pQuery = (raw.indexOf(" ") !== -1 && (lower.startsWith("pass ") || lower.startsWith("password "))) ? raw.slice(raw.indexOf(" ") + 1).trim() : searchField.text.trim();
                if (passLoader.item) passLoader.item.searchQuery = pQuery;
                if (ctrl.pass) ctrl.pass.searchQuery = pQuery;
                return;
            }
            if (currentMode === "math") {
                runCalculator(searchField.text.trim());
                return;
            }
            if (currentMode === "dictionary") {
                var dQuery = (raw.indexOf(" ") !== -1 && (lower.startsWith("def ") || lower.startsWith("dict "))) ? raw.slice(raw.indexOf(" ") + 1).trim() : searchField.text.trim();
                ctrl.dictionary.fetch(dQuery);
                return;
            }
            if (currentMode === "Email") {
                var eQuery = (raw.indexOf(" ") !== -1 && (lower.startsWith("em ") || lower.startsWith("email "))) ? raw.slice(raw.indexOf(" ") + 1).trim() : searchField.text.trim();
                if (ctrl.email && typeof ctrl.email.refreshFilter === "function") {
                    ctrl.email.refreshFilter(eQuery);
                }
                return;
            }

            if (searchField.text.trim().length > 1 && searchField.text.trim().indexOf("?") === 0) {
                launcherRoot.mode = "startpage";
                const cleanQuery = searchField.text.trim().substring(1).trim();
                if (launcherRoot.ctrl.startPage) launcherRoot.ctrl.startPage.updateSearch(cleanQuery);
                if (searchLoader.item) searchLoader.item.updateSearch(cleanQuery);
                return;
            }

            if (searchField.text.trim().startsWith(".")) {
                launcherRoot.mode = "unicode";
                const unicodeQuery = searchField.text.trim().substring(1).trim();
                launcherRoot.ctrl.unicodeSearch.refreshFilter(unicodeQuery);
                return;
            }

            if (runCalculator(searchField.text.trim())) {
                launcherRoot.mode = "math";
                return;
            }

            if (searchField.text.trim() === "rng" || searchField.text.trim() === "dice" || searchField.text.trim() === "roll" || searchField.text.trim() === "coin" || searchField.text.trim().startsWith("rng ") || searchField.text.trim().startsWith("roll ")) {
                launcherRoot.closeOverlay();
                if (ctrl.rng) ctrl.rng.showWindow();
                return;
            }

            if (searchField.text.trim().startsWith("ai ") || searchField.text.trim().startsWith("gemini ")) {
                launcherRoot.mode = "gemini";
                return;
            }

            launcherRoot.mode = "apps";
            launcherRoot.ctrl.appLauncher.refreshFilter(searchField.text.trim());
        }
    }

    Component.onCompleted: {
        appsLoader.active = true
    }

    function closeOverlay() {
        if (settingsManager) settingsManager.previewCapsule = "";
        launcherRoot.mode = "";
        launcherWindow.visible = false;
    }

    function toggleOverlayMode(targetMode) {
        if (mode === targetMode && launcherWindow.visible) {
            closeOverlay();
        } else {
            launcherRoot.mode = targetMode;
            searchField.clear();

            if (targetMode === "clipboard") { ctrl.clipboard.loadClipboard(); ctrl.clipboard.refreshFilter(""); }
            else if (targetMode === "apps") ctrl.appLauncher.refreshFilter("");
            else if (targetMode === "pass") {
                if (passLoader.item) {
                    passLoader.item.searchQuery = "";
                    if (typeof passLoader.item.reload === "function") passLoader.item.reload();
                }
                if (ctrl.pass) {
                    ctrl.pass.searchQuery = "";
                    if (typeof ctrl.pass.reload === "function") ctrl.pass.reload();
                }
            }

            launcherWindow.visible = true;

            if (targetMode === "todo") {
                Qt.callLater(function() { if (todoLoader.item) todoLoader.item.forceActiveFocus(); });
            } else if (targetMode.toLowerCase() === "email") {
                // Email manages its own list focus
            } else {
                searchField.forceActiveFocus();
            }
        }
    }

    function toggleLauncher() {
        var defaultMode = (shell && shell.settingsManager && shell.settingsManager.defaultLauncherMode) ? shell.settingsManager.defaultLauncherMode : "apps";
        toggleOverlayMode(defaultMode);
    }
    function toggleClipboard() { toggleOverlayMode("clipboard"); }
    function toggleTodo() { toggleOverlayMode("todo"); }
    function togglePower() { toggleOverlayMode("power"); }
    function togglePass() { toggleOverlayMode("pass"); }
    function toggleGemini() { toggleOverlayMode("gemini"); }
    function toggleSettings() { toggleOverlayMode("settings"); }
    function toggleEmail() { if (mode === "Email" && launcherWindow.visible) closeOverlay(); else toggleOverlayMode("Email"); }
    function toggleRng() {
        closeOverlay();
        if (ctrl.rng) ctrl.rng.toggleWindow();
    }

    function openDictionary(word) {
        launcherRoot.mode = "dictionary"
        searchField.text = word || ""
        ctrl.dictionary.fetch(searchField.text)
        launcherWindow.visible = true
        searchField.forceActiveFocus()
    }

    function navigateActiveList(up) {
        if (mode === "dictionary" && dictionaryLoader.item) {
            if (up) ctrl.dictionary.selectPrev(); else ctrl.dictionary.selectNext();
            dictionaryLoader.item.currentIndex = ctrl.dictionary.selectedIndex;
            dictionaryLoader.item.positionViewAtIndex(dictionaryLoader.item.currentIndex, ListView.Contain);
        } else if (mode === "unicode" && unicodeLoader.item) {
            if (up) ctrl.unicodeSearch.moveUp(); else ctrl.unicodeSearch.moveDown();
            unicodeLoader.item.currentIndex = ctrl.unicodeSearch.selectedIndex;
            unicodeLoader.item.positionViewAtIndex(unicodeLoader.item.currentIndex, ListView.Contain);
        } else if (mode === "notes" && notesLoader.item) {
            if (up) notesLoader.item.selectPrev(); else notesLoader.item.selectNext();
        } else if (mode === "power" && powerLoader.item) {
            if (up) powerLoader.item.selectPrev(); else powerLoader.item.selectNext();
        } else if (mode === "pass") {
            var pItem = passLoader.item || ctrl.pass;
            if (pItem) {
                if (up) pItem.selectPrev(); else pItem.selectNext();
                if (pItem.targetListView) {
                    pItem.targetListView.currentIndex = pItem.selectedIndex;
                    pItem.targetListView.positionViewAtIndex(pItem.selectedIndex, ListView.Contain);
                }
            }
        } else if (mode === "clipboard" && clipboardLoader.item && clipboardLoader.listViewInstance) {
            if (up) ctrl.clipboard.moveUp(); else ctrl.clipboard.moveDown();
            clipboardLoader.listViewInstance.positionViewAtIndex(ctrl.clipboard.selectedIndex, ListView.Contain);
        } else if (mode === "apps" && appsLoader.item) {
            if (up) {
                if (appsLoader.item.currentIndex > 0) appsLoader.item.currentIndex--;
            } else {
                if (appsLoader.item.currentIndex < ctrl.appLauncher.filteredApps.count - 1) appsLoader.item.currentIndex++;
            }
        }
    }

    MouseArea { 
        anchors.fill: parent; 
        onClicked: {
            if (settingsManager) settingsManager.previewCapsule = "";
            launcherRoot.closeOverlay();
        }
    }

    Keys.onEscapePressed: {
        launcherRoot.closeOverlay();
    }

    Rectangle {
        id: mainPanel
        anchors.centerIn: parent
        height: (settingsManager && settingsManager.launcherHeight > 0) ? settingsManager.launcherHeight : 700
        radius: 16
        color: shell.theme.base01
        border.width: 5
        border.color: shell.theme.base03
        width: launcherRoot.mode === "clipboard" ? 1100
             : (launcherRoot.mode === "settings" ? 1020
             : ((settingsManager && settingsManager.launcherWidth > 0) ? settingsManager.launcherWidth : 840))
        visible: launcherRoot.mode !== "" && launcherRoot.mode.toLowerCase() !== "email"

        Column {
            anchors.fill: parent
            anchors.margins: shell.theme.globalPadding
            spacing: 20

            readonly property real contentHeight: height - searchField.height - spacing

            FontMetrics {
                id: searchFontMetrics
                font: searchField.font
            }

            TextField {
                id: searchField
                width: parent.width
                leftPadding: 20
                rightPadding: (launcherRoot.mode === "pass" && launcherRoot.topPassKey !== "") ? (autoBadge.width + 30) : 20
                height: 50

                focus: true
                visible: launcherRoot.mode !== "todo" && launcherRoot.mode.toLowerCase() !== "email"

                color: shell.theme.base05
                font.pixelSize: 26
                placeholderTextColor: shell.theme.base05

                placeholderText: {
                    const currentMode = launcherRoot.mode
                    if (currentMode === "settings") return "System Settings (Type query to exit, or adjust below)..."
                    if (currentMode === "gemini") return "Ask Gemini... (Enter to send, Tab to clear)"
                    if (currentMode === "clipboard") return "Search clipboard history... [Tab to clear]"
                    if (currentMode === "unicode") return "Search unicode symbols... [Tab to clear]"
                    if (currentMode === "dictionary") return "Enter word... [Tab to clear]"
                    if (currentMode === "power") return "Choose power action (Enter to confirm)..."
                    if (currentMode === "pass") return "Search passwords... (Enter to auto-complete)"
                    if (currentMode === "notes") return "Type note to save (Enter to add, Del to remove)..."
                    if (currentMode === "amogus") return "Among Us Tracker (Click to dim, 'R' to reset, Esc to exit)..."
                    return "Search applications (or type 'settings')..."
                }

                // INLINE GHOST COMPLETION TEXT (Trailing directly behind typed text)
                Text {
                    id: inlineGhostText
                    visible: launcherRoot.mode === "pass" && searchField.text !== "" && launcherRoot.topPassKey !== "" && searchField.activeFocus
                    x: searchField.leftPadding + searchFontMetrics.advanceWidth(searchField.text)
                    anchors.verticalCenter: parent.verticalCenter
                    font: searchField.font
                    width: Math.max(0, parent.width - x - (autoBadge.visible ? autoBadge.width + 30 : 20))
                    clip: true
                    elide: Text.ElideRight

                    text: {
                        var fullText = launcherRoot.getCompletedPassText();
                        var typed = searchField.text;
                        if (!fullText || !typed) return "";
                        if (fullText.toLowerCase().startsWith(typed.toLowerCase())) {
                            return fullText.substring(typed.length);
                        } else {
                            return " → " + launcherRoot.topPassKey;
                        }
                    }
                    color: "#00e5ff"
                    opacity: 0.55
                }

                background: Rectangle {
                    radius: 10
                    color: "transparent"
                    border.width: 4
                    border.color: shell.theme.base05

                    // AUTO-COMPLETE PILL ON THE RIGHT
                    Rectangle {
                        id: autoBadge
                        visible: launcherRoot.mode === "pass" && launcherRoot.topPassKey !== "" && searchField.text.trim().toLowerCase() !== launcherRoot.getCompletedPassText().toLowerCase()
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        height: 32
                        width: badgeRow.implicitWidth + 20
                        radius: 6
                        color: "#182030"
                        border.color: "#00e5ff"
                        border.width: 1.5

                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "↵ Complete:"; color: "#00e5ff"; font.bold: true; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: launcherRoot.topPassKey; color: "#ffffff"; font.bold: true; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                onTextChanged: {
                    var trimmed = text.trim();
                    if (runCalculator(trimmed)) {
                        launcherRoot.mode = "math";
                        return;
                    } else if (launcherRoot.mode === "math" && !trimmed) {
                        launcherRoot.mode = "apps";
                    }

                    if (launcherRoot.mode === "" && text !== "") launcherRoot.mode = "apps";
                    var current = launcherRoot.mode;
                    if (current === "apps" || current === "") {
                        ctrl.appLauncher.refreshFilter(text);
                    }
                    searchDebounceTimer.pendingText = text;
                    searchDebounceTimer.restart();
                }

                Keys.onDownPressed: {
                    if (launcherRoot.mode === "math" && launcherRoot.mathResultString.indexOf("\n") !== -1) {
                        var total = launcherRoot.mathResultString.split("\n").length;
                        launcherRoot.mathSelectedIndex = (launcherRoot.mathSelectedIndex + 3) % total;
                    } else {
                        launcherRoot.navigateActiveList(false);
                    }
                }
                Keys.onUpPressed: {
                    if (launcherRoot.mode === "math" && launcherRoot.mathResultString.indexOf("\n") !== -1) {
                        var total = launcherRoot.mathResultString.split("\n").length;
                        launcherRoot.mathSelectedIndex = (launcherRoot.mathSelectedIndex - 3 + total) % total;
                    } else {
                        launcherRoot.navigateActiveList(true);
                    }
                }

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        launcherRoot.closeOverlay();
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Tab) {
                        if (launcherRoot.mode === "gemini" && geminiLoader.item) {
                            geminiLoader.item.clearContext();
                            searchField.clear();
                            event.accepted = true;
                            return;
                        }
                        if (searchField.text !== "") {
                            searchField.clear();
                            if (passLoader.item) passLoader.item.searchQuery = "";
                            if (launcherRoot.ctrl.pass) launcherRoot.ctrl.pass.searchQuery = "";
                            if (launcherRoot.mode === "clipboard") launcherRoot.ctrl.clipboard.refreshFilter("");
                            else if (launcherRoot.mode === "unicode") launcherRoot.ctrl.unicodeSearch.refreshFilter("");
                            event.accepted = true;
                            return;
                        } else if (launcherRoot.mode !== "apps" && launcherRoot.mode !== "") {
                            launcherRoot.mode = "apps";
                            launcherRoot.ctrl.appLauncher.refreshFilter("");
                            event.accepted = true;
                            return;
                        }
                    }

                    if (launcherRoot.mode === "math" && launcherRoot.mathResultString.indexOf("\n") !== -1) {
                        var totalItems = launcherRoot.mathResultString.split("\n").length;
                        if (event.key === Qt.Key_Right) {
                            launcherRoot.mathSelectedIndex = (launcherRoot.mathSelectedIndex + 1) % totalItems;
                            event.accepted = true;
                            return;
                        } else if (event.key === Qt.Key_Left) {
                            launcherRoot.mathSelectedIndex = (launcherRoot.mathSelectedIndex - 1 + totalItems) % totalItems;
                            event.accepted = true;
                            return;
                        } else if (event.key === Qt.Key_Down) {
                            launcherRoot.mathSelectedIndex = (launcherRoot.mathSelectedIndex + 3) % totalItems;
                            event.accepted = true;
                            return;
                        } else if (event.key === Qt.Key_Up) {
                            launcherRoot.mathSelectedIndex = (launcherRoot.mathSelectedIndex - 3 + totalItems) % totalItems;
                            event.accepted = true;
                            return;
                        }
                    }

                    if (event.key === Qt.Key_Backspace && searchField.text === "") {
                        if (launcherRoot.mode !== "apps") {
                            launcherRoot.mode = "apps";
                            event.accepted = true;
                            return;
                        }
                    }

                                        if (event.key === Qt.Key_Delete) {
                        if (launcherRoot.mode === "notes" && notesLoader.item) {
                            notesLoader.item.deleteSelected();
                            event.accepted = true;
                            return;
                        }
                        if (launcherRoot.mode === "clipboard") {
                            var isCtrlShift = (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier);
                            if (isCtrlShift) {
                                launcherRoot.ctrl.clipboard.wipeHistory();
                            } else {
                                launcherRoot.ctrl.clipboard.deleteSelected();
                            }
                            event.accepted = true;
                            return;
                        }
                    }
                }

                Keys.onEnterPressed: searchField.Keys.onReturnPressed(event)
                Keys.onReturnPressed: function(event) {
                    var rawText = searchField.text.trim();
                    var lowerText = rawText.toLowerCase();

                    // PASS AUTO-COMPLETE HANDLER
                    if (launcherRoot.mode === "pass") {
                        var pItem = passLoader.item || ctrl.pass;
                        var targetKey = launcherRoot.topPassKey;
                        var fullCompleteText = launcherRoot.getCompletedPassText();

                        // 1. If not completed yet, complete to the matched target
                        if (targetKey !== "" && fullCompleteText !== "" && searchField.text.trim().toLowerCase() !== fullCompleteText.toLowerCase()) {
                            searchField.text = fullCompleteText;
                            searchField.cursorPosition = searchField.text.length;
                            if (pItem) pItem.searchQuery = targetKey;
                            event.accepted = true;
                            return;
                        }

                        // 2. If already completed, copy and close
                        if (pItem && typeof pItem.decryptAndCopySelected === "function") {
                            pItem.decryptAndCopySelected();
                        } else if (ctrl.pass) {
                            ctrl.pass.decryptAndCopySelected();
                        }
                        launcherRoot.closeOverlay();
                        event.accepted = true;
                        return;
                    }

                    if (lowerText.startsWith("note ") || lowerText.startsWith("notes ")) {
                        var noteBody = rawText.slice(rawText.indexOf(" ") + 1).trim();
                        if (noteBody !== "") {
                            if (notesLoader.item) {
                                notesLoader.item.addNote(noteBody);
                            } else {
                                // Fallback direct execution
                                var notesFile = (launcherRoot.settingsManager && launcherRoot.settingsManager.notesFilePath)
                                    ? launcherRoot.settingsManager.notesFilePath : (Quickshell.env("HOME") + "/Documents/notes.txt");
                                Quickshell.execDetached([
                                    "sh", "-c",
                                    'mkdir -p "$(dirname "$1")"; ts=$(date "+%Y-%m-%d %H:%M"); printf "%s | %s\n" "$ts" "$2" >> "$1"; notify-send -a Notes -i accessories-text-editor "📝 Note Saved" "$2"',
                                    "sh", notesFile, noteBody
                                ]);
                            }
                            searchField.clear();
                            launcherRoot.closeOverlay();
                            event.accepted = true;
                            return;
                        }
                    }

                    var currentMode = launcherRoot.mode;
                    if (currentMode === "notes") {
                        if (rawText !== "" && notesLoader.item) {
                            notesLoader.item.addNote(rawText);
                            searchField.clear();
                        } else if (notesLoader.item) {
                            notesLoader.item.copySelected();
                        }
                        launcherRoot.closeOverlay();
                        event.accepted = true;
                        return;
                    }

                    if (currentMode === "settings") {
                        return;
                    }
                    if (currentMode === "gemini" && geminiLoader.item) {
                        var prompt = searchField.text;
                        if (prompt.startsWith("ai ")) prompt = prompt.substring(3).trim();
                        if (prompt.startsWith("gemini ")) prompt = prompt.substring(7).trim();
                        geminiLoader.item.sendMessage(prompt);
                        searchField.clear();
                        return;
                    }
                    if (currentMode === "math") {
                        runCalculator(searchField.text.trim());
                        return;
                    }
                    if (currentMode === "dictionary") { ctrl.dictionary.copySelected(); launcherRoot.closeOverlay(); }
                    else if (currentMode === "unicode") { ctrl.unicodeSearch.copySelected(); launcherRoot.closeOverlay(); }
                    else if (currentMode === "clipboard") { ctrl.clipboard.copySelected(); launcherRoot.closeOverlay(); }
                    else if (currentMode === "apps" && appsLoader.item && appsLoader.item.currentIndex >= 0) {
                        ctrl.appLauncher.launch(ctrl.appLauncher.filteredApps.get(appsLoader.item.currentIndex).exec);
                        launcherRoot.closeOverlay();
                    } else if (currentMode === "startpage" && searchLoader.item) {
                        searchLoader.item.openSearch();
                        launcherRoot.closeOverlay();
                    }
                }
            }

            Loader {
                id: settingsLoader
                active: launcherRoot.mode === "settings"
                visible: active
                width: parent.width
                height: active ? parent.contentHeight : 0
                source: "SettingsPanel.qml"
                onLoaded: {
                    if (item) {
                        item.shell = launcherRoot.shell;
                        item.settingsManager = launcherRoot.settingsManager;
                    }
                }
            }

            Loader {
                id: geminiLoader
                active: launcherRoot.mode === "gemini"
                visible: launcherRoot.mode === "gemini"
                width: parent.width
                height: launcherRoot.mode === "gemini" ? parent.contentHeight : 0
                source: "GeminiPanel.qml"
                onLoaded: {
                    if (item) item.shell = launcherRoot.shell;
                }
            }

            Loader {
                id: searchLoader
                active: launcherRoot.mode === "startpage" || launcherRoot.mode === "startPage"
                visible: active
                width: parent.width
                height: active ? parent.contentHeight : 0
                source: "StartPage.qml"
                onLoaded: {
                    if (item && ctrl.startPage) {
                        var cleanText = searchDebounceTimer.pendingText;
                        if (cleanText.startsWith("?")) cleanText = cleanText.substring(1).trim();
                        item.updateSearch(cleanText);
                    }
                }
            }

            Loader {
                id: unicodeLoader
                active: launcherRoot.mode === "unicode"
                visible: active
                width: parent.width
                height: active ? parent.contentHeight : 0
                sourceComponent: ListView {
                    id: unicodeListView
                    clip: true
                    cacheBuffer: 800
                    spacing: 20
                    focus: true
                    model: ctrl.unicodeSearch.filteredUnicodeItems
                    currentIndex: ctrl.unicodeSearch.selectedIndex
                    onCurrentIndexChanged: ctrl.unicodeSearch.selectedIndex = currentIndex

                    highlightMoveDuration: 0
                    highlightResizeDuration: 0
                    flickDeceleration: 10000

                    delegate: Rectangle {
                        width: unicodeListView.width
                        height: 90
                        radius: 10
                        color: ListView.isCurrentItem ? shell.theme.base02 : "transparent"
                        border.width: ListView.isCurrentItem ? 5 : 0
                        border.color: ListView.isCurrentItem ? shell.theme.base08 : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.margins: shell.theme.globalPadding
                            spacing: 20

                            Text {
                                text: modelData.symbol
                                color: shell.theme.base05
                                font.pixelSize: 50
                                width: 50
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                text: modelData.name
                                color: shell.theme.base05
                                font.pixelSize: 20
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                ctrl.unicodeSearch.selectedIndex = index
                                unicodeListView.currentIndex = index
                                ctrl.unicodeSearch.copySelected()
                                launcherRoot.closeOverlay()
                            }
                        }
                    }
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
            }

            Loader {
                id: appsLoader
                active: true
                visible: launcherRoot.mode === "apps" || launcherRoot.mode === ""
                width: parent.width
                height: visible ? parent.contentHeight : 0
                sourceComponent: Component {
                    ListView {
                        id: appsListView
                        clip: true
                        cacheBuffer: 800
                        spacing: 20
                        model: ctrl.appLauncher.filteredApps

                        highlightMoveDuration: 0
                        highlightResizeDuration: 0
                        flickDeceleration: 10000

                        delegate: Rectangle {
                            width: appsListView ? appsListView.width : 0
                            height: (launcherRoot.settingsManager && launcherRoot.settingsManager.appItemHeight > 0)
                                ? launcherRoot.settingsManager.appItemHeight : 80
                            radius: 10
                            color: ListView.isCurrentItem ? shell.theme.base02 : mouseArea.containsMouse ? shell.theme.base01 : "transparent"
                            border.width: ListView.isCurrentItem ? 5 : 0
                            border.color: ListView.isCurrentItem ? shell.theme.base08 : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.margins: shell.theme.globalPadding
                                spacing: 20

                                Image {
                                    width: (launcherRoot.settingsManager && launcherRoot.settingsManager.appIconSize > 0)
                                        ? launcherRoot.settingsManager.appIconSize : 32
                                    height: width
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: {
                                        if (!icon) return "";
                                        var s = String(icon);
                                        return (s.startsWith("/") || s.startsWith("file://")) ? s : "image://icon/" + s;
                                    }
                                    fillMode: Image.PreserveAspectFit
                                    smooth: false
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Text { text: name || ""; color: shell.theme.base05; font.pixelSize: 18; font.bold: true }
                                    Text { text: exec || ""; color: shell.theme.base07; font.pixelSize: 14; elide: Text.ElideRight; width: appsListView ? (appsListView.width - 90) : 0 }
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: { ctrl.appLauncher.launch(exec); launcherRoot.closeOverlay(); }
                            }
                        }
                    }
                }
            }

            Loader {
                id: startPageLoader
                active: launcherRoot.mode === "startPage"
                visible: active
                width: parent.width
                height: active ? parent.contentHeight : 0
                source: "StartPage.qml"
            }

            Loader {
                id: clipboardLoader
                active: launcherRoot.mode === "clipboard"
                visible: active
                width: parent.width
                height: active ? parent.contentHeight : 0
                readonly property var listViewInstance: item ? item.targetListView : null

                sourceComponent: Component {
                    Row {
                        width: parent.width; height: parent.height; spacing: 20
                        property Item targetListView: clipboardListView

                        ListView {
                            id: clipboardListView
                            width: 540; height: parent.height; clip: true; cacheBuffer: 200; spacing: 12
                            model: ctrl.clipboard.filteredClipboardItems
                            currentIndex: ctrl.clipboard.selectedIndex

                            highlightMoveDuration: 0
                            highlightResizeDuration: 0
                            flickDeceleration: 10000

                            delegate: Rectangle {
                                readonly property int itemIndex: index
                                readonly property string itemText: model.text || ""
                                readonly property bool itemIsImage: model.isImage || false
                                readonly property string itemImagePath: model.imagePath || ""

                                width: clipboardListView.width
                                height: itemIsImage ? 120 : 70
                                radius: 10
                                color: itemIndex === ctrl.clipboard.selectedIndex ? shell.theme.base02 : "transparent"
                                border.width: ListView.isCurrentItem ? 5 : 0
                                border.color: ListView.isCurrentItem ? shell.theme.base08 : "transparent"

                                Item {
                                    anchors.fill: parent
                                    anchors.margins: shell.theme.globalPadding

                                    Image {
                                        id: listEntryImageComponent
                                        visible: itemIsImage
                                        width: 100; height: 100
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: itemIsImage && itemImagePath ? "file://" + itemImagePath : ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: false
                                    }

                                    Text {
                                        anchors.left: itemIsImage ? listEntryImageComponent.right : parent.left
                                        anchors.leftMargin: itemIsImage ? 20 : 0
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (itemText.startsWith("[Image: ") || !itemIsImage) ? itemText : "[Image Clipboard Entry]"
                                        wrapMode: Text.NoWrap
                                        elide: Text.ElideRight
                                        color: shell.theme.base05
                                        font.pixelSize: 20
                                        textFormat: Text.PlainText
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        ctrl.clipboard.selectedIndex = itemIndex;
                                        ctrl.clipboard.updatePreview();
                                    }
                                }
                            }
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        }

                        Rectangle {
                            id: previewPanel
                            width: 500; height: parent.height; radius: 12; color: shell.theme.base00; border.width: 5; border.color: shell.theme.base03

                            property var selectedItem: (ctrl.clipboard.selectedIndex >= 0 && ctrl.clipboard.selectedIndex < ctrl.clipboard.filteredClipboardItems.count) ? ctrl.clipboard.filteredClipboardItems.get(ctrl.clipboard.selectedIndex) : null
                            property bool isPromptingSudo: false
                            property bool isInstalling: false
                            property bool installError: false
                            property string statusMsg: ""

                            Process {
                                id: cliphistInstaller
                                running: false
                                stdout: SplitParser {
                                    splitMarker: "\n"
                                    onRead: data => { if (data && data.trim()) previewPanel.statusMsg = data.trim(); }
                                }
                                onExited: (code) => {
                                    previewPanel.isInstalling = false;
                                    if (code === 0) {
                                        ctrl.clipboard.hasCliphist = true;
                                        previewPanel.isPromptingSudo = false;
                                        previewPanel.installError = false;
                                        ctrl.clipboard.loadClipboard();
                                    } else {
                                        previewPanel.installError = true;
                                        previewPanel.statusMsg = "Install failed. Check password & official repos.";
                                    }
                                }
                            }

                            function runInstall(pass) {
                                if (!pass || isInstalling) return;
                                isInstalling = true;
                                installError = false;
                                statusMsg = "Installing cliphist from official repos...";
                                cliphistInstaller.command = [
                                    "sudo", "-S", "-k", "bash", "-c",
                                    "if command -v pacman >/dev/null 2>&1; then pacman -Sy --noconfirm cliphist; " +
                                    "elif command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install -y cliphist; " +
                                    "elif command -v dnf >/dev/null 2>&1; then dnf install -y cliphist; " +
                                    "elif command -v zypper >/dev/null 2>&1; then zypper install -y cliphist; " +
                                    "elif command -v nix-env >/dev/null 2>&1; then nix-env -iA nixpkgs.cliphist || nix-env -iA nixos.cliphist; " +
                                    "else echo 'No supported package manager found' >&2; exit 1; fi"
                                ];
                                cliphistInstaller.running = true;
                                cliphistInstaller.write(pass + "\n");
                            }

                            Image {
                                anchors.fill: parent; anchors.margins: shell.theme.globalPadding
                                visible: ctrl.clipboard.hasCliphist && previewPanel.selectedItem && previewPanel.selectedItem.isImage
                                source: visible ? "file://" + previewPanel.selectedItem.imagePath : ""
                                fillMode: Image.PreserveAspectFit; smooth: false
                            }

                            ScrollView {
                                id: textPreview
                                anchors.fill: parent; anchors.margins: shell.theme.globalPadding
                                visible: ctrl.clipboard.hasCliphist && previewPanel.selectedItem && !previewPanel.selectedItem.isImage
                                clip: true

                                TextArea {
                                    text: ctrl.clipboard.previewText
                                    width: textPreview.availableWidth
                                    wrapMode: Text.WrapAnywhere; readOnly: true; selectByMouse: true
                                    color: shell.theme.base05; font.pixelSize: 20; background: null; textFormat: TextEdit.PlainText; persistentSelection: true; implicitHeight: contentHeight
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 40
                                spacing: 14
                                visible: !ctrl.clipboard.hasCliphist

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "📋"
                                    font.pixelSize: 48
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Preview relies on Cliphist."
                                    font.family: shell.theme.fontFamily
                                    font.pixelSize: 20
                                    font.bold: true
                                    color: shell.theme.base05
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Clipboard previews require cliphist (official repos only)."
                                    font.family: shell.theme.fontFamily
                                    font.pixelSize: 13
                                    color: shell.theme.base05
                                    opacity: 0.7
                                }

                                Rectangle {
                                    visible: !previewPanel.isPromptingSudo
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 140; height: 38; radius: 6
                                    color: instClipHov.hovered ? shell.theme.base05 : "transparent"
                                    border.color: shell.theme.base05; border.width: 2

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Install"
                                        font.bold: true; font.pixelSize: 15
                                        color: instClipHov.hovered ? "#11111b" : shell.theme.base05
                                    }

                                    HoverHandler { id: instClipHov }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            previewPanel.isPromptingSudo = true;
                                            Qt.callLater(() => sudoClipField.forceActiveFocus());
                                        }
                                    }
                                }

                                Column {
                                    visible: previewPanel.isPromptingSudo
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width - 60
                                    spacing: 8

                                    Text {
                                        text: "Enter Sudo Password:"
                                        font.bold: true; font.pixelSize: 13
                                        color: previewPanel.installError ? "#ff5555" : shell.theme.base05
                                    }

                                    Rectangle {
                                        width: parent.width; height: 36; radius: 6
                                        color: "#11111b"
                                        border.color: previewPanel.installError ? "#ff5555" : shell.theme.base05
                                        border.width: 1.5

                                        TextInput {
                                            id: sudoClipField
                                            anchors.fill: parent; anchors.margins: 8
                                            echoMode: TextInput.Password
                                            color: shell.theme.base05
                                            font.pixelSize: 14
                                            verticalAlignment: TextInput.AlignVCenter
                                            Keys.onPressed: (event) => {
                                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                    previewPanel.runInstall(text);
                                                    event.accepted = true;
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        visible: previewPanel.statusMsg !== ""
                                        text: previewPanel.statusMsg
                                        font.pixelSize: 12
                                        color: previewPanel.installError ? "#ff5555" : "#04f100"
                                    }

                                    Row {
                                        spacing: 10
                                        Rectangle {
                                            width: 100; height: 32; radius: 4
                                            color: "transparent"; border.color: shell.theme.base05; border.width: 1
                                            Text { anchors.centerIn: parent; text: "Cancel"; color: shell.theme.base05; font.bold: true; font.pixelSize: 12 }
                                            MouseArea { anchors.fill: parent; onClicked: previewPanel.isPromptingSudo = false }
                                        }
                                        Rectangle {
                                            width: 120; height: 32; radius: 4
                                            color: shell.theme.base05
                                            Text { anchors.centerIn: parent; text: previewPanel.isInstalling ? "Installing..." : "Confirm"; color: "#11111b"; font.bold: true; font.pixelSize: 12 }
                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: !previewPanel.isInstalling
                                                onClicked: previewPanel.runInstall(sudoClipField.text)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                id: dictionaryLoader
                active: launcherRoot.mode === "dictionary"
                visible: active
                width: parent.width
                height: active ? parent.contentHeight : 0

                sourceComponent: Component {
                    ListView {
                        id: dictionaryListView
                        width: parent.width; height: parent.height; clip: true; spacing: 20; interactive: true
                        model: ctrl.dictionary.definitionEntries
                        currentIndex: ctrl.dictionary.selectedIndex

                        highlightMoveDuration: 0
                        highlightResizeDuration: 0
                        flickDeceleration: 10000

                        delegate: Rectangle {
                            width: dictionaryListView.width
                            height: definitionText.implicitHeight + 40
                            radius: 10
                            color: ListView.isCurrentItem ? shell.theme.base02 : "transparent"
                            border.width: ListView.isCurrentItem ? 5 : 0
                            border.color: ListView.isCurrentItem ? shell.theme.base08 : "transparent"

                            Text {
                                id: definitionText
                                anchors.fill: parent; anchors.margins: shell.theme.globalPadding
                                text: modelData.text; wrapMode: Text.Wrap; color: shell.theme.base05; font.pixelSize: 22
                            }

                            MouseArea {
                                id: delegateMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    launcherRoot.ctrl.dictionary.selectedIndex = index
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }
                }
            }

            Loader {
                id: mathLoader
                active: launcherRoot.mode === "math"
                visible: active
                width: parent.width
                height: active ? parent.contentHeight : 0

                sourceComponent: Component {
                    Rectangle {
                        width: mathLoader.width
                        height: mathLoader.height
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: shell.theme.base00
                            border.width: 3
                            border.color: shell.theme.base05
                            visible: launcherRoot.mathResultString.indexOf("\n") === -1

                            Column {
                                anchors.centerIn: parent
                                spacing: 14

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: launcherRoot.mathResultString
                                    color: shell.theme.base05
                                    font.pixelSize: 44
                                    font.bold: true
                                    font.family: "JetBrains Mono, monospace"
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Press [Enter] to copy result to clipboard"
                                    color: (shell && shell.theme && shell.theme.base0C) ? shell.theme.base0C : "#04f100"
                                    font.pixelSize: 14
                                    font.family: "monospace"
                                    opacity: 0.85
                                }
                            }
                        }

                        Item {
                            anchors.fill: parent
                            visible: launcherRoot.mathResultString.indexOf("\n") !== -1

                            Grid {
                                anchors.fill: parent
                                columns: 3
                                columnSpacing: 12
                                rowSpacing: 12

                                Repeater {
                                    model: launcherRoot.mathResultString.split("\n")
                                    delegate: Rectangle {
                                        id: cCard
                                        readonly property var parts: modelData.split("|")
                                        readonly property string cSym: parts.length > 3 ? parts[0] : ""
                                        readonly property string cCode: parts.length > 3 ? parts[1] : ""
                                        readonly property string cName: parts.length > 3 ? parts[2] : ""
                                        readonly property string cVal: parts.length > 3 ? parts[3] : modelData
                                        readonly property bool isSelected: index === launcherRoot.mathSelectedIndex

                                        width: Math.floor((parent.width - 24) / 3)
                                        height: Math.floor((parent.height - 36) / 4)
                                        radius: 10
                                        color: isSelected ? shell.theme.base01 : (cHov.hovered ? shell.theme.base01 : shell.theme.base00)
                                        border.color: isSelected ? ((shell && shell.theme && shell.theme.base0C) ? shell.theme.base0C : "#04f100") : (cHov.hovered ? shell.theme.base05 : shell.theme.base03)
                                        border.width: isSelected ? 3 : 1.5

                                        Behavior on border.color { ColorAnimation { duration: 100 } }

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 6

                                            Item {
                                                width: parent.width
                                                height: 20

                                                Text {
                                                    text: cCard.cCode
                                                    font.bold: true
                                                    font.pixelSize: 15
                                                    font.family: "monospace"
                                                    color: isSelected ? ((shell && shell.theme && shell.theme.base0C) ? shell.theme.base0C : "#04f100") : shell.theme.base05
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                                                    text: cCard.cSym
                                                    font.bold: true
                                                    font.pixelSize: 16
                                                    color: (shell && shell.theme && shell.theme.base09) ? shell.theme.base09 : "#fe8019"
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            Text {
                                                text: cCard.cVal
                                                font.bold: true
                                                font.pixelSize: 24
                                                font.family: "JetBrains Mono, monospace"
                                                color: isSelected ? ((shell && shell.theme && shell.theme.base0C) ? shell.theme.base0C : "#04f100") : shell.theme.base05
                                                width: parent.width
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: cCard.cName
                                                font.pixelSize: 12
                                                font.family: "monospace"
                                                color: shell.theme.base05
                                                opacity: isSelected ? 0.9 : 0.65
                                                width: parent.width
                                                elide: Text.ElideRight
                                            }
                                        }

                                        HoverHandler { id: cHov }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                launcherRoot.mathSelectedIndex = index;
                                                Quickshell.clipboardText = cCard.cVal + " " + cCard.cCode;
                                                Quickshell.execDetached(["notify-send", "-a", "Currency", "-i", "dialog-information", "💵 Copied Currency", cCard.cVal + " " + cCard.cCode]);
                                                launcherRoot.closeOverlay();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                id: amogusLoader
                active: launcherRoot.mode === "amogus"
                visible: active
                width: parent.width
                height: active ? parent.contentHeight : 0
                source: "Amogus.qml"
                onLoaded: {
                    if (item) item.shell = launcherRoot.shell;
                }
            }

            Loader {
                id: notesLoader
                active: launcherRoot.mode === "notes"
                visible: active
                focus: false
                width: parent.width
                height: active ? parent.contentHeight : 0
                source: "Notes.qml"
                onLoaded: {
                    if (item) {
                        item.shell = launcherRoot.shell;
                        item.searchQuery = Qt.binding(function() {
                            var raw = searchField.text;
                            if (raw.startsWith("note ") || raw.startsWith("notes ")) {
                                return raw.slice(raw.indexOf(" ") + 1).trim();
                            }
                            if (raw === "note" || raw === "notes") return "";
                            return raw.trim();
                        });
                        item.actionCompleted.connect(function() { launcherRoot.closeOverlay(); });
                    }
                }
            }

            Loader {
                id: todoLoader
                active: launcherRoot.mode === "todo"
                visible: active
                focus: true
                width: parent.width
                height: active ? parent.contentHeight + 70 : 0
                source: "Todo.qml"
                onLoaded: { if (item) item.forceActiveFocus(); }
            }

            Loader {
                id: powerLoader
                active: launcherRoot.mode === "power"
                visible: active
                width: parent.width
                height: active ? parent.contentHeight : 0
                source: "PowerView.qml"
                onLoaded: {
                    if (item) {
                        item.shell = launcherRoot.shell;
                        item.searchQuery = Qt.binding(function() { return searchField.text; });
                        item.actionCompleted.connect(function() { launcherRoot.closeOverlay(); });
                    }
                }
            }

            // PASS LOADER: Binds searchQuery directly to searchField text minus prefix
            Loader {
                id: passLoader
                active: launcherRoot.mode === "pass"
                visible: active
                focus: false
                width: parent.width
                height: active ? parent.contentHeight : 0
                source: "Pass.qml"
                onLoaded: {
                    if (item) {
                        item.shell = launcherRoot.shell;
                        item.searchQuery = Qt.binding(function() {
                            var raw = searchField.text.trim();
                            if (raw.toLowerCase().startsWith("pass ")) {
                                return raw.substring(5).trim();
                            } else if (raw.toLowerCase().startsWith("password ")) {
                                return raw.substring(9).trim();
                            }
                            if (raw.toLowerCase() === "pass" || raw.toLowerCase() === "password") {
                                return "";
                            }
                            return raw;
                        });
                        if (typeof item.reload === "function") item.reload();
                    }
                }
            }
        }
    }

    Item {
        width: parent.width
        height: visible ? parent.height : 0
        visible: launcherRoot.mode.toLowerCase() === "email"

        Loader {
            id: emailLoader
            active: launcherRoot.mode.toLowerCase() === "email"
            visible: active
            width: 1500
            height: 900
            anchors.centerIn: parent
            source: "Email/Email.qml"
            focus: launcherRoot.mode.toLowerCase() === "email"
            onLoaded: {
                if (item) {
                    Qt.callLater(function() {
                        if (item.innerListView) item.innerListView.forceActiveFocus();
                        else item.forceActiveFocus();
                    });
                }
            }
        }
    }
}
