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

    // DIRECT INLINE MATH EVALUATOR (Zero external dependency, 100% reliable)
            // FULL MATH, UNIT & DATA CONVERTER ENGINE
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
            if (launcherRoot.mode === "pass") return launcherRoot.ctrl.pass
            return null
        }
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
                ctrl.pass.searchQuery = passQuery;
                return;
            }

            if (lower === "td" || lower === "todo" || raw.startsWith("td ") || raw.startsWith("todo ")) {
                launcherRoot.mode = "todo";
                return;
            }

            if (lower === "note" || lower === "notes" || raw.startsWith("note ") || raw.startsWith("notes ")) {
                launcherRoot.mode = "notes";
                return;
            }

            if (searchField.text.trim() === "") {
                if (currentMode === "clipboard") ctrl.clipboard.refreshFilter("");
                else if (currentMode === "pass") ctrl.pass.searchQuery = "";
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
                ctrl.pass.searchQuery = pQuery;
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
        launcherRoot.mode = ""
        launcherWindow.visible = false
    }

    function toggleOverlayMode(targetMode) {
        if (mode === targetMode && launcherWindow.visible) {
            closeOverlay();
        } else {
            launcherRoot.mode = targetMode;
            searchField.clear();

            if (targetMode === "clipboard") { ctrl.clipboard.loadClipboard(); ctrl.clipboard.refreshFilter(""); }
            else if (targetMode === "apps") ctrl.appLauncher.refreshFilter("");
            else if (targetMode === "pass") ctrl.pass.searchQuery = "";

            launcherWindow.visible = true;

            if (targetMode === "todo") {
                Qt.callLater(function() { if (todoLoader.item) todoLoader.item.forceActiveFocus(); });
            } else if (targetMode === "pass") {
                Qt.callLater(function() { if (passLoader.item) passLoader.item.forceActiveFocus(); });
            } else if (targetMode === "notes") {
                Qt.callLater(function() { if (notesLoader.item) notesLoader.item.forceActiveFocus(); });
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
        } else if (mode === "pass" && passLoader.item && passLoader.item.targetListView) {
            if (up) ctrl.pass.selectPrev(); else ctrl.pass.selectNext();
            passLoader.item.targetListView.currentIndex = ctrl.pass.selectedIndex;
            passLoader.item.targetListView.positionViewAtIndex(passLoader.item.targetListView.currentIndex, ListView.Contain);
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

    MouseArea { anchors.fill: parent; onClicked: if (launcherRoot.mode !== "settings") launcherRoot.closeOverlay() }
    Keys.onEscapePressed: {
        if (searchField.text !== "") {
            searchField.clear();
            launcherRoot.mode = "apps";
        } else if (launcherRoot.mode !== "apps" && launcherRoot.mode !== "") {
            launcherRoot.mode = "apps";
        } else {
            launcherRoot.closeOverlay();
        }
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

            TextField {
                id: searchField
                width: parent.width
                leftPadding: 20
                height: 50

                focus: launcherRoot.mode !== "todo" && launcherRoot.mode.toLowerCase() !== "email"
                visible: focus

                color: shell.theme.base05
                font.pixelSize: 30
                placeholderTextColor: shell.theme.base05

                placeholderText: {
                    const currentMode = launcherRoot.mode
                    if (currentMode === "settings") return "System Settings (Type query to exit, or adjust below)..."
                    if (currentMode === "gemini") return "Ask Gemini... (Enter to send, Tab to clear context)"
                    if (currentMode === "clipboard") return "Search clipboard history..."
                    if (currentMode === "unicode") return "Search unicode symbols..."
                    if (currentMode === "dictionary") return "Enter word..."
                    if (currentMode === "power") return "Choose power action (Enter to confirm)..."
                    if (currentMode === "pass") return "Search passwords..."
                    if (currentMode === "notes") return "Type note to save (Enter to add, or select to copy)..."
                    return "Search applications (or type 'settings')..."
                }

                background: Rectangle {
                    radius: 10
                    color: "transparent"
                    border.width: 5
                    border.color: shell.theme.base05

                    Text {
                        id: searchSuggestionText
                        visible: launcherRoot.mode === "pass" && searchField.text !== "" && searchField.activeFocus
                        text: {
                            if (launcherRoot.ctrl.pass && launcherRoot.ctrl.pass.filteredModelCount > 0) {
                                var firstMatch = launcherRoot.ctrl.pass.firstMatchedKey;
                                var rawText = searchField.text;
                                var hasPrefix = rawText.startsWith("pass ");
                                var query = hasPrefix ? rawText.substring(5).trim().toLowerCase() : rawText.trim().toLowerCase();

                                if (query !== "" && firstMatch.toLowerCase().startsWith(query)) {
                                    return hasPrefix ? "pass " + firstMatch : firstMatch;
                                }
                            }
                            return "";
                        }
                        font.family: searchField.font.family
                        font.pixelSize: searchField.font.pixelSize
                        font.italic: true
                        color: "#00e5ff"
                        opacity: 0.8
                        anchors.fill: parent
                        anchors.leftMargin: searchField.leftPadding
                        verticalAlignment: Text.AlignVCenter
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
                    if (launcherRoot.mode === "math" && launcherRoot.mathResultString.indexOf("
") !== -1) {
                        var total = launcherRoot.mathResultString.split("
").length;
                        launcherRoot.mathSelectedIndex = (launcherRoot.mathSelectedIndex + 3) % total;
                    } else {
                        launcherRoot.navigateActiveList(false);
                    }
                }
                Keys.onUpPressed: {
                    if (launcherRoot.mode === "math" && launcherRoot.mathResultString.indexOf("
") !== -1) {
                        var total = launcherRoot.mathResultString.split("
").length;
                        launcherRoot.mathSelectedIndex = (launcherRoot.mathSelectedIndex - 3 + total) % total;
                    } else {
                        launcherRoot.navigateActiveList(true);
                    }
                }

                Keys.onPressed: function(event) {
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
                    if (event.key === Qt.Key_Escape) {
                        if (searchField.text !== "") {
                            searchField.clear();
                            launcherRoot.mode = "apps";
                            event.accepted = true;
                            return;
                        } else if (launcherRoot.mode !== "apps") {
                            launcherRoot.mode = "apps";
                            event.accepted = true;
                            return;
                        }
                        launcherRoot.closeOverlay();
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Backspace && searchField.text === "") {
                        if (launcherRoot.mode !== "apps") {
                            launcherRoot.mode = "apps";
                            event.accepted = true;
                            return;
                        }
                    }

                    if (event.key === Qt.Key_Tab) {
                        if (launcherRoot.mode === "gemini" && geminiLoader.item) {
                            geminiLoader.item.clearContext();
                            searchField.clear();
                            event.accepted = true;
                            return;
                        }
                        if (launcherRoot.mode === "pass" && searchSuggestionText.text !== "") {
                            searchField.text = searchSuggestionText.text;
                            searchField.cursorPosition = searchField.text.length;

                            var query = searchField.text;
                            if (query.startsWith("pass ")) { query = query.substring(5).trim(); }
                            launcherRoot.ctrl.pass.searchQuery = query;

                            event.accepted = true;
                            return;
                        }
                    }

                    if (event.key === Qt.Key_Delete) {
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

                    if (lowerText.startsWith("note ") || lowerText.startsWith("notes ")) {
                        var noteBody = rawText.slice(rawText.indexOf(" ") + 1).trim();
                        if (noteBody !== "") {
                            var notesFile = (launcherRoot.settingsManager && launcherRoot.settingsManager.notesFilePath)
                                ? launcherRoot.settingsManager.notesFilePath
                                : (Quickshell.env("HOME") + "/Documents/notes.txt");
                            Quickshell.execDetached([
                                "sh", "-c",
                                'mkdir -p "$(dirname "$1")"; ts=$(date "+%Y-%m-%d %H:%M"); printf "%s | %s\n" "$ts" "$2" >> "$1"; notify-send -a Notes -i accessories-text-editor "📝 Note Saved" "$2"',
                                "sh", notesFile, noteBody
                            ]);
                            searchField.clear();
                            launcherRoot.closeOverlay();
                            return;
                        }
                    }

                    var currentMode = launcherRoot.mode;
                    if (currentMode === "notes") {
                        if (notesLoader.item) {
                            notesLoader.item.copySelected();
                        }
                        launcherRoot.closeOverlay();
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
                    else if (currentMode === "pass") { ctrl.pass.decryptAndCopySelected(); launcherRoot.closeOverlay(); }
                    else if (currentMode === "apps" && appsLoader.item && appsLoader.item.currentIndex >= 0) {
                        ctrl.appLauncher.launch(ctrl.appLauncher.filteredApps.get(appsLoader.item.currentIndex).exec);
                        launcherRoot.closeOverlay();
                    } else if (currentMode === "startpage" && searchLoader.item) {
                        searchLoader.item.openSearch();
                        launcherRoot.closeOverlay();
                    }
                }
            }

            // LOADERS
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
                            width: 540; height: parent.height; clip: true; cacheBuffer: 1200; spacing: 20
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

                            Image {
                                anchors.fill: parent; anchors.margins: shell.theme.globalPadding
                                visible: (previewPanel.selectedItem && previewPanel.selectedItem.isImage)
                                source: visible ? "file://" + previewPanel.selectedItem.imagePath : ""
                                fillMode: Image.PreserveAspectFit; smooth: false
                            }

                            ScrollView {
                                id: textPreview
                                anchors.fill: parent; anchors.margins: shell.theme.globalPadding
                                visible: (previewPanel.selectedItem && !previewPanel.selectedItem.isImage)
                                clip: true

                                TextArea {
                                    text: ctrl.clipboard.previewText
                                    width: textPreview.availableWidth
                                    wrapMode: Text.WrapAnywhere; readOnly: true; selectByMouse: true
                                    color: shell.theme.base05; font.pixelSize: 20; background: null; textFormat: TextEdit.PlainText; persistentSelection: true; implicitHeight: contentHeight
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

                        // Single Big Result (44px)
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

                        // Full-Height Currency Terminal Grid (3 columns x 4 rows, 138px tall)
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

                                            // Top Header: CODE & SYMBOL
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

                                            // Center Value (Large & Bold)
                                            Text {
                                                text: cCard.cVal
                                                font.bold: true
                                                font.pixelSize: 24
                                                font.family: "JetBrains Mono, monospace"
                                                color: isSelected ? ((shell && shell.theme && shell.theme.base0C) ? shell.theme.base0C : "#04f100") : shell.theme.base05
                                                width: parent.width
                                                elide: Text.ElideRight
                                            }

                                            // Subtitle: Country Name
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
                id: notesLoader
                active: launcherRoot.mode === "notes"
                visible: active
                focus: true
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

            Loader {
                id: passLoader
                active: launcherRoot.mode === "pass"
                visible: active
                focus: true
                width: parent.width
                height: active ? parent.contentHeight : 0
                source: "Pass.qml"
                onLoaded: {
                    if (item) {
                        item.shell = launcherRoot.shell;
                        item.forceActiveFocus();
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