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

                /*
                 * SEARCH MODES
                 */

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

                    if (dictionaryMode) {

                        LauncherModule
                        .LauncherController
                        .dictionary
                        .fetch(trimmed)

                        return
                    }

                    /*
                     * APP LAUNCHER
                     */

                    LauncherModule
                    .LauncherController
                    .appLauncher
                    .refreshFilter(trimmed)
                }

                /*
                 * DOWN
                 */

                Keys.onDownPressed: {

                    if (clipboardMode) {

                        LauncherModule
                        .LauncherController
                        .clipboard
                        .moveDown()

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

                /*
                 * UP
                 */

                Keys.onUpPressed: {

                    if (clipboardMode) {

                        LauncherModule
                        .LauncherController
                        .clipboard
                        .moveUp()

                        return
                    }

                    if (
                        listView.currentIndex > 0
                    ) {
                        listView.currentIndex--
                    }
                }

                /*
                 * DELETE
                 */

                Keys.onDeletePressed: {

                    if (!clipboardMode) {
                        return
                    }

                    LauncherModule
                    .LauncherController
                    .clipboard
                    .deleteSelected()
                    if (event.key === Qt.Key_Delete) {
                        clipboardController.handleDeleteKeyPress(); // or whatever your Clipboard component ID is named
                        event.accepted = true;
                    }
                }

                /*
                 * ENTER
                 */

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
                    width: 540
                    height: parent.height

                    clip: true

                    spacing: 4

                    model:
                    LauncherModule
                    .LauncherController
                    .clipboard
                    .filteredClipboardItems

                    delegate: Rectangle {
                        required property int index
                        required property string text

                        width: ListView.view.width
                        height: 70

                        radius: 10

                        color:
                        index ===
                        LauncherModule
                        .LauncherController
                        .clipboard
                        .selectedIndex
                        ? shell.theme.base02
                        : "transparent"

                        Text {
                            anchors.fill: parent
                            anchors.margins: 14

                            text: parent.text

                            wrapMode: Text.Wrap

                            maximumLineCount: 2

                            elide: Text.ElideRight

                            color: shell.theme.base05

                            font.pixelSize: 18
                        }
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
        }
    }
}
