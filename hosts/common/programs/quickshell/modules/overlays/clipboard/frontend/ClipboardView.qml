import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import "../../../style" as Style
import "../../../common/Utils.js" as Utils

Item {
    id: viewRoot

    property var theme: null
    property var settingsManager: null

    readonly property int fieldHeight: settingsManager
        ? settingsManager.getWindowFieldHeight("clipboard", 52) : 52
    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize : 15

    readonly property int controlBorderWidth: (settingsManager && settingsManager.controlBorderWidth)
        ? settingsManager.controlBorderWidth
        : ((theme && theme.controlBorderWidth) ? theme.controlBorderWidth : 2)

    readonly property int globalBorderWidth: (settingsManager && settingsManager.globalBorderWidth)
        ? settingsManager.globalBorderWidth
        : ((theme && theme.globalBorderWidth) ? theme.globalBorderWidth : 3)

    readonly property var inputPad: Utils.getSafeInputPadding(settingsManager)

    signal completed()

    property var rawItems: []
    property int selectedIndex: 0
    property string previewImage: ""
    property string previewText: ""
    property string previewTitle: ""
    property string previewDate: ""
    property string previewDims: ""
    property string previewSize: ""
    property bool isOcrRunning: false

    property string debugError: ""
    property string debugStatus: "Initializing..."
    property bool isFetching: false

    ListModel {
        id: clipModel
    }

    function clearAndFocus() {
        searchField.clear();
        reload();
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    function reload() {
        viewRoot.isFetching = true;
        viewRoot.debugError = "";
        viewRoot.debugStatus = "Querying cliphist...";
        listProc.running = false;
        rawItems = [];
        clipModel.clear();
        listProc.running = true;
    }

    function filterList(query) {
        var q = (query || "").toLowerCase().trim();
        var isImgFilter = (q === "image" || q === "images" || q === "shot" || q === "screenshots" || q.startsWith("image:"));

        if (q.startsWith("image:")) {
            q = q.substring(6).trim();
        }

        clipModel.clear();
        for (var i = 0; i < rawItems.length; i++) {
            var item = rawItems[i];
            if (!item) continue;
            if (isImgFilter && !item.isImage) continue;

            var st = (item.searchText || item.text || item.displayText || item.title || "").toLowerCase();
            if (q === "" || st.indexOf(q) !== -1 || (item.isImage && (q === "image" || q === "shot"))) {
                clipModel.append(item);
            }
        }
        viewRoot.selectedIndex = 0;
        updatePreview();
    }

    function updatePreview() {
        if (selectedIndex < 0 || selectedIndex >= clipModel.count) {
            previewImage = "";
            previewText = "";
            previewTitle = "";
            previewDate = "";
            previewDims = "";
            previewSize = "";
            return;
        }

        var item = clipModel.get(selectedIndex);
        if (item.isImage) {
            previewImage = item.thumbPath || "";
            previewText = "";
            previewTitle = item.title || "Screenshot";
            previewDate = item.date || "";
            previewDims = item.dims || "";
            previewSize = item.size || "";
            runOcr(true);
        } else {
            previewImage = "";
            previewTitle = "Text";
            previewDate = item.date || "";
            previewDims = "";
            previewSize = "";
            previewProc.running = false;
            previewProc.command = [
                "sh", "-c",
                'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
                'SCR="' + Quickshell.shellDir + '/modules/overlays/clipboard/backend/ClipboardEngine.lua"; ' +
                'if [ -f "$SCR" ] && command -v lua >/dev/null 2>&1; then ' +
                '  lua "$SCR" preview "$1"; ' +
                'else ' +
                '  printf "%s\t\n" "$1" | cliphist decode; ' +
                'fi',
                "sh", String(item.id)
            ];
            previewProc.running = true;
        }
    }

    function runOcr(background) {
        if (selectedIndex < 0 || selectedIndex >= clipModel.count) return;
        var item = clipModel.get(selectedIndex);
        if (!item || !item.isImage) return;

        if (!background) viewRoot.isOcrRunning = true;
        ocrProc.command = [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="' + Quickshell.shellDir + '/modules/overlays/clipboard/backend/ClipboardEngine.lua"; ' +
            'if [ -f "$SCR" ] && command -v lua >/dev/null 2>&1; then ' +
            '  lua "$SCR" ocr "$1"; ' +
            'else ' +
            ' tmp="${XDG_RUNTIME_DIR:-/tmp}/qs_ocr_$1.png"; printf "%s\t\n" "$1" | cliphist decode > "$tmp" 2>/dev/null; ' +
            '  tesseract "$tmp" stdout 2>/dev/null || true; rm -f "$tmp" 2>/dev/null; ' +
            'fi',
            "sh", String(item.id)
        ];
        ocrProc.running = false;
        ocrProc.running = true;
    }

    function copyCurrent() {
        if (selectedIndex < 0 || selectedIndex >= clipModel.count) return;
        var item = clipModel.get(selectedIndex);
        copyProc.command = [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="' + Quickshell.shellDir + '/modules/overlays/clipboard/backend/ClipboardEngine.lua"; ' +
            'if [ -f "$SCR" ] && command -v lua >/dev/null 2>&1; then ' +
            '  lua "$SCR" copy "$1"; ' +
            'else ' +
            '  printf "%s\t\n" "$1" | cliphist decode | wl-copy; ' +
            'fi',
            "sh", String(item.id)
        ];
        copyProc.running = false;
        copyProc.running = true;
        viewRoot.completed();
    }

    function deleteCurrent() {
        if (selectedIndex < 0 || selectedIndex >= clipModel.count) return;
        var item = clipModel.get(selectedIndex);
        deleteProc.command = [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="' + Quickshell.shellDir + '/modules/overlays/clipboard/backend/ClipboardEngine.lua"; ' +
            'if [ -f "$SCR" ] && command -v lua >/dev/null 2>&1; then ' +
            '  lua "$SCR" delete "$1"; ' +
            'else ' +
            '  printf "%s\t\n" "$1" | cliphist delete; ' +
            'fi',
            "sh", String(item.id)
        ];
        deleteProc.running = false;
        deleteProc.running = true;

        for (var i = 0; i < rawItems.length; i++) {
            if (rawItems[i].id === item.id) {
                rawItems.splice(i, 1);
                break;
            }
        }
        clipModel.remove(selectedIndex);
        if (selectedIndex >= clipModel.count) selectedIndex = Math.max(0, clipModel.count - 1);
        updatePreview();
    }

    function wipeAll() {
        wipeProc.running = false;
        wipeProc.running = true;
        rawItems = [];
        clipModel.clear();
        previewImage = "";
        previewText = "";
        previewTitle = "";
        previewDate = "";
        previewDims = "";
        previewSize = "";
    }

    Process {
        id: listProc
        command: [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="' + Quickshell.shellDir + '/modules/overlays/clipboard/backend/ClipboardEngine.lua"; ' +
            'if [ -f "$SCR" ] && command -v lua >/dev/null 2>&1; then ' +
            '  lua "$SCR" list; ' +
            'else ' +
            '  cliphist list 2>/dev/null | awk -F\'\t\' \'BEGIN {printf "["} { if (NR>1) printf ","; ' +
            '  gsub(/\\\\/, "\\\\\\\\", $2); gsub(/"/, "\\\\\"", $2); gsub(/\\n/, "\\\\n", $2); ' +
            '  is_img = ($2 ~ /binary data/ || $2 ~ /\\[\\[/) ? "true" : "false"; ' +
            '  printf "{\\"id\\":\\"%s\\",\\"isImage\\":%s,\\"text\\":\\"%s\\",\\"displayText\\":\\"%s\\",\\"title\\":\\"Entry\\",\\"searchText\\":\\"%s\\"}", $1, is_img, $2, $2, tolower($2) ' +
            '  } END {print "]"}\'; ' +
            'fi'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                viewRoot.isFetching = false;
                var raw = text ? text.trim() : "";
                if (!raw) {
                    viewRoot.debugStatus = "cliphist database is currently empty.";
                    return;
                }
                try {
                    var parsed = JSON.parse(raw);
                    viewRoot.rawItems = parsed;
                    viewRoot.debugStatus = parsed.length === 0 ? "cliphist database is currently empty." : "Loaded " + parsed.length + " entries.";
                    viewRoot.filterList(searchField.text);
                } catch(e) {
                    viewRoot.debugError = "JSON parse error: " + e.message;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "") {
                    viewRoot.debugError = text.trim();
                }
            }
        }
    }

    Process {
        id: previewProc
        stdout: StdioCollector {
            onStreamFinished: {
                viewRoot.previewText = text || "";
            }
        }
    }

    Process {
        id: ocrProc
        stdout: StdioCollector {
            onStreamFinished: {
                viewRoot.isOcrRunning = false;
                var ocrResult = (text || "").trim();
                if (ocrResult.length > 0) {
                    viewRoot.previewText = ocrResult;
                }
            }
        }
    }

    Process { id: copyProc }
    Process { id: deleteProc }
    Process {
        id: wipeProc
        command: [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="' + Quickshell.shellDir + '/modules/overlays/clipboard/backend/ClipboardEngine.lua"; ' +
            'if [ -f "$SCR" ] && command -v lua >/dev/null 2>&1; then ' +
            '  lua "$SCR" wipe; ' +
            'else ' +
            ' cliphist wipe 2>/dev/null; rm -f "${XDG_RUNTIME_DIR:-/tmp}"/qs_clip_thumb_*.png 2>/dev/null || true; ' +
            'fi'
        ]
    }

    Component.onCompleted: clearAndFocus()
    onVisibleChanged: if (visible) clearAndFocus()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12

        // Top Search Bar Row
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: viewRoot.fieldHeight
            Layout.minimumHeight: viewRoot.fieldHeight
            Layout.maximumHeight: viewRoot.fieldHeight
            spacing: 12

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    color: (theme && theme.base00) ? theme.base00 : "#11111b"
                    borderColor: searchField.activeFocus
                        ? ((theme && theme.base05) ? theme.base05 : "yellow")
                        : ((theme && theme.base03) ? theme.base03 : "#45475a")
                    borderWidth: viewRoot.controlBorderWidth
                    slantWidth: 14
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: viewRoot.inputPad.left
                    anchors.rightMargin: viewRoot.inputPad.right
                    spacing: 10

                    Text {
                        text: "📋"
                        font.pixelSize: Math.max(16, viewRoot.fieldHeight * 0.38)
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                        font.pixelSize: viewRoot.overlayFontSize
                        color: (theme && theme.base05) ? theme.base05 : "yellow"
                        selectByMouse: true
                        focus: true
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: viewRoot.filterList(text)

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search clipboard... [type 'image:' or 'shot' for images, Del to remove]"
                            color: "#666"
                            font.pixelSize: viewRoot.overlayFontSize
                            visible: parent.text === "" && !parent.activeFocus
                            elide: Text.ElideRight
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Down) {
                                if (viewRoot.selectedIndex < clipModel.count - 1) {
                                    viewRoot.selectedIndex++;
                                    viewRoot.updatePreview();
                                    clipList.positionViewAtIndex(viewRoot.selectedIndex, ListView.Contain);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                if (viewRoot.selectedIndex > 0) {
                                    viewRoot.selectedIndex--;
                                    viewRoot.updatePreview();
                                    clipList.positionViewAtIndex(viewRoot.selectedIndex, ListView.Contain);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                viewRoot.copyCurrent();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Delete) {
                                viewRoot.deleteCurrent();
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            Item {
                Layout.preferredWidth: 80
                Layout.fillHeight: true

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    color: wipeHov.hovered ? "#ff5555" : ((theme && theme.base00) ? theme.base00 : "#11111b")
                    borderColor: "#ff5555"
                    borderWidth: viewRoot.controlBorderWidth
                    slantWidth: 10
                }

                Text {
                    anchors.centerIn: parent
                    text: "🗑️ Wipe"
                    font.bold: true
                    font.pixelSize: 13
                    color: wipeHov.hovered ? "#000" : "#ff5555"
                }

                HoverHandler { id: wipeHov }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: viewRoot.wipeAll()
                }
            }
        }

        // Two-Column Split (List & Preview)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Item {
                Layout.preferredWidth: Math.round(viewRoot.width * 0.46)
                Layout.fillHeight: true

                ListView {
                    id: clipList
                    anchors.fill: parent
                    clip: true
                    spacing: 6
                    model: clipModel
                    currentIndex: viewRoot.selectedIndex

                    delegate: Item {
                        id: delegateCard
                        readonly property bool isSelected: index === viewRoot.selectedIndex
                        width: clipList.width - 12
                        height: viewRoot.fieldHeight

                        Style.ShapeBox {
                            anchors.fill: parent
                            role: "input"
                            color: delegateCard.isSelected ? ((theme && theme.base02) ? theme.base02 : "#333") : "transparent"
                            borderColor: delegateCard.isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : ((theme && theme.base03) ? theme.base03 : "#555")
                            borderWidth: viewRoot.controlBorderWidth
                            slantWidth: 10
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.max(18, viewRoot.inputPad.left + 4)
                            anchors.rightMargin: Math.max(16, viewRoot.inputPad.right)
                            anchors.topMargin: model.isImage ? 8 : 4
                            anchors.bottomMargin: model.isImage ? 8 : 4
                            spacing: 10

                            // 1. Image Thumbnail
                            Rectangle {
                                visible: model.isImage
                                Layout.preferredWidth: 54
                                Layout.preferredHeight: 54
                                Layout.alignment: Qt.AlignVCenter
                                radius: 4
                                color: (theme && theme.base02) ? theme.base02 : "#1a1a1a"
                                border.color: (theme && theme.base03) ? theme.base03 : "#45475a"
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    fillMode: Image.PreserveAspectFit
                                    cache: false
                                    asynchronous: true
                                    source: model.isImage ? (model.thumbPath || "") : ""
                                }
                            }

                            // 2. Compact Text Icon
                            Text {
                                visible: !model.isImage
                                text: "📄"
                                font.pixelSize: 16
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    text: model.isImage ? (model.title || "Screenshot") : (model.displayText || model.text || "")
                                    font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                                    font.pixelSize: viewRoot.overlayFontSize
                                    font.bold: delegateCard.isSelected
                                    color: delegateCard.isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#ccc"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: model.isImage || (model.date && model.date !== "")
                                    text: {
                                        if (!model.isImage) return model.date || "";
                                        var d = model.date || "";
                                        if (model.dims && model.dims !== "") d += (d !== "" ? " • " : "") + model.dims;
                                        if (model.size && model.size !== "") d += (d !== "" ? " (" : "") + model.size + (d !== "" ? ")" : "");
                                        return d;
                                    }
                                    font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                                    font.pixelSize: Math.max(10, viewRoot.overlayFontSize - 4)
                                    color: delegateCard.isSelected ? ((theme && theme.base0C) ? theme.base0C : "#04f100") : "#888"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                viewRoot.selectedIndex = index;
                                viewRoot.updatePreview();
                            }
                            onDoubleClicked: {
                                viewRoot.selectedIndex = index;
                                viewRoot.copyCurrent();
                            }
                        }
                    }
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
            }

            // Right Pane: Preview Canvas
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    color: (theme && theme.base00) ? theme.base00 : "#11111b"
                    borderColor: (theme && theme.base03) ? theme.base03 : "#45475a"
                    borderWidth: viewRoot.controlBorderWidth
                    slantWidth: 10
                }

                // Image Preview Mode
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10
                    visible: viewRoot.previewImage !== ""

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "🖼️ " + viewRoot.previewTitle
                            font.bold: true
                            font.pixelSize: viewRoot.overlayFontSize + 1
                            color: (theme && theme.base05) ? theme.base05 : "yellow"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            width: ocrTxt.implicitWidth + 18
                            height: 26
                            radius: 4
                            color: ocrHov.hovered ? ((theme && theme.base0C) ? theme.base0C : "#04f100") : "transparent"
                            border.color: (theme && theme.base0C) ? theme.base0C : "#04f100"
                            border.width: 1.5

                            Text {
                                id: ocrTxt
                                anchors.centerIn: parent
                                text: viewRoot.isOcrRunning ? "⏳ Reading..." : "🔤 Copy OCR Text"
                                font.pixelSize: 11
                                font.bold: true
                                color: ocrHov.hovered ? "#000000" : ((theme && theme.base0C) ? theme.base0C : "#04f100")
                            }

                            HoverHandler { id: ocrHov }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    viewRoot.runOcr(false);
                                    if (viewRoot.previewText !== "") {
                                        Quickshell.clipboardText = viewRoot.previewText;
                                    }
                                }
                            }
                        }

                        Text {
                            text: viewRoot.previewDate
                            font.pixelSize: viewRoot.overlayFontSize - 3
                            color: "#888"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: (theme && theme.base03) ? theme.base03 : "#45475a"
                    }

                    Image {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        source: viewRoot.previewImage
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        asynchronous: true
                    }

                    Text {
                        text: viewRoot.previewText !== "" ? ("Text: " + viewRoot.previewText.replace(/\n/g, " ").slice(0, 60)) : ("Resolution: " + viewRoot.previewDims + "  •  Size: " + viewRoot.previewSize)
                        font.pixelSize: viewRoot.overlayFontSize - 3
                        color: (theme && theme.base0C) ? theme.base0C : "#04f100"
                        Layout.alignment: Qt.AlignHCenter
                        elide: Text.ElideRight
                        Layout.maximumWidth: parent.width - 20
                    }
                }

                // Text Preview Mode
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 14
                    visible: viewRoot.previewImage === ""
                    clip: true

                    TextArea {
                        text: viewRoot.previewText
                        wrapMode: Text.WrapAnywhere
                        readOnly: true
                        selectByMouse: true
                        color: (theme && theme.base05) ? theme.base05 : "yellow"
                        font.family: "monospace"
                        font.pixelSize: viewRoot.overlayFontSize
                        background: null
                    }
                }
            }
        }
    }
}
