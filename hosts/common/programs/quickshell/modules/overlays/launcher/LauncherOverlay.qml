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

    property bool appMode: true
    property bool clipboardMode: false
    property bool dictionaryMode: false
    property bool mathMode: false

    anchors.fill: parent

    color: "#00000088"

    visible: launcherWindow.visible
    enabled: visible
    focus: visible

    /*
     * WINDOW CONTROL
     */

    function openLauncher() {

        launcherWindow.visible = true

        appMode = true
        clipboardMode = false
        dictionaryMode = false
        mathMode = false

        searchField.text = ""

        LauncherModule
        .LauncherController
        .appLauncher
        .refreshFilter("")

        searchField.forceActiveFocus()
    }

    function openClipboard() {

        launcherWindow.visible = true

        appMode = false
        clipboardMode = true
        dictionaryMode = false
        mathMode = false

        searchField.text = ""

        LauncherModule
        .LauncherController
        .clipboard
        .refreshFilter("")

        searchField.forceActiveFocus()
    }

    function openDictionary(word) {

        launcherWindow.visible = true

        appMode = false
        clipboardMode = false
        dictionaryMode = true
        mathMode = false

        searchField.text = word || ""

        LauncherModule
        .LauncherController
        .dictionary
        .fetch(searchField.text)

        searchField.forceActiveFocus()
    }

    function closeOverlay() {

        launcherWindow.visible = false

        searchField.text = ""

        currentDefinition = ""

        appMode = false
        clipboardMode = false
        dictionaryMode = false
        mathMode = false
    }

    function toggleLauncher() {

        if (
            launcherWindow.visible &&
            appMode
        ) {
            closeOverlay()
        } else {
            openLauncher()
        }
    }

    function toggleClipboard() {

        if (
            launcherWindow.visible &&
            clipboardMode
        ) {
            closeOverlay()
        } else {
            openClipboard()
        }
    }

    /*
     * IPC
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

    /*
     * BACKDROP
     */

    MouseArea {
        anchors.fill: parent

        onClicked: launcherRoot.closeOverlay()
    }

    Keys.onEscapePressed: {
        launcherRoot.closeOverlay()
    }

    /*
     * MAIN PANEL
     */

    Rectangle {

        width:
        clipboardMode
        ? 1100
        : 820

        height: 700

        anchors.centerIn: parent

        radius: 16

        color: shell.theme.base01

        border.width: 2
        border.color: shell.theme.base03

        MouseArea {
            anchors.fill: parent
        }

        Column {

            anchors.fill: parent
            anchors.margins: 20

            spacing: 14

            /*
             * SEARCH FIELD
             */

            TextField {
                id: searchField

                width: parent.width
                height: 52

                color: shell.theme.base05

                font.pixelSize: 20

                placeholderText:
                clipboardMode
                ? "Search clipboard history..."
                : dictionaryMode
                ? "Enter word..."
                : "Search applications..."

                background: Rectangle {

                    radius: 10

                    color: "transparent"

                    border.width: 2
                    border.color: shell.theme.base03
                }

                onTextChanged: {

                    const trimmed =
                    (text || "").trim()

                    /*
                     * CLIPBOARD
                     */

                    if (clipboardMode) {

                        LauncherModule
                        .LauncherController
                        .clipboard
                        .refreshFilter(trimmed)

                        return
                    }

                    /*
                     * DICTIONARY
                     */

                    if (
                        trimmed.startsWith("def ")
                    ) {

                        appMode = false
                        clipboardMode = false
                        dictionaryMode = true
                        mathMode = false

                        const word =
                        trimmed.substring(4).trim()

                        LauncherModule
                        .LauncherController
                        .dictionary
                        .fetch(word)

                        return
                    }

                    /*
                     * MATH
                     */

                    const mathWorked =
                    LauncherModule
                    .LauncherController
                    .mathEngine
                    .runCalculator(trimmed)

                    if (mathWorked) {

                        appMode = false
                        clipboardMode = false
                        dictionaryMode = false
                        mathMode = true

                        return
                    }

                    /*
                     * APPS
                     */

                    appMode = true
                    clipboardMode = false
                    dictionaryMode = false
                    mathMode = false

                    LauncherModule
                    .LauncherController
                    .appLauncher
                    .refreshFilter(trimmed)
                }

                Keys.onDownPressed: {

                    if (clipboardMode) {

                        LauncherModule
                        .LauncherController
                        .clipboard
                        .moveDown()

                        clipboardListView.positionViewAtIndex(
                            LauncherModule
                            .LauncherController
                            .clipboard
                            .selectedIndex,
                            ListView.Contain
                        )

                        return
                    }

                    if (
                        listView.currentIndex <
                        LauncherModule
                        .LauncherController
                        .appLauncher
                        .filteredApps.count - 1
                    ) {
                        listView.currentIndex++
                    }
                }

                Keys.onUpPressed: {

                    if (clipboardMode) {

                        LauncherModule
                        .LauncherController
                        .clipboard
                        .moveUp()

                        clipboardListView.positionViewAtIndex(
                            LauncherModule
                            .LauncherController
                            .clipboard
                            .selectedIndex,
                            ListView.Contain
                        )

                        return
                    }

                    if (
                        listView.currentIndex > 0
                    ) {
                        listView.currentIndex--
                    }
                }

                Keys.onDeletePressed: {

                    if (!clipboardMode) {
                        return
                    }

                    LauncherModule
                    .LauncherController
                    .clipboard
                    .deleteSelected()
                }

                Keys.onReturnPressed: {

                    /*
                     * CLIPBOARD
                     */

                    if (clipboardMode) {

                        LauncherModule
                        .LauncherController
                        .clipboard
                        .copySelected()

                        launcherRoot.closeOverlay()

                        return
                    }

                    /*
                     * APPS
                     */

                    if (
                        appMode &&
                        listView.currentIndex >= 0
                    ) {

                        LauncherModule
                        .LauncherController
                        .appLauncher
                        .launch(
                            LauncherModule
                            .LauncherController
                            .appLauncher
                            .filteredApps
                            .get(
                                listView.currentIndex
                            ).exec
                        )

                        launcherRoot.closeOverlay()
                    }
                }
            }

            /*
             * APP LIST
             */

            ListView {
                id: listView

                visible: appMode

                width: parent.width

                height:
                parent.height -
                searchField.height -
                20

                clip: true

                spacing: 4

                model:
                LauncherModule
                .LauncherController
                .appLauncher
                .filteredApps

                delegate: Rectangle {

                    width: ListView.view.width
                    height: 64

                    radius: 10

                    color:
                    ListView.isCurrentItem
                    ? shell.theme.base02
                    : mouseArea.containsMouse
                    ? shell.theme.base01
                    : "transparent"

                    Row {

                        anchors.fill: parent
                        anchors.margins: 14

                        spacing: 14

                        Image {

                            width: 32
                            height: 32

                            anchors.verticalCenter:
                            parent.verticalCenter

                            source:
                            "image://icon/" + icon

                            fillMode:
                            Image.PreserveAspectFit

                            smooth: true
                        }

                        Column {

                            anchors.verticalCenter:
                            parent.verticalCenter

                            spacing: 2

                            Text {

                                text: name

                                color:
                                shell.theme.base05

                                font.pixelSize: 18
                                font.bold: true
                            }

                            Text {

                                text: exec

                                color:
                                shell.theme.base07

                                font.pixelSize: 13

                                elide:
                                Text.ElideRight

                                width: 620
                            }
                        }
                    }

                    MouseArea {
                        id: mouseArea

                        anchors.fill: parent

                        hoverEnabled: true

                        onClicked: {

                            LauncherModule
                            .LauncherController
                            .appLauncher
                            .launch(exec)

                            launcherRoot.closeOverlay()
                        }
                    }
                }
            }

            /*
             * CLIPBOARD VIEW
             */

            Row {

                visible: clipboardMode

                width: parent.width

                height:
                parent.height -
                searchField.height -
                20

                spacing: 20

                ListView {
                    id: clipboardListView

                    width: 540
                    height: parent.height

                    clip: true

                    spacing: 4

                    boundsBehavior:
                    Flickable.StopAtBounds

                    model:
                    LauncherModule
                    .LauncherController
                    .clipboard
                    .filteredClipboardItems

                    currentIndex:
                    LauncherModule
                    .LauncherController
                    .clipboard
                    .selectedIndex

                    delegate: Rectangle {

                        property int itemIndex: index

                        property string itemText:
                        model.text || ""

                        property bool itemIsImage:
                        model.isImage || false

                        property string itemImagePath:
                        model.imagePath || ""

                        width: clipboardListView.width

                        height:
                        itemIsImage
                        ? 120
                        : 70

                        radius: 10

                        color:
                        itemIndex ===
                        LauncherModule
                        .LauncherController
                        .clipboard
                        .selectedIndex
                        ? shell.theme.base02
                        : "transparent"

                        Row {

                            anchors.fill: parent
                            anchors.margins: 12

                            spacing: 12

                            Image {

                                visible: itemIsImage

                                width: 90
                                height: 90

                                source:
                                itemIsImage
                                ? "file://" + itemImagePath
                                : ""

                                fillMode:
                                Image.PreserveAspectFit

                                smooth: true
                            }

                            Text {

                                width:
                                parent.width -
                                (itemIsImage ? 120 : 0)

                                anchors.verticalCenter:
                                parent.verticalCenter

                                text:
                                itemIsImage
                                ? "[Image Clipboard Entry]"
                                : itemText

                                wrapMode: Text.Wrap

                                maximumLineCount: 3

                                elide: Text.ElideRight

                                color: shell.theme.base05

                                font.pixelSize: 18

                                textFormat:
                                Text.PlainText
                            }
                        }

                        MouseArea {

                            anchors.fill: parent

                            hoverEnabled: true

                            onClicked: {

                                LauncherModule
                                .LauncherController
                                .clipboard
                                .selectedIndex = itemIndex

                                LauncherModule
                                .LauncherController
                                .clipboard
                                .updatePreview()
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }

                Rectangle {

                    width: 500
                    height: 500

                    radius: 12

                    color: shell.theme.base00

                    border.width: 2
                    border.color: shell.theme.base03

                    visible:
                    LauncherModule
                    .LauncherController
                    .clipboard
                    .previewImage.length > 0

                    Image {

                        anchors.fill: parent
                        anchors.margins: 10

                        source:
                        LauncherModule
                        .LauncherController
                        .clipboard
                        .previewImage

                        fillMode:
                        Image.PreserveAspectFit

                        smooth: true
                    }
                }
            }

            /*
             * DICTIONARY
             */

            ScrollView {

                visible: dictionaryMode

                width: parent.width

                height:
                parent.height -
                searchField.height -
                20

                clip: true

                Text {

                    width:
                    parent.width - 20

                    text:
                    LauncherModule
                    .LauncherController
                    .dictionary
                    .currentDefinition

                    wrapMode: Text.Wrap

                    color:
                    shell.theme.base05

                    font.pixelSize: 20

                    lineHeight: 1.3
                }
            }

            /*
             * MATH
             */

            Rectangle {

                visible: mathMode

                width: parent.width

                height:
                parent.height -
                searchField.height -
                20

                radius: 12

                color: shell.theme.base00

                border.width: 2
                border.color: shell.theme.base03

                Text {

                    anchors.centerIn: parent

                    text:
                    LauncherModule
                    .LauncherController
                    .mathEngine
                    .mathResultString

                    color:
                    shell.theme.base05

                    font.pixelSize: 42

                    font.bold: true
                }
            }
        }
    }
}
