import QtQuick
import QtQuick.Layouts
import QtQuick.Controls 2
import QtQuick.Window

import Quickshell
import Quickshell.Io

Scope {
    id: root

    // #######################################################
    // #################### USER VARIABLES ###################
    // #######################################################

    property int uiFontSize: 20
    property int rowHeight: 68
    property int launcherWidth: 980
    property int launcherHeight: 640
    property int imagePreviewSize: 420
    property int borderRadius: 20

    // #######################################################
    // ######################## STATE ########################
    // #######################################################

    property bool isMenuOpen: false
    property bool isMathMode: false
    property bool isClipboardMode: false

    property string mathResultString: ""
    property string activeImageCachePath: ""
    property string dictDataBuffer: ""

    property var masterAppsList: []
    property var masterClipboardList: []

    // #######################################################
    // ####################### HELPERS #######################
    // #######################################################

    function resetLauncherState() {

        root.mathResultString = ""
        root.dictDataBuffer = ""
        root.activeImageCachePath = ""

        root.isMathMode = false

        filteredAppsModel.clear()

        appsListView.currentIndex = -1
    }

    function focusSearch() {

        Qt.callLater(function() {
            appSearchInputField.forceActiveFocus()
        })
    }

    function rebuildClipboardModel(searchTerm) {

        filteredAppsModel.clear()

        let query = (searchTerm || "").trim().toLowerCase()

        for (let i = 0; i < root.masterClipboardList.length; ++i) {

            let item = root.masterClipboardList[i]

            let haystack =
            (
                item.searchText
                || item.labelName
                || ""
            ).toLowerCase()

            if (
                query.length === 0
                || haystack.includes(query)
            ) {

                filteredAppsModel.append(item)
            }
        }

        appsListView.currentIndex =
        filteredAppsModel.count > 0
        ? 0
        : -1

        if (filteredAppsModel.count <= 0) {
            root.activeImageCachePath = ""
        }
    }

    function rebuildAppsModel(searchTerm) {

        filteredAppsModel.clear()

        let query = (searchTerm || "").trim().toLowerCase()

        for (let i = 0; i < root.masterAppsList.length; ++i) {

            let app = root.masterAppsList[i]

            if (
                query.length === 0
                || app.labelName.toLowerCase().includes(query)
            ) {

                filteredAppsModel.append(app)
            }
        }

        appsListView.currentIndex =
        filteredAppsModel.count > 0
        ? 0
        : -1
    }

    function removeClipboardItem(clipId) {

        let proc = Qt.createQmlObject(
            'import Quickshell; Process {}',
            root
        )

        proc.command = [
            "sh",
            "-c",
            "cliphist delete " + clipId
        ]

        proc.running = true

        for (let i = 0; i < root.masterClipboardList.length; ++i) {

            if (root.masterClipboardList[i].clipId === clipId) {

                root.masterClipboardList.splice(i, 1)
                break
            }
        }

        rebuildClipboardModel(
            appSearchInputField.text
            .replace(/^clip\s*/i, "")
        )
    }

    // #######################################################
    // ######################## TOGGLE #######################
    // #######################################################

    function toggleMenu() {

        root.isMenuOpen = !root.isMenuOpen

        if (!root.isMenuOpen)
            return

            resetLauncherState()

            root.isClipboardMode = false

            appSearchInputField.text = ""

            root.masterAppsList = []

            appsIndexer.running = false
            appsIndexer.running = true

            clipboardIndexer.running = false
            dictFetcher.running = false

            focusSearch()
    }

    function openClipboardMenu() {

        root.isMenuOpen = true

        resetLauncherState()

        root.isClipboardMode = true

        appSearchInputField.text = ""

        root.masterClipboardList = []

        clipboardIndexer.running = false

        Qt.callLater(function() {
            clipboardIndexer.running = true
        })

        focusSearch()
    }

    function closeMenu() {

        root.isMenuOpen = false

        appSearchInputField.text = ""

        root.activeImageCachePath = ""

        clipboardIndexer.running = false
        dictFetcher.running = false
    }

    // #######################################################
    // ###################### APP INDEXER ####################
    // #######################################################

    Process {
        id: appsIndexer

        command: [
            "sh",
            "-c",
            `
            find \
            /run/current-system/sw/share/applications \
            ~/.local/share/applications \
            -name '*.desktop' 2>/dev/null |

            while read -r f; do

                name=$(grep -m1 '^Name=' "$f" | sed 's/^Name=//')

                exec_cmd=$(grep -m1 '^Exec=' "$f" |
                sed 's/^Exec=//' |
                sed 's/ *%[fFuUdDnNickvm]//g' |
                tr -d '"'
                )

                icon_name=$(grep -m1 '^Icon=' "$f" |
                sed 's/^Icon=//')

                [ -z "$icon_name" ] && icon_name="system-run"

                if [ -n "$name" ] && [ -n "$exec_cmd" ]; then
                    echo "$name|$exec_cmd|$icon_name"
                    fi

                    done | sort -u
                    `
        ]

        stdout: SplitParser {

            onRead: data => {

                if (!data || root.isClipboardMode)
                    return

                    let lines = data.split("\n")

                    for (let line of lines) {

                        line = line.trim()

                        if (line.length === 0)
                            continue

                            let parts = line.split("|")

                            if (parts.length < 3)
                                continue

                                let obj = {

                                    labelName: parts[0],
                                    execCmd: parts[1],
                                    iconName: parts[2],

                                    isClipboard: false,
                                    isImageClip: false,

                                    imagePath: "",
                                    clipId: ""
                                }

                                root.masterAppsList.push(obj)
                    }

                    rebuildAppsModel(appSearchInputField.text)
            }
        }
    }

    // ####### CLIPBOARD PROCESS #######

    Process {
        id: clipboardIndexer

        command: [
            "sh",
            "-c",
            `
            mkdir -p /tmp/quickshell_clipboard_previews

            cliphist list | while read -r line; do

            id=$(echo "$line" | awk '{print $1}')

            descriptor=$(echo "$line" | cut -d' ' -f2-)

            if echo "$descriptor" | grep -qiE 'binary data|png|jpeg|bmp|image'; then

                out="/tmp/quickshell_clipboard_previews/$id.png"

                cliphist decode "$id" > "$out" 2>/dev/null

                echo "IMAGE|||$id|||$out"

                else

                    text=$(cliphist decode "$id" 2>/dev/null | tr '\\n' ' ' | head -c 300)

                    text=$(echo "$text" | tr '|' ' ')

                    echo "TEXT|||$id|||$text"

                    fi

                    done
                    `
        ]

        stdout: SplitParser {

            onRead: data => {

                if (!root.isClipboardMode || !data)
                    return

                    let lines = data.split("\n")

                    for (let line of lines) {

                        line = line.trim()

                        if (line.length === 0)
                            continue

                            let parts = line.split("|||")

                            if (parts.length < 3)
                                continue

                                let type = parts[0]
                                let clipId = parts[1]

                                let obj = {
                                    labelName: "",
                                    searchText: "",
                                    execCmd: clipId,

                                    iconName: type === "IMAGE"
                                    ? "image"
                                    : "text-x-generic",

                                    isClipboard: true,
                                    isImageClip: type === "IMAGE",

                                    imagePath: "",
                                    clipId: clipId
                                }

                                if (type === "IMAGE") {

                                    obj.labelName = "[IMAGE]"
                                    obj.searchText = "image png jpg screenshot photo"

                                    obj.imagePath =
                                    "file://" +
                                    parts[2] +
                                    "?t=" +
                                    Date.now()

                                } else {

                                    obj.labelName = parts[2]
                                    obj.searchText = parts[2].toLowerCase()
                                }

                                root.masterClipboardList.push(obj)
                    }

                    root.refreshClipboardFilter()
            }
        }
    }
    // #######################################################
    // ###################### DICTIONARY #####################
    // #######################################################

    Process {
        id: dictFetcher

        stdout: SplitParser {

            onRead: data => {
                root.dictDataBuffer += data
            }
        }

        onExited: {

            if (root.dictDataBuffer.trim().length === 0) {

                root.mathResultString =
                "Dictionary lookup failed."

                return
            }

            try {

                let response =
                JSON.parse(root.dictDataBuffer)

                if (
                    Array.isArray(response)
                    && response.length > 0
                ) {

                    let wordData = response[0]

                    let output = ""

                    output +=
                    "WORD: "
                    + (wordData.word || "")
                    + "\n\n"

                    if (wordData.phonetic) {

                        output +=
                        "PHONETIC: "
                        + wordData.phonetic
                        + "\n\n"
                    }

                    if (
                        wordData.meanings
                        && wordData.meanings.length > 0
                    ) {

                        let meaning =
                        wordData.meanings[0]

                        if (meaning.partOfSpeech) {

                            output +=
                            "TYPE: "
                            + meaning.partOfSpeech
                            + "\n\n"
                        }

                        if (
                            meaning.definitions
                            && meaning.definitions.length > 0
                        ) {

                            output +=
                            "DEFINITION:\n"
                            + meaning.definitions[0].definition
                            + "\n\n"
                        }
                    }

                    root.mathResultString = output

                } else {

                    root.mathResultString =
                    "No dictionary results."
                }

            } catch (e) {

                root.mathResultString =
                "Dictionary parse error."
            }
        }
    }

    // #######################################################
    // ######################## RUNNER #######################
    // #######################################################

    Process {
        id: nativeAppRunner
    }

    ListModel {
        id: filteredAppsModel
    }

    // #######################################################
    // ######################### IPC #########################
    // #######################################################

    IpcHandler {
        id: launcherIpc

        target: "global_launcher"

        function toggleMenu() {
            root.toggleMenu()
        }

        function closeMenu() {
            root.closeMenu()
        }

        function openLauncher() {
            root.toggleMenu()
        }

        function openClipboard() {
            root.openClipboardMenu()
        }
    }

    // #######################################################
    // ###################### DICTIONARY #####################
    // #######################################################

    function fetchWordDefinition(word) {

        root.dictDataBuffer = ""

        root.mathResultString =
        `Searching "${word}"...`

        dictFetcher.running = false

        dictFetcher.command = [
            "sh",
            "-c",
            `curl -s "https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}"`
        ]

        dictFetcher.running = true
    }

    // #######################################################
    // ###################### CONVERSIONS ####################
    // #######################################################

    function runMeasurementConversion(lowerQuery) {

        let match =
        lowerQuery.match(
            /^([0-9.]+)\s*([a-zA-Z]+)(?:\s+to\s+([a-zA-Z]+))?$/
        )

        if (!match)
            return false

            let value = parseFloat(match[1])

            let from = match[2].toLowerCase()

            let target =
            match[3]
            ? match[3].toLowerCase()
            : ""

            let units = {

                mm: 0.001,
                cm: 0.01,
                m: 1,
                km: 1000,

                in: 0.0254,
                ft: 0.3048,
                yd: 0.9144,
                mi: 1609.34
            }

            if (units[from] === undefined)
                return false

                let meters = value * units[from]

                let results = []

                for (let key in units) {

                    let converted =
                    meters / units[key]

                    let line =
                    converted.toFixed(3)
                    + " "
                    + key

                    if (
                        target.length === 0
                        || line.toLowerCase().includes(target)
                    ) {

                        results.push(line)
                    }
                }

                root.isMathMode = true

                root.mathResultString =
                results.join("\n")

                return true
    }

    // #######################################################
    // ######################## FILTER #######################
    // #######################################################

    function filterApplications(query) {

        let cleanQuery = query.trim()

        let lowerQuery =
        cleanQuery.toLowerCase()

        // ====================================================
        // DICTIONARY
        // ====================================================

        if (
            lowerQuery === "def"
            || lowerQuery.startsWith("def ")
        ) {

            root.isMathMode = true
            root.isClipboardMode = false

            let word =
            cleanQuery.substring(4).trim()

            if (word.length > 0) {

                fetchWordDefinition(word)

            } else {

                root.mathResultString =
                "Format: def <word>"
            }

            return
        }

        // ====================================================
        // CLIPBOARD MODE
        // ====================================================

        if (
            root.isClipboardMode
            || lowerQuery === "clip"
            || lowerQuery.startsWith("clip ")
        ) {

            root.isClipboardMode = true
            root.isMathMode = false

            let searchTerm =
            lowerQuery.replace(/^clip\s*/i, "")

            rebuildClipboardModel(searchTerm)

            return
        }

        root.isClipboardMode = false

        // ====================================================
        // CONVERSIONS
        // ====================================================

        if (runMeasurementConversion(lowerQuery))
            return

            // ====================================================
            // CALCULATOR
            // ====================================================

            if (
                cleanQuery.length > 0
                && /^[0-9+\-*/().\s]+$/.test(cleanQuery)
            ) {

                root.isMathMode = true

                try {

                    let result =
                    Function(
                        `"use strict"; return (${cleanQuery})`
                    )()

                    root.mathResultString =
                    String(result)

                } catch (e) {

                    root.mathResultString =
                    "Calculation error."
                }

                return
            }

            // ====================================================
            // APPS
            // ====================================================

            root.isMathMode = false

            rebuildAppsModel(lowerQuery)
    }

    // #######################################################
    // ####################### EXECUTION #####################
    // #######################################################

    function handleSelectionExecution(
        execCmd,
        isClipboardRow,
        clipId
    ) {

        if (isClipboardRow) {

            let proc =
            Qt.createQmlObject(
                'import Quickshell; Process {}',
                root
            )

            proc.command = [
                "sh",
                "-c",
                `cliphist decode ${clipId} | wl-copy`
            ]

            proc.running = true

        } else {

            nativeAppRunner.running = false

            nativeAppRunner.command = [
                "bash",
                "-c",
                execCmd + " &"
            ]

            nativeAppRunner.running = true
        }

        root.closeMenu()
    }

    // #######################################################
    // ######################## WINDOW #######################
    // #######################################################

    Window {
        id: launcherWindow

        visible: root.isMenuOpen

        width: root.launcherWidth
        height: root.launcherHeight

        color: "transparent"

        flags:
        Qt.Window
        | Qt.FramelessWindowHint
        | Qt.WindowStaysOnTopHint

        Rectangle {

            anchors.fill: parent

            radius: root.borderRadius

            color:
            Quickshell.env("STYLIX_BASE00")
            || "#1a1a1a"

            border.width: 4

            border.color:
            Quickshell.env("STYLIX_BASE03")
            || "#003399"

            clip: true

            RowLayout {

                anchors.fill: parent

                anchors.margins: 20

                spacing: 16

                // ###################################################
                // ###################### LEFT #######################
                // ###################################################

                ColumnLayout {

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    spacing: 12

                    TextField {
                        id: appSearchInputField

                        Layout.fillWidth: true

                        placeholderText:
                        "Apps, clip, math, def <word>..."

                        font.family: "monospace"

                        font.pixelSize:
                        root.uiFontSize

                        color: "white"

                        selectByMouse: true

                        background: Rectangle {

                            radius: 8

                            color: "#080808"

                            border.width: 2

                            border.color:
                            appSearchInputField.activeFocus
                            ? "red"
                            : "#333333"
                        }

                        onTextChanged: {
                            root.filterApplications(text)
                        }

                        Keys.onPressed: function(event) {

                            // ESC
                            if (event.key === Qt.Key_Escape) {

                                root.closeMenu()

                                event.accepted = true
                                return
                            }

                            // DELETE CLIPBOARD ENTRY
                            if (
                                (
                                    event.key === Qt.Key_Delete
                                    || event.key === Qt.Key_Backspace
                                )
                                && root.isClipboardMode
                                && filteredAppsModel.count > 0
                            ) {

                                let item =
                                filteredAppsModel.get(
                                    appsListView.currentIndex
                                )

                                if (item) {

                                    removeClipboardItem(
                                        item.clipId
                                    )
                                }

                                event.accepted = true
                                return
                            }

                            // DOWN
                            if (event.key === Qt.Key_Down) {

                                if (
                                    appsListView.currentIndex
                                    < filteredAppsModel.count - 1
                                ) {

                                    appsListView.currentIndex++
                                }

                                event.accepted = true
                                return
                            }

                            // UP
                            if (event.key === Qt.Key_Up) {

                                if (
                                    appsListView.currentIndex > 0
                                ) {

                                    appsListView.currentIndex--
                                }

                                event.accepted = true
                                return
                            }

                            // ENTER
                            if (
                                event.key === Qt.Key_Return
                                || event.key === Qt.Key_Enter
                            ) {

                                if (root.isMathMode) {

                                    let proc =
                                    Qt.createQmlObject(
                                        'import Quickshell; Process {}',
                                        root
                                    )

                                    proc.command = [
                                        "sh",
                                        "-c",
                                        `echo -n '${root.mathResultString}' | wl-copy`
                                    ]

                                    proc.running = true

                                    root.closeMenu()

                                } else if (
                                    filteredAppsModel.count > 0
                                ) {

                                    let item =
                                    filteredAppsModel.get(
                                        appsListView.currentIndex
                                    )

                                    handleSelectionExecution(
                                        item.execCmd,
                                        item.isClipboard,
                                        item.clipId
                                    )
                                }

                                event.accepted = true
                            }
                        }
                    }

                    // ###################################################
                    // ##################### LISTVIEW ####################
                    // ###################################################

                    ListView {
                        id: appsListView

                        visible: !root.isMathMode

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        model: filteredAppsModel

                        clip: true

                        spacing: 4

                        onCurrentIndexChanged: {

                            if (
                                !root.isClipboardMode
                                || currentIndex < 0
                            ) {

                                root.activeImageCachePath = ""
                                return
                            }

                            let item =
                            model.get(currentIndex)

                            if (
                                item
                                && item.isImageClip
                            ) {

                                root.activeImageCachePath =
                                item.imagePath

                            } else {

                                root.activeImageCachePath = ""
                            }
                        }

                        delegate: Rectangle {

                            width: appsListView.width

                            height: root.rowHeight

                            radius: 8

                            color:
                            appsListView.currentIndex === index
                            ? "#252538"
                            : "transparent"

                            RowLayout {

                                anchors.fill: parent

                                anchors.leftMargin: 8
                                anchors.rightMargin: 8

                                spacing: 12

                                Rectangle {

                                    Layout.preferredWidth: 52
                                    Layout.preferredHeight: 52

                                    radius: 6

                                    color: "#111111"

                                    clip: true

                                    Image {

                                        anchors.fill: parent

                                        source:
                                        model.isImageClip
                                        ? model.imagePath
                                        : "image://icon/" + model.iconName

                                        fillMode:
                                        Image.PreserveAspectFit

                                        cache: false
                                    }
                                }

                                Text {

                                    Layout.fillWidth: true

                                    text: model.labelName

                                    color: "white"

                                    font.family: "monospace"

                                    font.pixelSize:
                                    root.uiFontSize

                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {

                                anchors.fill: parent

                                hoverEnabled: true

                                onEntered: {
                                    appsListView.currentIndex =
                                    index
                                }

                                onClicked: {

                                    handleSelectionExecution(
                                        model.execCmd,
                                        model.isClipboard,
                                        model.clipId
                                    )
                                }
                            }
                        }
                    }

                    // ###################################################
                    // ###################### MATH #######################
                    // ###################################################

                    Rectangle {

                        visible: root.isMathMode

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        radius: 12

                        color: "#0c0c12"

                        border.width: 2

                        border.color: "red"

                        ScrollView {

                            anchors.fill: parent

                            anchors.margins: 20

                            clip: true

                            Text {

                                width: parent.width

                                text:
                                root.mathResultString

                                color: "#ffff88"

                                font.family:
                                "monospace"

                                font.pixelSize:
                                root.uiFontSize

                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }

                // ###################################################
                // ################ IMAGE PREVIEW ###################
                // ###################################################

                Rectangle {

                    visible:
                    root.isClipboardMode
                    && root.activeImageCachePath !== ""

                    Layout.preferredWidth:
                    root.imagePreviewSize

                    Layout.preferredHeight:
                    root.imagePreviewSize

                    radius: 12

                    color: "#111111"

                    border.width: 2

                    border.color: "#333333"

                    clip: true

                    Image {

                        anchors.fill: parent

                        anchors.margins: 8

                        source:
                        root.activeImageCachePath

                        fillMode:
                        Image.PreserveAspectFit

                        cache: false
                    }
                }
            }
        }
    }
}
