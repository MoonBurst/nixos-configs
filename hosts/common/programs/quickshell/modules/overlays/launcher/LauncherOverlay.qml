// modules/overlays/launcher/LauncherOverlay.qml
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "." as LauncherModule

Rectangle {
    id: launcherRoot

    property var shell
    property var launcherWindow
    property string currentDefinition: ""
    property string mode: "apps"

    readonly property bool isStartPageOpen: mode === "startPage"
    readonly property bool isAppsOpen: mode === "apps"
    readonly property bool isClipboardOpen: mode === "clipboard"
    readonly property bool isEmailOpen: mode === "Email"
    readonly property bool isTodoOpen: mode === "todo"
    readonly property bool isPassOpen: mode === "pass"

    readonly property var ctrl: LauncherModule.LauncherController
    property var activeController: null

    Binding {
        target: launcherRoot
        property: "activeController"
        value: {
            if (launcherRoot.mode === "apps") return launcherRoot.ctrl.appLauncher
                if (launcherRoot.mode === "clipboard") return launcherRoot.ctrl.clipboard
                    if (launcherRoot.mode === "dictionary") return launcherRoot.ctrl.dictionary
                        if (launcherRoot.mode === "math") return launcherRoot.ctrl.math
                            if (launcherRoot.mode === "unicode") return launcherRoot.ctrl.unicodeSearch
                                if (launcherRoot.mode === "search") return launcherRoot.ctrl.startPage
                                    if (launcherRoot.mode === "email") return launcherRoot.ctrl.email
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
        interval: 100
        repeat: false
        property string pendingText: ""
        onTriggered: {
            const trimmed = pendingText
            const currentMode = launcherRoot.mode

            if (trimmed === "") {
                if (currentMode === "clipboard") ctrl.clipboard.refreshFilter("");
                else if (currentMode === "pass") ctrl.pass.searchQuery = "";
                else if (currentMode === "unicode") ctrl.unicodeSearch.refreshFilter("");
                else if (currentMode === "dictionary") ctrl.dictionary.fetch("");
                else if (currentMode === "Email" && ctrl.email && typeof ctrl.email.refreshFilter === "function") ctrl.email.refreshFilter("");
                else if (currentMode === "apps") ctrl.appLauncher.refreshFilter("");
                return;
            }

            if (currentMode === "clipboard") {
                ctrl.clipboard.refreshFilter(trimmed)
                return
            }

            if (currentMode === "pass") {
                var query = trimmed;
                            const pwrTriggers = ["power", "pwr", "session", "sys", "reboot", "restart", "shutdown", "poweroff", "sleep", "suspend", "logout"];
            if (pwrTriggers.includes(trimmed) || trimmed.startsWith("pwr ") || trimmed.startsWith("power ")) {
                launcherRoot.mode = "power";
                return;
            }

            if (trimmed.startsWith("pass ")) {
                    query = trimmed.substring(5).trim();
                }
                ctrl.pass.searchQuery = query;
                return;
            }

            if (currentMode === "dictionary") {
                var query = trimmed;
                if (trimmed.startsWith("def ")) {
                    query = trimmed.substring(4).trim();
                }
                ctrl.dictionary.fetch(query);
                return;
            }

            if (currentMode === "Email") {
                var query = trimmed;
                if (trimmed.startsWith("em ")) {
                    query = trimmed.substring(5).trim();
                }
                if (ctrl.email && typeof ctrl.email.refreshFilter === "function") {
                    ctrl.email.refreshFilter(query);
                }
                return;
            }

            if (trimmed.length > 1 && trimmed.indexOf("?") === 0) {
                launcherRoot.mode = "startpage"
                const cleanQuery = trimmed.substring(1).trim()

                if (launcherRoot.ctrl.startPage) {
                    launcherRoot.ctrl.startPage.updateSearch(cleanQuery)
                }

                if (searchLoader.item) {
                    searchLoader.item.updateSearch(cleanQuery)
                }
                return
            }

            if (trimmed.startsWith(".")) {
                launcherRoot.mode = "unicode"
                const unicodeQuery = trimmed.substring(1).trim()
                launcherRoot.ctrl.unicodeSearch.refreshFilter(unicodeQuery)
                return
            }

            if (trimmed.startsWith("def ")) {
                launcherRoot.mode = "dictionary"
                var query = trimmed.substring(4).trim()
                searchField.text = query
                searchField.cursorPosition = searchField.text.length
                ctrl.dictionary.fetch(query)
                return
            }

            if (trimmed.startsWith("em ")) {
                launcherRoot.mode = "Email"
                var query = trimmed.substring(5).trim()
                searchField.text = query
                searchField.cursorPosition = searchField.text.length
                if (ctrl.email && typeof ctrl.email.refreshFilter === "function") {
                    ctrl.email.refreshFilter(query);
                }
                return
            }

            if (trimmed.startsWith("td ")) {
                launcherRoot.mode = "todo"
                return
            }

                        const pwrTriggers = ["power", "pwr", "session", "sys", "reboot", "restart", "shutdown", "poweroff", "sleep", "suspend", "logout"];
            if (pwrTriggers.includes(trimmed) || trimmed.startsWith("pwr ") || trimmed.startsWith("power ")) {
                launcherRoot.mode = "power";
                return;
            }

            if (trimmed.startsWith("pass ")) {
                launcherRoot.mode = "pass"
                var query = trimmed.substring(5).trim()
                searchField.text = query
                searchField.cursorPosition = searchField.text.length
                ctrl.pass.searchQuery = query
                return
            }

            if (launcherRoot.ctrl.mathEngine.runCalculator(trimmed)) {
                launcherRoot.mode = "math"
                return
            }

            if (trimmed === "rng" || trimmed === "dice" || trimmed === "roll" || trimmed === "coin" || trimmed.startsWith("rng ") || trimmed.startsWith("roll ")) {
                launcherRoot.closeOverlay();
                if (ctrl.rng) ctrl.rng.showWindow();
                return;
            }

            launcherRoot.mode = "apps"
            launcherRoot.ctrl.appLauncher.refreshFilter(trimmed)
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
            } else {
                searchField.forceActiveFocus();
            }
        }
    }

    function toggleLauncher() { toggleOverlayMode("apps"); }
    function toggleClipboard() { toggleOverlayMode("clipboard"); }
    function toggleTodo() { toggleOverlayMode("todo"); }
    function togglePower() { toggleOverlayMode("power"); }
    function togglePass() { toggleOverlayMode("pass"); }
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

    MouseArea { anchors.fill: parent; onClicked: launcherRoot.closeOverlay() }
    Keys.onEscapePressed: launcherRoot.closeOverlay()

    // Centered Main Panel Container
    Rectangle {
        id: mainPanel
        anchors.centerIn: parent
        height: 700
        radius: 16
        color: shell.theme.base01
        border.width: 5
        border.color: shell.theme.base03
        width: launcherRoot.mode === "clipboard" ? 1100 : 820
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
                    if (currentMode === "clipboard") return "Search clipboard history..."
                        if (currentMode === "unicode") return "Search unicode symbols..."
                            if (currentMode === "dictionary") return "Enter word..."
                                if (currentMode === "power") return "Choose power action (Enter to confirm)..."
                                if (currentMode === "pass") return "Search passwords..."
                                    return "Search applications..."
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
                        color: shell.theme.base0B
                        anchors.fill: parent
                        anchors.leftMargin: searchField.leftPadding
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                onTextChanged: {
                    if (launcherRoot.mode === "") return;
                    searchDebounceTimer.pendingText = text
                    searchDebounceTimer.restart()
                }

                Keys.onDownPressed: launcherRoot.navigateActiveList(false)
                Keys.onUpPressed: launcherRoot.navigateActiveList(true)

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Backspace && searchField.text === "") {
                        if (launcherRoot.mode !== "apps") {
                            launcherRoot.mode = "apps";
                            event.accepted = true;
                            return;
                        }
                    }

                    if (event.key === Qt.Key_Tab) {
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

                Keys.onReturnPressed: {
                    const currentMode = launcherRoot.mode
                    if (currentMode === "dictionary") { ctrl.dictionary.copySelected(); launcherRoot.closeOverlay(); }
                    else if (currentMode === "unicode") { ctrl.unicodeSearch.copySelected(); launcherRoot.closeOverlay(); }
                    else if (currentMode === "clipboard") { ctrl.clipboard.copySelected(); launcherRoot.closeOverlay(); }
                    else if (currentMode === "pass") { ctrl.pass.decryptAndCopySelected(); launcherRoot.closeOverlay(); }
                    else if (currentMode === "apps" && appsLoader.item && appsLoader.item.currentIndex >= 0) {
                        ctrl.appLauncher.launch(ctrl.appLauncher.filteredApps.get(appsLoader.item.currentIndex).exec)
                        launcherRoot.closeOverlay();
                    } else if (currentMode === "startpage" && searchLoader.item) {
                        searchLoader.item.openSearch()
                        launcherRoot.closeOverlay();
                    }
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
                height: active ? parent.contentHeight : 0
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
                            width: ListView.view.width
                            height: 90
                            radius: 10
                            color: ListView.isCurrentItem ? shell.theme.base02 : mouseArea.containsMouse ? shell.theme.base01 : "transparent"
                            border.width: ListView.isCurrentItem ? 5 : 0
                            border.color: ListView.isCurrentItem ? shell.theme.base08 : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.margins: shell.theme.globalPadding
                                spacing: 20

                                Image {
                                    width: 32; height: 32
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
                                    spacing: 20

                                    Text { text: name || ""; color: shell.theme.base05; font.pixelSize: 20; font.bold: true }
                                    Text { text: exec || ""; color: shell.theme.base07; font.pixelSize: 20; elide: Text.ElideRight; width: 620 }
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
                        radius: 12; color: shell.theme.base00; border.width: 5; border.color: shell.theme.base03
                        implicitHeight: mathFlow.implicitHeight + 40

                        Flow {
                            id: mathFlow
                            anchors.fill: parent; anchors.margins: shell.theme.globalPadding; spacing: 10

                            Repeater {
                                model: ctrl.mathEngine.mathResultString.split("\n")
                                delegate: Rectangle {
                                    radius: 10; width: (mathFlow.width / 3) - 14; height: 54
                                    color: mouseArea.containsMouse ? shell.theme.base01 : shell.theme.base02
                                    border.width: 2; border.color: shell.theme.base05

                                    Text {
                                        anchors.centerIn: parent; width: parent.width - 20; text: modelData
                                        color: shell.theme.base05; font.pixelSize: 22; font.bold: true; font.family: "JetBrains Mono"
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; wrapMode: Text.NoWrap; elide: Text.ElideRight
                                    }
                                    MouseArea { id: mouseArea; anchors.fill: parent; hoverEnabled: true }
                                }
                            }
                        }
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
