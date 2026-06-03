        import QtQuick
        import QtQuick.Controls
        import Quickshell
        import Quickshell.Io
        import "."
        as LauncherModule

        Rectangle {
            id: launcherRoot

            // Core Window and Theme Context References
            property
            var shell
            property
            var launcherWindow
            property string currentDefinition: ""
            property string mode: "apps"

            // Search mode detection
            readonly property bool isStartPageOpen: mode === "startPage"

            // Performance Cache: Read-Only Evaluators
            readonly property bool isAppsOpen: mode === "apps"
            readonly property bool isClipboardOpen: mode === "clipboard"
            readonly property bool isEmailOpen: mode === "Email"
            readonly property bool isPlaceholder2Open: mode === "placeholder2"
            readonly property bool isPlaceholder3Open: mode === "placeholder3"

            // Global Controller Alias to eliminate deep JavaScript scope resolution costs
            readonly property
            var ctrl: LauncherModule.LauncherController

            // Centralized active controller tracking
            property
            var activeController: null

            // Native C++ level compilation binding pathways
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
                                                if (launcherRoot.mode === "placeholder2") return launcherRoot.ctrl.placeholder2
                                                    if (launcherRoot.mode === "placeholder3") return launcherRoot.ctrl.placeholder3
                                            return null
                }
            }

            anchors.fill: parent
            color: mode !== "" ? "#00000088" : "transparent"
            visible: true
            focus: true

            /*
             * KEYSTROKE DEBOUNCER
             */
            Timer {
                id: searchDebounceTimer
                interval: 100
                repeat: false
                property string pendingText: ""
                onTriggered: {
                    const trimmed = pendingText
                    const currentMode = launcherRoot.mode

                    if (currentMode === "clipboard") {
                        launcherRoot.ctrl.clipboard.refreshFilter(trimmed)
                        return
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

                    if (trimmed.length > 4 && trimmed.indexOf("def ") === 0) {
                        launcherRoot.mode = "dictionary"
                        launcherRoot.ctrl.dictionary.fetch(trimmed.substring(4).trim())
                        return
                    }

                    if (trimmed.startsWith("em ")) {
                        launcherRoot.mode = "Email"

                        const p1Query = trimmed.substring(5).trim()

                        if (launcherRoot.ctrl.email &&
                            typeof launcherRoot.ctrl.email.refreshFilter === "function")
                        {
                            launcherRoot.ctrl.email.refreshFilter(p1Query)
                        }

                        return
                    }

                    if (trimmed.startsWith("placeholder2activatetext")) {
                        launcherRoot.mode = "placeholder2"
                        const p2Query = trimmed.substring(2).trim()
                        if (launcherRoot.ctrl.placeholder2 && typeof launcherRoot.ctrl.placeholder2.refreshFilter === "function") {
                            launcherRoot.ctrl.placeholder2.refreshFilter(p2Query)
                        }
                        return
                    }

                    if (trimmed.startsWith("placeholder3activatetext")) {
                        launcherRoot.mode = "placeholder3"
                        const p3Query = trimmed.substring(2).trim()
                        if (launcherRoot.ctrl.placeholder3 && typeof launcherRoot.ctrl.placeholder3.refreshFilter === "function") {
                            launcherRoot.ctrl.placeholder3.refreshFilter(p3Query)
                        }
                        return
                    }


                    if (launcherRoot.ctrl.mathEngine.runCalculator(trimmed)) {
                        launcherRoot.mode = "math"
                        return
                    }

                    launcherRoot.mode = "apps"
                    launcherRoot.ctrl.appLauncher.refreshFilter(trimmed)
                }
            }



            /*
             * WINDOW STATE CONTROL ACTIONS (MODULATED FOR COMPOSITOR DRIVEN FOCUS GRABS)
             */

            Component.onCompleted: {
                appsLoader.active = true
            }

            function closeOverlay() {
                launcherRoot.mode = ""
                launcherWindow.visible = false
            }

//LAUNCHER
            function openLauncher() {
                launcherRoot.mode = "apps"
                searchField.clear()
                ctrl.appLauncher.refreshFilter("")
                launcherWindow.visible = true
                searchField.forceActiveFocus()
            }

            function toggleLauncher() {
                if (launcherRoot.mode === "apps" && launcherWindow.visible) launcherRoot.closeOverlay()
                    else launcherRoot.openLauncher()
            }
//Clipboard
            function openClipboard() {
                launcherRoot.mode = "clipboard"
                searchField.clear()
                ctrl.clipboard.refreshFilter("")
                launcherWindow.visible = true
                searchField.forceActiveFocus()
            }

            function toggleClipboard() {
                if (launcherRoot.mode === "clipboard" && launcherWindow.visible) launcherRoot.closeOverlay()
                    else launcherRoot.openClipboard()
            }

//Dictionary
            function openDictionary(word) {
                launcherRoot.mode = "dictionary"
                searchField.text = word || ""
                ctrl.dictionary.fetch(searchField.text)
                launcherWindow.visible = true
                searchField.forceActiveFocus()
            }

//Placeholders
            function toggleEmail() {
                if (launcherRoot.mode === "Email" && launcherWindow.visible) {
                    launcherRoot.closeOverlay()
                } else {
                    launcherRoot.openEmail()
                }
            }

            function togglePlaceholder2() {
                if (launcherRoot.mode === "placeholder2" && launcherWindow.visible) {
                    launcherRoot.closeOverlay()
                } else {
                    launcherRoot.openPlaceholder2()
                }
            }

            function togglePlaceholder3() {
                if (launcherRoot.mode === "placeholder3" && launcherWindow.visible) {
                    launcherRoot.closeOverlay()
                } else {
                    launcherRoot.openPlaceholder3()
                }
            }


            /*
             * IPC CHANNELS
             */

            IpcHandler {
                target: "launcher"
                function open() {
                    launcherRoot.openLauncher()
                }

                function close() {
                    launcherRoot.closeOverlay()
                }

                function toggle() {
                    launcherRoot.toggleLauncher()
                }
            }

            IpcHandler {
                target: "clipboard"
                function open() {
                    launcherRoot.openClipboard()
                }

                function close() {
                    launcherRoot.closeOverlay()
                }

                function toggle() {
                    launcherRoot.toggleClipboard()
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: launcherRoot.closeOverlay()
            }

            Keys.onEscapePressed: {
                launcherRoot.closeOverlay()
            }

            /*
             * MAIN CONTAINER PANEL
             */
            Rectangle {
                id: mainPanel
                height: 700
                anchors.centerIn: parent
                radius: 16
                color: shell.theme.base01
                border.width: 5
                border.color: shell.theme.base03

                width: launcherRoot.mode === "clipboard" ? 1100 : 820

                Column {
                    anchors.fill: parent
                    anchors.margins: shell.theme.globalPadding
                    spacing: 20

                    readonly property real contentHeight: height - searchField.height - spacing

                    /*
                     * CENTRALIZED SEARCH FIELD ENGINE
                     */

                    TextField {
                        id: searchField

                        width: parent.width
                        leftPadding: 20
                        height: 52

                        focus: true

                        color: shell.theme.base05
                        font.pixelSize: 30

                        placeholderTextColor: shell.theme.base05

                        placeholderText: {
                            const currentMode = launcherRoot.mode

                            if (currentMode === "clipboard")
                                return "Search clipboard history..."

                                if (currentMode === "unicode")
                                    return "Search unicode symbols..."

                                    if (currentMode === "dictionary")
                                        return "Enter word..."

                                        return "Search applications..."
                        }

                        background: Rectangle {
                            radius: 10
                            color: "transparent"

                            border.width: 5
                            border.color: shell.theme.base05
                        }

                        onTextChanged: {
                            if (launcherRoot.mode === "")
                                return

                                searchDebounceTimer.pendingText = text
                                searchDebounceTimer.restart()
                        }

                        Keys.onDownPressed: {
                            const currentMode = launcherRoot.mode
                            if (currentMode === "dictionary" && dictionaryLoader.item) {

                                launcherRoot.ctrl.dictionary.selectNext()

                                dictionaryLoader.item.currentIndex =
                                launcherRoot.ctrl.dictionary.selectedIndex

                                dictionaryLoader.item.positionViewAtIndex(
                                    dictionaryLoader.item.currentIndex,
                                    ListView.Contain
                                )
                                return
                            }
                            if (currentMode === "unicode" && unicodeLoader.item) {
                                launcherRoot.ctrl.unicodeSearch.moveDown()

                                unicodeLoader.item.currentIndex =
                                launcherRoot.ctrl.unicodeSearch.selectedIndex

                                unicodeLoader.item.positionViewAtIndex(
                                    unicodeLoader.item.currentIndex,
                                    ListView.Contain
                                )

                                return
                            }

                            if (
                                currentMode === "clipboard" &&
                                clipboardLoader.item &&
                                clipboardLoader.listViewInstance
                            ) {
                                launcherRoot.ctrl.clipboard.moveDown()

                                clipboardLoader.listViewInstance.positionViewAtIndex(
                                    launcherRoot.ctrl.clipboard.selectedIndex,
                                    ListView.Contain
                                )

                                return
                            }

                            if (
                                currentMode === "apps" &&
                                appsLoader.item &&
                                appsLoader.item.currentIndex <
                                launcherRoot.ctrl.appLauncher.filteredApps.count - 1
                            ) {
                                appsLoader.item.currentIndex++
                            }
                        }

                        Keys.onUpPressed: {
                            const currentMode = launcherRoot.mode

                            // 1. DICTIONARY MODE HANDLER (UP)
                            if (currentMode === "dictionary" && dictionaryLoader.item) {
                                launcherRoot.ctrl.dictionary.selectPrev()

                                // Sync the UI view item's index with the engine's tracking pointer
                                dictionaryLoader.item.currentIndex =
                                launcherRoot.ctrl.dictionary.selectedIndex

                                // Snap the layout container viewport to stay centered on the item
                                dictionaryLoader.item.positionViewAtIndex(
                                    dictionaryLoader.item.currentIndex,
                                    ListView.Contain
                                )
                                return
                            }

                            // 2. UNICODE MODE HANDLER
                            if (currentMode === "unicode" && unicodeLoader.item) {
                                launcherRoot.ctrl.unicodeSearch.moveUp()

                                unicodeLoader.item.currentIndex =
                                launcherRoot.ctrl.unicodeSearch.selectedIndex

                                unicodeLoader.item.positionViewAtIndex(
                                    unicodeLoader.item.currentIndex,
                                    ListView.Contain
                                )

                                return
                            }

                            // 3. CLIPBOARD MODE HANDLER
                            if (
                                currentMode === "clipboard" &&
                                clipboardLoader.item &&
                                clipboardLoader.listViewInstance
                            ) {
                                launcherRoot.ctrl.clipboard.moveUp()

                                clipboardLoader.listViewInstance.positionViewAtIndex(
                                    launcherRoot.ctrl.clipboard.selectedIndex,
                                    ListView.Contain
                                )

                                return
                            }

                            // 4. APPS MODE HANDLER
                            if (
                                currentMode === "apps" &&
                                appsLoader.item &&
                                appsLoader.item.currentIndex > 0
                            ) {
                                appsLoader.item.currentIndex--
                            }
                        }




                        Keys.onDeletePressed: {
                            if (launcherRoot.mode !== "clipboard")
                                return

                                launcherRoot.ctrl.clipboard.deleteSelected()
                        }

                        Keys.onReturnPressed: {
                            const currentMode = launcherRoot.mode

                            // 1. DICTIONARY MODE HANDLER (RETURN)
                            if (currentMode === "dictionary") {
                                launcherRoot.ctrl.dictionary.copySelected()
                                launcherRoot.closeOverlay()
                                return
                            }

                            // 2. UNICODE MODE HANDLER
                            if (currentMode === "unicode") {
                                launcherRoot.ctrl.unicodeSearch.copySelected()
                                launcherRoot.closeOverlay()
                                return
                            }

                            // 3. CLIPBOARD MODE HANDLER
                            if (currentMode === "clipboard") {
                                launcherRoot.ctrl.clipboard.copySelected()
                                launcherRoot.closeOverlay()
                                return
                            }

                            // 4. APPS MODE HANDLER
                            if (
                                currentMode === "apps" &&
                                appsLoader.item &&
                                appsLoader.item.currentIndex >= 0
                            ) {
                                launcherRoot.ctrl.appLauncher.launch(
                                    launcherRoot.ctrl.appLauncher
                                    .filteredApps
                                    .get(appsLoader.item.currentIndex).exec
                                )

                                launcherRoot.closeOverlay()
                                return
                            }

                            // 5. STARTPAGE MODE HANDLER
                            if (currentMode === "startpage" && searchLoader.item) {
                                searchLoader.item.openSearch()
                                launcherRoot.closeOverlay()
                                return
                            }
                        }


                    }
                    /*
                     * STARTPAGE LOADER
                     */

                    Loader {
                        id: searchLoader

                        active: launcherRoot.mode === "startpage"
                        visible: active

                        width: parent.width
                        height: parent.contentHeight
                        source: "StartPage.qml"

                        onLoaded: {
                            if (item && launcherRoot.ctrl.startPage) {
                                item.updateSearch(searchDebounceTimer.pendingText.substring(1).trim())
                            }
                        }
                    }



                    /*
                     * UNICODE LOADER
                     */
                    Loader {
                        id: unicodeLoader
                        active: launcherRoot.mode === "unicode"
                        visible: active
                        width: parent.width
                        height: parent.height

                        sourceComponent: ListView {
                            id: unicodeListView
                            clip: true
                            cacheBuffer: 800
                            spacing: 20

                            focus: true

                            model: launcherRoot.ctrl.unicodeSearch.filteredUnicodeItems
                            currentIndex: launcherRoot.ctrl.unicodeSearch.selectedIndex

                            onCurrentIndexChanged: {
                                launcherRoot.ctrl.unicodeSearch.selectedIndex = currentIndex
                            }

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
                                        // Visual alignment fix for larger emojis/symbols
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
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        launcherRoot.ctrl.unicodeSearch.selectedIndex = index
                                        unicodeListView.currentIndex = index
                                        launcherRoot.ctrl.unicodeSearch.copySelected()
                                        launcherRoot.closeOverlay()
                                    }
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }
                        }
                    }

                    /*
                     * PROGRAM LAUNCHER LOADER
                     */
                    Loader {
                        id: appsLoader
                        active: true
                        visible: launcherRoot.mode === "apps" || launcherRoot.mode === ""
                        width: parent.width
                        height: parent.contentHeight
                        sourceComponent: Component {
                            ListView {
                                clip: true
                                cacheBuffer: 800
                                spacing: 20
                                model: launcherRoot.ctrl.appLauncher.filteredApps

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
                                            width: 32
                                            height: 32
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: icon ? "image://icon/" + icon : ""
                                            fillMode: Image.PreserveAspectFit
                                            smooth: false
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 20

                                            Text {
                                                text: name || ""
                                                color: shell.theme.base05
                                                font.pixelSize: 20
                                                font.bold: true
                                            }

                                            Text {
                                                text: exec || ""
                                                color: shell.theme.base07
                                                font.pixelSize: 20
                                                elide: Text.ElideRight
                                                width: 620
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: mouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            launcherRoot.ctrl.appLauncher.launch(exec)
                                            launcherRoot.closeOverlay()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    /*
                     * STARTPAGE LOADER
                     */
                    Loader {
                        id: startPageLoader
                        active: launcherRoot.mode === "startPage"
                        visible: active
                        width: parent.width
                        height: parent.contentHeight
                        source: "StartPage.qml"
                    }
                    /*
                     * CLIPBOARD LOADER
                     */
                    Loader {
                        id: clipboardLoader
                        active: launcherRoot.mode === "clipboard"
                        visible: active
                        width: parent.width
                        height: parent.contentHeight

                        readonly property
                        var listViewInstance: item ? item.targetListView : null

                        sourceComponent: Component {
                            Row {
                                width: parent.width
                                height: parent.height
                                spacing: 20

                                property Item targetListView: clipboardListView

                                ListView {
                                    id: clipboardListView
                                    width: 540
                                    height: parent.height
                                    clip: true
                                    cacheBuffer: 1200
                                    spacing: 20
                                    model: launcherRoot.ctrl.clipboard.filteredClipboardItems
                                    currentIndex: ctrl.clipboard.selectedIndex

                                    delegate: Rectangle {
                                        readonly property int itemIndex: index
                                        readonly property string itemText: model.text || ""
                                        readonly property bool itemIsImage: model.isImage || false
                                        readonly property string itemImagePath: model.imagePath || ""

                                        width: clipboardListView.width
                                        height: itemIsImage ? 120 : 70
                                        radius: 10
                                        color: itemIndex === launcherRoot.ctrl.clipboard.selectedIndex ? shell.theme.base02 : "transparent"
                                        border.width: ListView.isCurrentItem ? 5 : 0
                                        border.color: ListView.isCurrentItem ? shell.theme.base08 : "transparent"

                                        Item {
                                            anchors.fill: parent
                                            anchors.margins: shell.theme.globalPadding

                                            Image {
                                                id: listEntryImageComponent
                                                visible: itemIsImage
                                                width: 100
                                                height: 100
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

                                                text: itemIsImage ? "[Image Clipboard Entry]" : itemText
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
                                                ctrl.clipboard.selectedIndex = itemIndex
                                                ctrl.clipboard.updatePreview()
                                            }
                                        }
                                    }
                                    ScrollBar.vertical: ScrollBar {
                                        policy: ScrollBar.AsNeeded
                                    }
                                }

                                Rectangle {
                                    id: previewPanel

                                    width: 500
                                    height: parent.height

                                    radius: 12
                                    color: shell.theme.base00

                                    border.width: 5
                                    border.color: shell.theme.base03

                                    property
                                    var selectedItem: (
                                        launcherRoot.ctrl.clipboard.selectedIndex >= 0 &&
                                        launcherRoot.ctrl.clipboard.selectedIndex <
                                        launcherRoot.ctrl.clipboard.filteredClipboardItems.count
                                    ) ?
                                    launcherRoot.ctrl.clipboard.filteredClipboardItems.get(
                                        launcherRoot.ctrl.clipboard.selectedIndex
                                    ) : null

                                    /*
                                     * IMAGE PREVIEW
                                     */

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: shell.theme.globalPadding

                                        visible: (
                                            previewPanel.selectedItem &&
                                            previewPanel.selectedItem.isImage
                                        )

                                        source: visible ?
                                        "file://" + previewPanel.selectedItem.imagePath :
                                        ""

                                        fillMode: Image.PreserveAspectFit
                                        smooth: false
                                    }

                                    /*
                                     * TEXT PREVIEW
                                     */

                                    ScrollView {
                                        id: textPreview

                                        anchors.fill: parent
                                        anchors.margins: shell.theme.globalPadding

                                        visible: (
                                            previewPanel.selectedItem &&
                                            !previewPanel.selectedItem.isImage
                                        )

                                        clip: true

                                        TextArea {
                                            id: previewTextArea

                                            text: launcherRoot.ctrl.clipboard.previewText

                                            width: textPreview.availableWidth

                                            wrapMode: Text.WrapAnywhere

                                            readOnly: true
                                            selectByMouse: true

                                            color: shell.theme.base05
                                            font.pixelSize: 20

                                            background: null

                                            textFormat: TextEdit.PlainText
                                            persistentSelection: true

                                            implicitHeight: contentHeight
                                        }
                                    }
                                }
                            }
                        }
                    }


                    /*
                     * DICATIONARY LOADER
                     */
                    Loader {
                        id: dictionaryLoader

                        active: launcherRoot.mode === "dictionary"
                        visible: active

                        width: parent.width
                        height: parent.contentHeight

                        sourceComponent: Component {
                            ListView {
                                id: dictionaryListView

                                width: parent.width
                                height: parent.height

                                clip: true
                                spacing: 20

                                interactive: true

                                model: launcherRoot.ctrl.dictionary.definitionEntries

                                currentIndex: launcherRoot.ctrl.dictionary.selectedIndex

                                delegate: Rectangle {
                                    width: dictionaryListView.width
                                    height: definitionText.implicitHeight + 40

                                    radius: 10

                                    color: ListView.isCurrentItem ?
                                    shell.theme.base02 : "transparent"

                                    border.width: ListView.isCurrentItem ? 5 : 0

                                    border.color: ListView.isCurrentItem ?
                                    shell.theme.base08 : "transparent"

                                    Text {
                                        id: definitionText

                                        anchors.fill: parent
                                        anchors.margins: shell.theme.globalPadding

                                        text: modelData.text

                                        wrapMode: Text.Wrap

                                        color: shell.theme.base05

                                        font.pixelSize: 22
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            launcherRoot.ctrl.dictionary.selectedIndex = index
                                        }
                                    }
                                }

                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }
                            }
                        }
                    }


                    /*
                     * MATH LOADER
                     */
                    Loader {
                        active: launcherRoot.mode === "math"
                        visible: active
                        width: parent.width
                        height: parent.contentHeight
                        sourceComponent: Component {
                            Rectangle {
                                radius: 12
                                color: shell.theme.base00
                                border.width: 5
                                border.color: shell.theme.base03

                                implicitHeight: mathFlow.implicitHeight + 40

                                Flow {
                                    id: mathFlow

                                    anchors.fill: parent
                                    anchors.margins: shell.theme.globalPadding

                                    spacing: 10

                                    Repeater {
                                        model: launcherRoot.ctrl.mathEngine.mathResultString.split("\n")

                                        delegate: Rectangle {

                                            radius: 10

                                            width: (mathFlow.width / 3) - 14
                                            height: 54

                                            color: mouseArea.containsMouse
                                            ? shell.theme.base01
                                            : shell.theme.base02

                                            border.width: 2
                                            border.color: shell.theme.base05

                                            Text {
                                                id: bubbleText

                                                anchors.centerIn: parent

                                                width: parent.width - 20

                                                text: modelData

                                                color: shell.theme.base05

                                                font.pixelSize: 22
                                                font.bold: true
                                                font.family: "JetBrains Mono"

                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter

                                                wrapMode: Text.NoWrap
                                                elide: Text.ElideRight
                                            }

                                            MouseArea {
                                                id: mouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }



                    /*
                     * CLEANED EMAIL APPS DASHBOARD LOADER GATEWAY
                     */
                    Loader {
                        id: emailLoader
                        active: launcherRoot.mode.toLowerCase() === "email"
                        visible: active

                        // Maintain your clean system scaling proportions
                        width: parent.width
                        height: parent.contentHeight

                        // Seamlessly load your dedicated external workspace script file
                        source: "Email.qml"

                        // Automatically hooks keyboard focus straight down onto your script on load
                        onLoaded: {
                            if (item) {
                                item.forceActiveFocus()
                            }
                        }
                    }

                    /*
                     * PLACEHOLDER 2 LOADER
                     */
                    Loader {
                        id: placeholder2Loader
                        active: launcherRoot.mode === "placeholder2"
                        visible: active
                        width: parent.width
                        height: parent.contentHeight
                        source: "Placeholder2.qml"
                    }

                    /*
                     * PLACEHOLDER 3 LOADER
                     */
                    Loader {
                        id: placeholder3Loader
                        active: launcherRoot.mode === "placeholder3"
                        visible: active
                        width: parent.width
                        height: parent.contentHeight
                        source: "Placeholder3.qml"
                    }

                }
            }
        }
