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

            // Performance Cache: Read-Only Evaluators
            readonly property bool isAppsOpen: mode === "apps"
            readonly property bool isClipboardOpen: mode === "clipboard"

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
                    return null
                }
            }

            anchors.fill: parent
            color: mode !== "" ? "#00000088" : "transparent"
            visible: true
            focus: true

            /*
             * PEAK-PERFORMANCE KEYSTROKE DEBOUNCER
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

                    if (trimmed === ".") {
                        launcherRoot.mode = "unicode"
                        launcherRoot.ctrl.unicodeSearch.refreshFilter(trimmed.substring(1).trim())
                        return
                    }

                    if (trimmed.length > 4 && trimmed.indexOf("def ") === 0) {
                        launcherRoot.mode = "dictionary"
                        launcherRoot.ctrl.dictionary.fetch(trimmed.substring(4).trim())
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
            function openLauncher() {
                launcherRoot.mode = "apps"
                searchField.clear()
                ctrl.appLauncher.refreshFilter("")
                launcherWindow.visible = true
                searchField.forceActiveFocus()
            }

            Component.onCompleted: {
                appsLoader.active = true
            }

            function openClipboard() {
                launcherRoot.mode = "clipboard"
                searchField.clear()
                ctrl.clipboard.refreshFilter("")
                launcherWindow.visible = true
                searchField.forceActiveFocus()
            }

            function openDictionary(word) {
                launcherRoot.mode = "dictionary"
                searchField.text = word || ""
                ctrl.dictionary.fetch(searchField.text)
                launcherWindow.visible = true
                searchField.forceActiveFocus()
            }

            function closeOverlay() {
                launcherRoot.mode = ""
                launcherWindow.visible = false
            }

            function toggleLauncher() {
                if (launcherRoot.mode === "apps" && launcherWindow.visible) launcherRoot.closeOverlay()
                else launcherRoot.openLauncher()
            }

            function toggleClipboard() {
                if (launcherRoot.mode === "clipboard" && launcherWindow.visible) launcherRoot.closeOverlay()
                else launcherRoot.openClipboard()
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

                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    readonly property real contentHeight: height - searchField.height - spacing

                    /*
                     * CENTRALIZED SEARCH FIELD ENGINE (ZERO-LAG DEBOUNCED)
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
                            if (currentMode === "clipboard") return "Search clipboard history..."
                            if (currentMode === "unicode") return "Search unicode symbols..."
                            if (currentMode === "dictionary") return "Enter word..."
                            return "Search applications..."
                        }

                        background: Rectangle {
                            radius: 10
                            color: "transparent"
                            border.width: 5
                            border.color: shell.theme.base05
                        }

                        onTextChanged: {
                            if (launcherRoot.mode === "") return

                            searchDebounceTimer.pendingText = text
                            searchDebounceTimer.restart()
                        }

                        Keys.onDownPressed: {
                            const currentMode = launcherRoot.mode
                            if (currentMode === "unicode" && unicodeLoader.item) {
                                launcherRoot.ctrl.unicodeSearch.moveDown()
                                unicodeLoader.item.currentIndex = launcherRoot.ctrl.unicodeSearch.selectedIndex
                                unicodeLoader.item.positionViewAtIndex(unicodeLoader.item.currentIndex, ListView.Contain)
                                return
                            }

                            if (currentMode === "clipboard" && clipboardLoader.item && clipboardLoader.listViewInstance) {
                                launcherRoot.ctrl.clipboard.moveDown()
                                clipboardLoader.listViewInstance.positionViewAtIndex(launcherRoot.ctrl.clipboard.selectedIndex, ListView.Contain)
                                return
                            }

                            if (currentMode === "apps" && appsLoader.item && appsLoader.item.currentIndex < launcherRoot.ctrl.appLauncher.filteredApps.count - 1) {
                                appsLoader.item.currentIndex++
                            }
                        }

                        Keys.onUpPressed: {
                            const currentMode = launcherRoot.mode
                            if (currentMode === "unicode" && unicodeLoader.item) {
                                launcherRoot.ctrl.unicodeSearch.moveUp()
                                unicodeLoader.item.currentIndex = launcherRoot.ctrl.unicodeSearch.selectedIndex
                                unicodeLoader.item.positionViewAtIndex(unicodeLoader.item.currentIndex, ListView.Contain)
                                return
                            }

                            if (currentMode === "clipboard" && clipboardLoader.item && clipboardLoader.listViewInstance) {
                                launcherRoot.ctrl.clipboard.moveUp()
                                clipboardLoader.listViewInstance.positionViewAtIndex(launcherRoot.ctrl.clipboard.selectedIndex, ListView.Contain)
                                return
                            }

                            if (currentMode === "apps" && appsLoader.item && appsLoader.item.currentIndex > 0) {
                                appsLoader.item.currentIndex--
                            }
                        }

                        Keys.onDeletePressed: {
                            if (launcherRoot.mode !== "clipboard") return
                            launcherRoot.ctrl.clipboard.deleteSelected()
                        }

                        Keys.onReturnPressed: {
                            const currentMode = launcherRoot.mode
                            if (currentMode === "unicode") {
                                launcherRoot.ctrl.unicodeSearch.copySelected()
                                launcherRoot.closeOverlay()
                                return
                            }

                            if (currentMode === "clipboard") {
                                launcherRoot.ctrl.clipboard.copySelected()
                                launcherRoot.closeOverlay()
                                return
                            }

                            if (currentMode === "apps" && appsLoader.item && appsLoader.item.currentIndex >= 0) {
                                launcherRoot.ctrl.appLauncher.launch(launcherRoot.ctrl.appLauncher.filteredApps.get(appsLoader.item.currentIndex).exec)
                                launcherRoot.closeOverlay()
                            }
                        }
                    }

                    /*
                     * HIGH-PERFORMANCE PRE-CACHED LAZYLOADERS
                     */
                    Loader {
                        id: unicodeLoader
                        active: launcherRoot.mode === "unicode"
                        visible: active
                        width: parent.width
                        height: parent.contentHeight
                        sourceComponent: Component {
                            ListView {
                                id: unicodeListView
                                clip: true
                                cacheBuffer: 800
                                spacing: 20
                                boundsBehavior: Flickable.StopAtBounds
                                model: launcherRoot.ctrl.unicodeSearch.filteredUnicodeItems
                                currentIndex: launcherRoot.ctrl.unicodeSearch.selectedIndex

                                delegate: Rectangle {
                                    width: unicodeListView.width
                                    height: 60
                                    radius: 10
                                    color: ListView.isCurrentItem ? shell.theme.base02 : "transparent"

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 20
                                        spacing: 20
                                        Text {
                                            text: modelData.symbol
                                            color: shell.theme.base05
                                            font.pixelSize: 50
                                            width: 50
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
                    }

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
                                        anchors.margins: 20
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
                                    boundsBehavior: Flickable.StopAtBounds
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

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 20

                                            Image {
                                                visible: itemIsImage
                                                width: 100
                                                height: 100
                                                source: itemIsImage && itemImagePath ? "file://" + itemImagePath : ""
                                                fillMode: Image.PreserveAspectFit
                                                smooth: false
                                            }

                                            Text {

                                                anchors.left: itemIsImage ? parent.left : parent.left
                                                anchors.leftMargin: itemIsImage ? 120 : 0 // 100px image width + 20px layout spacing
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
                                        anchors.margins: 20

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
                                        anchors.margins: 20

                                        visible: (
                                            previewPanel.selectedItem &&
                                            !previewPanel.selectedItem.isImage
                                        )

                                        clip: true

                                        TextArea {
                                            text: (
                                                previewPanel.selectedItem ?
                                                previewPanel.selectedItem.text :
                                                ""
                                            )

                                            width: textPreview.availableWidth
                                            wrapMode: TextArea.WrapAnywhere
                                            readOnly: true
                                            selectByMouse: true
                                            color: shell.theme.base05
                                            font.pixelSize: 20
                                            background: null
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Loader {
                        active: launcherRoot.mode === "dictionary"
                        visible: active
                        width: parent.width
                        height: parent.contentHeight
                        sourceComponent: Component {
                            ScrollView {
                                clip: true
                                Text {
                                    width: parent.width - 20
                                    text: launcherRoot.ctrl.dictionary.currentDefinition
                                    wrapMode: Text.Wrap
                                    color: shell.theme.base05
                                    font.pixelSize: 20
                                    lineHeight: 1.3
                                }
                            }
                        }
                    }

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

                                Text {
                                    anchors.centerIn: parent
                                    text: launcherRoot.ctrl.mathEngine.mathResultString
                                    color: shell.theme.base05
                                    font.pixelSize: 50
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
