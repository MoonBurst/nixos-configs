import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshot"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // ---- Selection state -----------------------------------------------------
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0
    property bool hasSelection: false
    property bool creating: false
    property bool exporting: false
    property string activeRevealedPath: ""

    readonly property bool ready: shot.hasContent
    readonly property string selfTestMode: {
        var v = Quickshell.env("QUICKSHOT_SELFTEST");
        return v ? String(v) : "";
    }
    readonly property bool selfTest: selfTestMode === "1" || selfTestMode === "2"
    onReadyChanged: if (ready && selfTest) Qt.callLater(runSelfTest)
    readonly property bool active: ShotState.ownsSelection(modelData.name)
    readonly property bool isOwner: ShotState.activeScreen === modelData.name
    readonly property bool showChrome: ready && !exporting && (creating || hasSelection)
    readonly property real captureScale: shot.sourceSize.width > 0
        ? shot.sourceSize.width / Math.max(1, width) : 1

    property string _mode: ""

    Connections {
        target: ShotState
        function onCopyRequested() { if (root.isOwner) root.exportRegion("copy"); }
        function onSaveRequested() { if (root.isOwner) root.exportRegion("save"); }
        function onUndoRequested() { if (root.isOwner) canvas.undo(); }
        function onOcrRequested() { if (root.isOwner) root.exportRegion("ocr"); }
        function onToolChanged() {
            if (ShotState.tool === "colorpicker" && root.active && root.ready) {
                captureRoot.grabToImage(function (result) {
                    if (result) {
                        var path = "/tmp/quickshot-backdrop.png";
                        result.saveToFile(path);
                        backdropImage.source = "file://" + path + "?t=" + new Date().getTime();
                    }
                });
            }
        }
    }

    Image {
        id: backdropImage
        visible: false
        cache: false
        onStatusChanged: if (status === Image.Ready) magnifierCanvas.requestPaint()
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: function (event) { root.onKey(event); }

        Item {
            id: exportClip
            clip: true
            x: 0
            y: 0
            width: root.width
            height: root.height

            Item {
                id: captureRoot
                x: 0
                y: 0
                width: root.width
                height: root.height

                ScreencopyView {
                    id: shot
                    anchors.fill: parent
                    captureSource: root.modelData
                    live: false
                    paintCursor: false
                }

                // Live revealed leak image
                Image {
                    id: liveRevealOverlay
                    x: root.selX
                    y: root.selY
                    width: root.selW
                    height: root.selH
                    visible: false
                    fillMode: Image.Stretch
                    cache: false
                    z: 5
                }

                AnnotationCanvas {
                    id: canvas
                    anchors.fill: parent
                    backdrop: shot
                    z: 10
                    onEditFinished: content.forceActiveFocus()
                    onEditStarted: {
                        editor.text = "";
                        editor.forceActiveFocus();
                    }
                }
            }
        }

        Timer {
            interval: 120
            repeat: true
            running: !shot.hasContent
            property int tries: 0
            onTriggered: {
                if (shot.hasContent || tries > 10) {
                    running = false;
                    return;
                }
                shot.captureFrame();
                tries += 1;
            }
        }

        Item {
            anchors.fill: parent
            visible: root.ready
            Rectangle {
                color: Style.dim; opacity: Style.dimOpacity
                x: 0; y: 0; width: root.width; height: Math.max(0, root.selY)
            }
            Rectangle {
                color: Style.dim; opacity: Style.dimOpacity
                x: 0; y: root.selY + root.selH
                width: root.width; height: Math.max(0, root.height - (root.selY + root.selH))
            }
            Rectangle {
                color: Style.dim; opacity: Style.dimOpacity
                x: 0; y: root.selY; width: Math.max(0, root.selX); height: root.selH
            }
            Rectangle {
                color: Style.dim; opacity: Style.dimOpacity
                x: root.selX + root.selW; y: root.selY
                width: Math.max(0, root.width - (root.selX + root.selW)); height: root.selH
            }
        }

        Rectangle {
            visible: root.showChrome
            x: root.selX
            y: root.selY
            width: root.selW
            height: root.selH
            color: "transparent"
            border.color: ShotState.scanMode ? "#00f0ff" : Style.selectionBorder
            border.width: Style.selectionBorderWidth
        }

        Rectangle {
            visible: root.showChrome
            color: "#0d0e13"
            radius: 6
            border.color: Style.panelBorder
            width: badgeText.implicitWidth + 14
            height: badgeText.implicitHeight + 8
            x: root.clamp(root.selX, Style.gap, root.width - width - Style.gap)
            y: (root.selY - height - 6 >= 0) ? root.selY - height - 6 : root.selY + 6
            Text {
                id: badgeText
                anchors.centerIn: parent
                color: Style.text
                font.family: Style.fontFamily
                font.pixelSize: Style.badgeFontSize
                text: Math.round(root.selW * root.captureScale) + " × " + Math.round(root.selH * root.captureScale)
            }
        }

        Rectangle {
            visible: root.ready && root.active && !root.hasSelection && !root.creating && ShotState.tool !== "colorpicker"
            anchors.centerIn: parent
            radius: 10
            color: Style.panel
            border.color: Style.panelBorder
            width: hintText.implicitWidth + 28
            height: hintText.implicitHeight + 18
            Text {
                id: hintText
                anchors.centerIn: parent
                color: Style.text
                font.family: Style.fontFamily
                font.pixelSize: 15
                text: "Drag over an image to crop/scan    •    Esc to cancel"
            }
        }

        MouseArea {
            id: creator
            anchors.fill: parent
            enabled: root.active && !root.hasSelection && root.ready && ShotState.tool !== "colorpicker"
            visible: enabled
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.CrossCursor
            property real ax: 0
            property real ay: 0
            onPressed: function (mouse) {
                ShotState.claimScreen(root.modelData.name);
                creator.ax = mouse.x;
                creator.ay = mouse.y;
                root.creating = true;
                root.setSel(mouse.x, mouse.y, 0, 0);
            }
            onPositionChanged: function (mouse) {
                if (root.creating)
                    root.setSelFromPoints(creator.ax, creator.ay, mouse.x, mouse.y);
            }
            onReleased: function (mouse) {
                root.creating = false;
                if (root.selW >= 8 && root.selH >= 8) {
                    root.hasSelection = true;
                } else {
                    root.setSel(0, 0, 0, 0);
                    if (root.isOwner)
                        ShotState.activeScreen = "";
                }
            }
        }

        MouseArea {
            id: mover
            enabled: root.active && root.hasSelection && ShotState.tool === "select"
            visible: enabled
            x: root.selX
            y: root.selY
            width: root.selW
            height: root.selH
            acceptedButtons: Qt.LeftButton
            preventStealing: true
            cursorShape: Qt.SizeAllCursor
            property real px: 0
            property real py: 0
            property real ox: 0
            property real oy: 0
            onPressed: function (mouse) {
                var p = mapToItem(content, mouse.x, mouse.y);
                mover.px = p.x;
                mover.py = p.y;
                mover.ox = root.selX;
                mover.oy = root.selY;
            }
            onPositionChanged: function (mouse) {
                var p = mapToItem(content, mouse.x, mouse.y);
                var nx = root.clamp(mover.ox + (p.x - mover.px), 0, root.width - root.selW);
                var ny = root.clamp(mover.oy + (p.y - mover.py), 0, root.height - root.selH);
                var dx = nx - root.selX;
                var dy = ny - root.selY;
                root.selX = nx;
                root.selY = ny;
                canvas.translateAll(dx, dy);
            }
            onReleased: {
                if (ShotState.scanMode) root.executeHighPassReveal();
            }
        }

        MouseArea {
            id: drawArea
            enabled: root.active && root.hasSelection && root.ready && ShotState.isDrawTool()
            visible: enabled
            x: root.selX
            y: root.selY
            width: root.selW
            height: root.selH
            acceptedButtons: Qt.LeftButton
            preventStealing: true
            cursorShape: Qt.CrossCursor
            onPressed: function (mouse) {
                canvas.beginDraft(root.selX + mouse.x, root.selY + mouse.y);
            }
            onPositionChanged: function (mouse) {
                canvas.updateDraft(root.clamp(root.selX + mouse.x, root.selX, root.selX + root.selW),
                                   root.clamp(root.selY + mouse.y, root.selY, root.selY + root.selH));
            }
            onReleased: function (mouse) {
                canvas.endDraft();
            }
        }

        TextInput {
            id: editor
            visible: canvas.editing !== null
            enabled: visible
            x: canvas.editing ? canvas.editing.x1 : 0
            y: canvas.editing ? canvas.editing.y1 : 0
            color: canvas.editing ? canvas.editing.color : "white"
            font.family: Style.fontFamily
            font.bold: true
            font.pixelSize: canvas.editing ? canvas.editing.fontSize : ShotState.fontSize
            selectByMouse: true
            cursorVisible: true

            onTextChanged: if (canvas.editing) canvas.editing.text = text
            onAccepted: canvas.finishEditing()
            onActiveFocusChanged: if (!activeFocus && canvas.editing) canvas.finishEditing()
            Keys.onPressed: function (e) {
                if (e.key === Qt.Key_Escape) {
                    canvas.cancelEditing();
                    e.accepted = true;
                }
            }
        }

        MouseArea {
            id: colorPickerArea
            enabled: root.active && root.ready && ShotState.tool === "colorpicker"
            visible: enabled
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.BlankCursor

            property real mouseX: 0
            property real mouseY: 0

            onPositionChanged: function (mouse) {
                mouseX = mouse.x;
                mouseY = mouse.y;
                magnifierCanvas.requestPaint();
            }

            onPressed: function (mouse) {
                mouseX = mouse.x;
                mouseY = mouse.y;
                root.pickColor(mouse.x, mouse.y);
            }
        }

        Item {
            id: magnifier
            visible: colorPickerArea.enabled && colorPickerArea.containsMouse
            x: colorPickerArea.mouseX - width / 2
            y: colorPickerArea.mouseY - height / 2
            width: 130
            height: 130
            z: 2000

            Canvas {
                id: magnifierCanvas
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var w = width;
                    var h = height;

                    ctx.beginPath();
                    ctx.arc(w / 2, h / 2, w / 2 - 2, 0, 2 * Math.PI);
                    ctx.clip();
                    ctx.imageSmoothingEnabled = false;

                    if (backdropImage.status === Image.Ready) {
                        var scale = root.captureScale;
                        var sx = (colorPickerArea.mouseX - 6.5) * scale;
                        var sy = (colorPickerArea.mouseY - 6.5) * scale;
                        var sw = 13 * scale;
                        var sh = 13 * scale;

                        ctx.drawImage(backdropImage, sx, sy, sw, sh, 0, 0, w, h);
                    } else {
                        ctx.fillStyle = "#151515";
                        ctx.fillRect(0, 0, w, h);
                    }

                    ctx.strokeStyle = "rgba(255, 255, 255, 0.25)";
                    ctx.lineWidth = 1;
                    var step = w / 13;
                    for (var i = 1; i < 13; i++) {
                        ctx.beginPath();
                        ctx.moveTo(i * step, 0); ctx.lineTo(i * step, h); ctx.stroke();
                        ctx.beginPath();
                        ctx.moveTo(0, i * step); ctx.lineTo(w, i * step); ctx.stroke();
                    }

                    var centerSize = w / 13;
                    var cx = (w - centerSize) / 2;
                    var cy = (h - centerSize) / 2;

                    ctx.strokeStyle = "white";
                    ctx.lineWidth = 1.5;
                    ctx.strokeRect(cx, cy, centerSize, centerSize);

                    ctx.strokeStyle = "black";
                    ctx.lineWidth = 1;
                    ctx.strokeRect(cx + 1, cy + 1, centerSize - 2, centerSize - 2);
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.color: Style.selectionBorder
                border.width: 3
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.color: "black"
                border.width: 1
                anchors.margins: -1
            }
        }

        Repeater {
            model: [
                { role: "tl", fx: 0,   fy: 0   },
                { role: "t",  fx: 0.5, fy: 0   },
                { role: "tr", fx: 1,   fy: 0   },
                { role: "r",  fx: 1,   fy: 0.5 },
                { role: "br", fx: 1,   fy: 1   },
                { role: "b",  fx: 0.5, fy: 1   },
                { role: "bl", fx: 0,   fy: 1   },
                { role: "l",  fx: 0,   fy: 0.5 }
            ]
            delegate: Handle {
                required property var modelData
                visible: root.showChrome && root.hasSelection && root.active && ShotState.tool === "select"
                role: modelData.role
                reference: content
                cx: root.selX + modelData.fx * root.selW
                cy: root.selY + modelData.fy * root.selH
                onMoved: function (gx, gy) { root.resizeTo(modelData.role, gx, gy); }
                onFinished: if (ShotState.scanMode) root.executeHighPassReveal()
            }
        }

        Toolbar {
            id: toolbar
            visible: root.showChrome && root.hasSelection && root.isOwner
            x: root.clamp(root.selX, Style.gap, root.width - width - Style.gap)
            y: {
                var below = root.selY + root.selH + Style.gap;
                var above = root.selY - height - Style.gap;
                if (below + height <= root.height)
                    return below;
                if (above >= 0)
                    return above;
                return root.clamp(root.selY + Style.gap, Style.gap, root.height - height - Style.gap);
            }
            onUndo: canvas.undo()
            onClearAll: canvas.clearAll()
            onCopy: root.exportRegion("copy")
            onSave: root.exportRegion("save")
            onOcr: root.exportRegion("ocr")
            onCancel: root.cancel()
        }

        Rectangle {
            id: watermarkBadge
            visible: root.ready && root.active && !root.exporting
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 16
            z: 99999

            width: 480
            height: 36
            radius: 8
            color: Style.panel
            border.color: ShotState.watermarkText.length > 0 ? (Style.selectionBorder || ShotState.strokeColor) : Style.panelBorder
            border.width: 1.5

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onPressed: function(mouse) {
                    watermarkInputField.forceActiveFocus();
                    mouse.accepted = true;
                }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "≋"
                    color: ShotState.watermarkText.length > 0 ? Style.accent : Style.text
                    font.pixelSize: 18
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 150
                    height: parent.height

                    TextInput {
                        id: watermarkInputField
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        text: ShotState.watermarkText
                        color: Style.text
                        font.family: Style.fontFamily
                        font.pixelSize: 13
                        selectByMouse: true
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Recipients (e.g. alice, bob, charlie)..."
                            color: "#6c7086"
                            font.family: Style.fontFamily
                            font.pixelSize: 13
                            visible: !watermarkInputField.text && !watermarkInputField.activeFocus
                        }

                        onTextChanged: {
                            ShotState.watermarkText = text;
                        }
                    }
                }

                Rectangle {
                    id: scanButton
                    anchors.verticalCenter: parent.verticalCenter
                    width: 86
                    height: 24
                    radius: 6
                    color: ShotState.scanMode ? "#00f0ff" : "#24273a"
                    border.color: ShotState.scanMode ? "#00f0ff" : "#494d64"
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "🔍"
                            font.pixelSize: 11
                        }
                        Text {
                            text: ShotState.scanMode ? "HIDE" : "REVEAL"
                            color: ShotState.scanMode ? "#11111b" : Style.text
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.hasSelection) {
                                root.notify("Revealer", "Select a region on your screen first.", false);
                                return;
                            }
                            ShotState.scanMode = !ShotState.scanMode;
                            if (ShotState.scanMode) {
                                root.executeHighPassReveal();
                            } else {
                                liveRevealOverlay.visible = false;
                                liveRevealOverlay.source = "";
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: Style.text
                    opacity: 0.6
                    font.pixelSize: 12
                    visible: watermarkInputField.text.length > 0

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            watermarkInputField.text = "";
                            content.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }

    // Process that waits for ImageMagick to finish before updating UI
    Process {
        id: revealProcess
        property string outPath: ""
        onExited: {
            liveRevealOverlay.source = "file://" + outPath;
            liveRevealOverlay.visible = true;
            root.activeRevealedPath = outPath;
            root.notify("🔍 REVEAL COMPLETE", "Revealed directly inside your selection box.", false);
        }
    }

    function executeHighPassReveal() {
        if (!hasSelection) return;

        // 1. Temporarily hide previous overlay so we take a clean screenshot of the screen underneath
        liveRevealOverlay.visible = false;

        var rx = Math.round(selX);
        var ry = Math.round(selY);
        var rw = Math.max(1, Math.round(selW));
        var rh = Math.max(1, Math.round(selH));
        
        exportClip.x = rx; exportClip.y = ry;
        exportClip.width = rw; exportClip.height = rh;
        captureRoot.x = -rx; captureRoot.y = -ry;
        
        exportClip.grabToImage(function (cropResult) {
            exportClip.x = 0; exportClip.y = 0;
            exportClip.width = Qt.binding(function () { return root.width; });
            exportClip.height = Qt.binding(function () { return root.height; });
            captureRoot.x = 0; captureRoot.y = 0;
            
            if (!cropResult) return;
            var ts = new Date().getTime();
            var cropPath = "/tmp/test_fingerprints/captured_" + ts + ".png";
            var outPath = "/tmp/test_fingerprints/REVEALED_" + ts + ".png";
            cropResult.saveToFile(cropPath);

            revealProcess.outPath = outPath;
            revealProcess.command = [
                "sh", "-c",
                "mkdir -p /tmp/test_fingerprints; " +
                "magick " + ShotState.shQuote(cropPath) + " -channel B -separate \\( +clone -blur 0x2 \\) -compose Subtract -composite -auto-level -define png:compression-level=1 " + ShotState.shQuote(outPath) + "; " +
                "rm -f " + ShotState.shQuote(cropPath)
            ];
            revealProcess.running = true;
        });
    }

    Timer {
        id: grabTimer
        interval: 24
        repeat: false
        onTriggered: {
            var grab = exportClip.grabToImage(function (result) {
                root.deliver(result, root._mode);
            });
            if (!grab) {
                root.abortExport();
                return;
            }
            exportWatchdog.start();
        }
    }

    Timer {
        id: exportWatchdog
        interval: 2500
        repeat: false
        onTriggered: root.abortExport()
    }

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
    function setSel(x, y, w, h) { selX = x; selY = y; selW = w; selH = h; }

    function setSelFromPoints(ax, ay, bx, by) {
        ax = clamp(ax, 0, width); bx = clamp(bx, 0, width);
        ay = clamp(ay, 0, height); by = clamp(by, 0, height);
        selX = Math.min(ax, bx);
        selY = Math.min(ay, by);
        selW = Math.abs(bx - ax);
        selH = Math.abs(by - ay);
    }

    function resizeTo(role, gx, gy) {
        gx = clamp(gx, 0, width);
        gy = clamp(gy, 0, height);
        var l = selX, t = selY, r = selX + selW, b = selY + selH;
        if (role.indexOf("l") >= 0) l = gx;
        if (role.indexOf("r") >= 0) r = gx;
        if (role.indexOf("t") >= 0) t = gy;
        if (role.indexOf("b") >= 0) b = gy;
        selX = Math.min(l, r);
        selY = Math.min(t, b);
        selW = Math.abs(r - l);
        selH = Math.abs(b - t);
    }

    function onKey(e) {
        if (watermarkInputField.activeFocus) {
            if (e.key === Qt.Key_Escape || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                content.forceActiveFocus();
                e.accepted = true;
            }
            return;
        }

        if (e.key === Qt.Key_Escape) {
            root.cancel();
            e.accepted = true;
            return;
        }
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            ShotState.copyRequested();
            e.accepted = true;
            return;
        }
        if (e.modifiers & Qt.ControlModifier) {
            if (e.key === Qt.Key_S) { ShotState.saveRequested(); e.accepted = true; }
            else if (e.key === Qt.Key_C) { ShotState.copyRequested(); e.accepted = true; }
            else if (e.key === Qt.Key_Z) { ShotState.undoRequested(); e.accepted = true; }
            else if (e.key === Qt.Key_F) { ShotState.ocrRequested(); e.accepted = true; }
            return;
        }
        var map = {};
        map[Qt.Key_V] = "select";
        map[Qt.Key_R] = "rect";
        map[Qt.Key_O] = "ellipse";
        map[Qt.Key_A] = "arrow";
        map[Qt.Key_L] = "line";
        map[Qt.Key_P] = "pen";
        map[Qt.Key_H] = "highlight";
        map[Qt.Key_T] = "text";
        map[Qt.Key_N] = "counter";
        map[Qt.Key_X] = "redact";
        map[Qt.Key_I] = "colorpicker";
        if (map[e.key] !== undefined) {
            ShotState.tool = map[e.key];
            e.accepted = true;
        }
    }

    function cancel() { Qt.quit(); }

    function exportRegion(mode) {
        if (!hasSelection || ShotState.finishing)
            return;
        ShotState.finishing = true;

        canvas.commitDraft();
        exporting = true;

        var rx = Math.round(selX);
        var ry = Math.round(selY);
        var rw = Math.max(1, Math.round(selW));
        var rh = Math.max(1, Math.round(selH));

        exportClip.x = rx;
        exportClip.y = ry;
        exportClip.width = rw;
        exportClip.height = rh;
        captureRoot.x = -rx;
        captureRoot.y = -ry;

        root._mode = mode;
        grabTimer.start();
    }

    function abortExport() {
        exportWatchdog.stop();
        exporting = false;
        ShotState.finishing = false;
        exportClip.x = 0;
        exportClip.y = 0;
        exportClip.width = Qt.binding(function () { return root.width; });
        exportClip.height = Qt.binding(function () { return root.height; });
        captureRoot.x = 0;
        captureRoot.y = 0;
        notify("Screenshot failed", "grab timed out — try again", false);
    }

    function deliver(result, mode) {
        exportWatchdog.stop();
        if (!result) {
            abortExport();
            return;
        }
        var path = (mode === "copy") ? ShotState.clipPath()
        : (mode === "save") ? ShotState.savePath()
        : (mode === "ocr") ? "/tmp/quickshot-ocr.png"
        : "/tmp/quickshot-selftest.png";

        var ok = result.saveToFile(path);
        if (ok && (mode === "copy" || mode === "save")) {
            var baseDir = ShotState.saveDir();
            var ts = ShotState.timestamp();

            // 1. If capturing while REVEAL is active: save/copy the revealed proof
            if (ShotState.scanMode && liveRevealOverlay.visible && root.activeRevealedPath.length > 0) {
                var proofPath = baseDir + "/quickshot_" + ts + "_REVEALED.png";
                var proofCmd = "mkdir -p " + ShotState.shQuote(baseDir) + "; mkdir -p /tmp/clipboard_thumbnails; " +
                               "cp -f " + ShotState.shQuote(root.activeRevealedPath) + " " + ShotState.shQuote(proofPath) + "; " +
                               "cliphist store < " + ShotState.shQuote(proofPath) + "; " +
                               "cid=$(cliphist list | head -n 1 | cut -f1); " +
                               "chash=$(md5sum " + ShotState.shQuote(proofPath) + " | cut -d' ' -f1); " +
                               "echo 'REVEALED' > /tmp/clipboard_thumbnails/quickshell_clip_label_${cid}.txt; " +
                               "echo 'REVEALED' > /tmp/clipboard_thumbnails/label_${chash}.txt; ";

                var proofAction = (mode === "copy")
                    ? ("wl-copy --type image/png < " + ShotState.shQuote(proofPath) + " && notify-send -a Quickshot 'Revealed Proof Copied' 'Stored on clipboard as [Image: REVEALED]'; ")
                    : ("notify-send -a Quickshot 'Revealed Proof Saved' " + ShotState.shQuote(proofPath) + "; ");

                Quickshell.execDetached(["sh", "-c", proofCmd + proofAction]);
                Qt.quit();
                return;
            }

            // 2. Standard watermarking pipeline with immutable MD5 hash labeling
            var rawText = ShotState.watermarkText ? ShotState.watermarkText.trim() : "";
            var names = rawText.split(",").map(function(s) { return s.trim(); }).filter(function(s) { return s.length > 0; });

            if (names.length > 1) {
                var batchPids = "mkdir -p " + ShotState.shQuote(baseDir) + "; mkdir -p /tmp/clipboard_thumbnails; ";
                var firstSavedPath = "";

                for (var i = names.length - 1; i >= 0; i--) {
                    var target = names[i];
                    var safeTarget = target.replace(/[^a-zA-Z0-9_\-]/g, "_");
                    var outPath = baseDir + "/quickshot_" + ts + "_" + safeTarget + ".png";
                    if (i === 0) firstSavedPath = outPath;

                    batchPids += "magick " + ShotState.shQuote(path) + " " +
                                 "\\( -size 240x220 xc:none -fill 'rgba(100, 0, 255, 0.008)' " +
                                 "-font 'Liberation-Sans-Bold' -pointsize 20 -gravity Center " +
                                 "-annotate +0+0 " + ShotState.shQuote(target) + " " +
                                 "-distort ScaleRotateTranslate 30 -write mpr:text +delete \\) " +
                                 "\\( +clone -tile mpr:text -draw 'color 0,0 reset' \\) " +
                                 "-compose Over -composite -define png:compression-level=1 " + ShotState.shQuote(outPath) + "; " +
                                 "cliphist store < " + ShotState.shQuote(outPath) + "; " +
                                 "cid=$(cliphist list | head -n 1 | cut -f1); " +
                                 "chash=$(md5sum " + ShotState.shQuote(outPath) + " | cut -d' ' -f1); " +
                                 "echo " + ShotState.shQuote(target) + " > /tmp/clipboard_thumbnails/quickshell_clip_label_${cid}.txt; " +
                                 "echo " + ShotState.shQuote(target) + " > /tmp/clipboard_thumbnails/label_${chash}.txt; ";
                }

                var copyAction = "";
                if (mode === "copy" && firstSavedPath.length > 0) {
                    copyAction = "wl-copy --type image/png < " + ShotState.shQuote(firstSavedPath) + "; " +
                                 "sleep 0.15; " +
                                 "topId=$(cliphist list | head -n 1 | cut -f1); " +
                                 "firstHash=$(md5sum " + ShotState.shQuote(firstSavedPath) + " | cut -d' ' -f1); " +
                                 "echo " + ShotState.shQuote(names[0]) + " > /tmp/clipboard_thumbnails/quickshell_clip_label_${topId}.txt; " +
                                 "echo " + ShotState.shQuote(names[0]) + " > /tmp/clipboard_thumbnails/label_${firstHash}.txt; ";
                }

                var batchNotify = "notify-send -a Quickshot 'Batch Watermarked (" + names.length + " copies)' " + ShotState.shQuote("Stored in clipboard & ~/Screenshots for: " + names.join(", "));
                Quickshell.execDetached(["sh", "-c", batchPids + copyAction + batchNotify]);
            } else if (names.length === 1) {
                var singleName = names[0];
                var embedCmd = "mkdir -p /tmp/clipboard_thumbnails; " +
                               "magick " + ShotState.shQuote(path) + " " +
                               "\\( -size 240x220 xc:none -fill 'rgba(100, 0, 255, 0.008)' " +
                               "-font 'Liberation-Sans-Bold' -pointsize 20 -gravity Center " +
                               "-annotate +0+0 " + ShotState.shQuote(singleName) + " " +
                               "-distort ScaleRotateTranslate 30 -write mpr:text +delete \\) " +
                               "\\( +clone -tile mpr:text -draw 'color 0,0 reset' \\) " +
                               "-compose Over -composite -define png:compression-level=1 " + ShotState.shQuote(path) + "; " +
                               "cliphist store < " + ShotState.shQuote(path) + "; " +
                               "cid=$(cliphist list | head -n 1 | cut -f1); " +
                               "chash=$(md5sum " + ShotState.shQuote(path) + " | cut -d' ' -f1); " +
                               "echo " + ShotState.shQuote(singleName) + " > /tmp/clipboard_thumbnails/quickshell_clip_label_${cid}.txt; " +
                               "echo " + ShotState.shQuote(singleName) + " > /tmp/clipboard_thumbnails/label_${chash}.txt; ";

                var actionCmd = (mode === "copy")
                    ? ("wl-copy --type image/png < " + ShotState.shQuote(path) + "; " +
                       "sleep 0.15; " +
                       "topId=$(cliphist list | head -n 1 | cut -f1); " +
                       "echo " + ShotState.shQuote(singleName) + " > /tmp/clipboard_thumbnails/quickshell_clip_label_${topId}.txt; " +
                       "notify-send -a Quickshot 'Copied to clipboard' 'Watermark: " + singleName + "'")
                    : ("notify-send -a Quickshot 'Screenshot saved' " + ShotState.shQuote(path));

                Quickshell.execDetached(["sh", "-c", embedCmd + actionCmd]);
            } else {
                var cleanCmd = (mode === "copy")
                    ? ("wl-copy --type image/png < " + ShotState.shQuote(path) + " && notify-send -a Quickshot 'Copied to clipboard' " + ShotState.shQuote(path))
                    : ("notify-send -a Quickshot 'Screenshot saved' " + ShotState.shQuote(path));
                Quickshell.execDetached(["sh", "-c", cleanCmd]);
            }
        } else if (ok && mode === "ocr") {
            var ocrCmd = [
                "sh", "-c",
                "text=$(tesseract " + ShotState.shQuote(path) + " stdout 2>/dev/null); if [ -n \"$text\" ]; then printf \"%s\" \"$text\" | wl-copy; notify-send -a Quickshot 'Text Copied' \"$text\"; fi; rm -f " + ShotState.shQuote(path)
            ];
            Quickshell.execDetached(ocrCmd);
        }
        Qt.quit();
    }

    function notify(summary, body, withIcon) {
        Quickshell.execDetached([
            "notify-send", "-a", "Quickshot",
            "-i", withIcon ? "image-x-generic" : "dialog-information",
            summary, body
        ]);
    }

    function pickColor(x, y) {
        colorSamplerSource.grabToImage(function (result) {
            if (!result) return;

            var tempPath = "/tmp/quickshot_pixel.png";
            result.saveToFile(tempPath);

            var cacheBuster = "?t=" + new Date().getTime();
            colorCanvas.sample("file://" + tempPath + cacheBuster, function (rgba) {
                var r = rgba[0];
                var g = rgba[1];
                var b = rgba[2];

                var hex = rgbToHex(r, g, b);
                var rgbStr = "rgb(" + r + ", " + g + ", " + b + ")";

                ShotState.strokeColor = hex;
                notifyColor(hex, rgbStr);

                Quickshell.execDetached(["rm", "-f", tempPath]);
                ShotState.tool = "select";
            });
        });
    }

    function rgbToHex(r, g, b) {
        var toHex = function (c) {
            var hex = c.toString(16);
            return hex.length === 1 ? "0" + hex : hex;
        };
        return "#" + toHex(r) + toHex(g) + toHex(b);
    }

    function notifyColor(hex, rgbStr) {
        var cleanHex = hex.replace("#", "");
        var iconPath = "/tmp/qs_color_icon_" + cleanHex + ".svg";
        var svgContent = '<svg width="64" height="64" xmlns="http://www.w3.org/2000/svg"><rect width="64" height="64" fill="' + hex + '" rx="8"/></svg>';

        var title = "Color Picked";
        var body = hex + "  •  " + rgbStr;

        var cmd = [
            "sh", "-c",
            "echo -n " + ShotState.shQuote(hex) + " | wl-copy && " +
            "echo " + ShotState.shQuote(svgContent) + " > " + ShotState.shQuote(iconPath) + " && " +
            "notify-send -a Quickshot -u critical -i " + ShotState.shQuote(iconPath) + " " + ShotState.shQuote(title) + " " + ShotState.shQuote(body)
        ];

        Quickshell.execDetached(cmd);
    }

    Item {
        id: colorSamplerItem
        x: 0
        y: 0
        width: 1
        height: 1
        visible: true
        opacity: 0.01

        ShaderEffectSource {
            id: colorSamplerSource
            anchors.fill: parent
            sourceItem: captureRoot
            live: true
            smooth: false
            sourceRect: Qt.rect(colorPickerArea.mouseX, colorPickerArea.mouseY, 1, 1)
        }
    }

    Canvas {
        id: colorCanvas
        x: 0
        y: 0
        width: 1
        height: 1
        visible: true
        opacity: 0.01

        property var callback: null
        property string currentUrl: ""
        onImageLoaded: {
            var ctx = getContext("2d");
            ctx.drawImage(colorCanvas.currentUrl, 0, 0);
            var imgData = ctx.getImageData(0, 0, 1, 1);
            if (callback) {
                callback(imgData.data);
                callback = null;
            }
            unloadImage(colorCanvas.currentUrl);
        }
        function sample(url, cb) {
            callback = cb;
            currentUrl = url;
            if (isImageLoaded(url)) {
                var ctx = getContext("2d");
                ctx.drawImage(url, 0, 0);
                var imgData = ctx.getImageData(0, 0, 1, 1);
                if (callback) {
                    callback(imgData.data);
                    callback = null;
                }
                unloadImage(url);
            } else {
                loadImage(url);
            }
        }
    }

    function runSelfTest() {
        if (!ShotState.ownsSelection(modelData.name))
            return;
        ShotState.claimScreen(modelData.name);
        if (!isOwner || ShotState.finishing)
            return;

        setSel(80, 80, Math.min(520, width - 160), Math.min(360, height - 160));
        hasSelection = true;

        if (selfTestMode === "2") {
            gestureStroke("rect", 110, 110, 320, 230);
            gestureStroke("highlight", 130, 300, 360, 345);
            ShotState.tool = "counter"; canvas.beginDraft(170, 165); canvas.endDraft();
            ShotState.tool = "counter"; canvas.beginDraft(240, 200); canvas.endDraft();
            gestureStroke("ellipse", 360, 120, 540, 250);
            gestureStroke("arrow", 140, 270, 430, 360);

            var dx = 90, dy = 60;
            setSel(selX + dx, selY + dy, selW, selH);
            canvas.translateAll(dx, dy);
            runSelfTestExport();
            return;
        }

        canvas.annotations = [
            { type: "rect",     x1: 110, y1: 110, x2: 320, y2: 230, color: "#ff453a", width: 4 },
            { type: "ellipse",  x1: 340, y1: 120, x2: 540, y2: 250, color: "#32d74b", width: 4 },
            { type: "arrow",    x1: 130, y1: 270, x2: 430, y2: 380, color: "#0a84ff", width: 5 },
            { type: "line",     x1: 120, y1: 120, x2: 300, y2: 200, color: "#ffd60a", width: 3 },
            { type: "highlight",x1: 150, y1: 320, x2: 360, y2: 360, color: "#ffd60a", width: 4 },
            { type: "pen",      points: [{x:400,y:300},{x:430,y:330},{x:460,y:300},{x:490,y:340}], color: "#ffffff", width: 4 },
            { type: "counter",  x1: 150, y1: 150, color: "#5e5ce6", number: 1, fontSize: 26 },
            { type: "text",     x1: 170, y1: 250, text: "Quickshot", color: "#ffd60a", fontSize: 28 },
            { type: "redact",   x1: 380, y1: 270, x2: 540, y2: 380 }
        ];

        runSelfTestExport();
    }

    function gestureStroke(tool, x1, y1, x2, y2) {
        ShotState.tool = tool;
        canvas.beginDraft(x1, y1);
        canvas.updateDraft((x1 + x2) / 2, (y1 + y2) / 2);
        canvas.updateDraft(x2, y2);
        canvas.endDraft();
    }

    function runSelfTestExport() {
        ShotState.finishing = true;
        canvas.commitDraft();
        exporting = true;
        var rx = Math.round(selX), ry = Math.round(selY);
        var rw = Math.max(1, Math.round(selW)), rh = Math.max(1, Math.round(selH));
        exportClip.x = rx; exportClip.y = ry;
        exportClip.width = rw; exportClip.height = rh;
        captureRoot.x = -rx; captureRoot.y = -ry;
        root._mode = "selftest";
        grabTimer.start();
    }
}
