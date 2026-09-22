import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// A full-screen overlay with rubber-band selection, annotation tools,
// faint watermarking, a Dual-Stage GPU Binary Contrast Scanner, and
// automatic microdot watermark detection on the selected region.
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

    // Restart the debounced watermark scan whenever the selection settles
    // into a new position/size (created, dragged, or resized). Debounced
    // rather than run every frame, so dragging doesn't spam decode attempts.
    onSelXChanged: root._restartWatermarkScan()
    onSelYChanged: root._restartWatermarkScan()
    onSelWChanged: root._restartWatermarkScan()
    onSelHChanged: root._restartWatermarkScan()

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

    // Route global shortcuts
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

        // 1. Exportable scene
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

                // ---- Dual-Stage Real-Time GPU Binary Contrast Scanner ----
                // Stage 1: Crop & pivot contrast around background threshold
                ShaderEffectSource {
                    id: stage1Source
                    sourceItem: shot
                    sourceRect: Qt.rect(root.selX, root.selY, Math.max(1, root.selW), Math.max(1, root.selH))
                    visible: false
                    live: true
                }

                MultiEffect {
                    id: stage1Effect
                    width: Math.max(1, root.selW)
                    height: Math.max(1, root.selH)
                    visible: false // Internal texture pipeline to Stage 2

                    source: stage1Source
                    contrast: 0.88
                    saturation: -1.0
                    brightness: ShotState.scanThreshold
                }

                // Stage 2: Binary hard clipper (slams subtle shifts into crisp solid black & white)
                ShaderEffectSource {
                    id: stage2Source
                    sourceItem: stage1Effect
                    visible: false
                    live: true
                }

                MultiEffect {
                    id: realTimeScanEffect
                    x: root.selX
                    y: root.selY
                    width: Math.max(1, root.selW)
                    height: Math.max(1, root.selH)
                    visible: ShotState.scanMode && root.hasSelection

                    source: stage2Source
                    contrast: 0.96   // Extreme binary contrast cutoff
                    brightness: 0.0
                }

                AnnotationCanvas {
                    id: canvas
                    anchors.fill: parent
                    backdrop: shot
                    onEditFinished: content.forceActiveFocus()
                    onEditStarted: {
                        editor.text = "";
                        editor.forceActiveFocus();
                    }
                }
            }
        }

        // Keep requesting frame until delivered
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

        // 2. Dimming veil
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

        // 3. Selection outline
        Rectangle {
            visible: root.showChrome
            x: root.selX
            y: root.selY
            width: root.selW
            height: root.selH
            color: "transparent"
            border.color: ShotState.scanMode ? "#ff007f" : Style.selectionBorder
            border.width: Style.selectionBorderWidth
        }

        // 4. Dimension badge
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

        // 5. Pre-selection hint
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
                text: "Drag over an image to scan it    •    Esc to cancel"
            }
        }

        // 6. Region creation
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

        // 7. Move the selection
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
        }

        // 8. Draw annotations
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

        // 8b. Inline text editor
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

        // 8c. Color Picker Area
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

        // 8d. Magnifier Loupe Bubble
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

        // 9. Resize handles
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
            }
        }

        // 10. Toolbar
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

        // 11. Persistent Watermark & Dual-Stage Real-Time Scanner Bar
        Rectangle {
            id: watermarkBadge
            visible: root.ready && root.active && !root.exporting
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 16
            z: 99999

            width: ShotState.scanMode ? 560 : 420
            height: 36
            radius: 8
            color: Style.panel
            border.color: ShotState.scanMode ? "#ff007f" : (ShotState.watermarkText.length > 0 ? (Style.selectionBorder || ShotState.strokeColor) : Style.panelBorder)
            border.width: 1.5

            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

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
                    color: ShotState.watermarkText.length > 0 ? (Style.selectionBorder || ShotState.strokeColor) : Style.text
                    font.pixelSize: 15
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: ShotState.scanMode ? 140 : (parent.width - 200)
                    height: parent.height
                    clip: true

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
                            text: "Secret watermark..."
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

                // Eye Preview Toggle
                Rectangle {
                    id: revealSwitch
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 22
                    radius: 11
                    color: ShotState.revealWatermark ? ShotState.strokeColor : "#313244"

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: ShotState.revealWatermark ? parent.width - width - 2 : 2
                        width: 18
                        height: 18
                        radius: 9
                        color: "#ffffff"

                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                        Text {
                            anchors.centerIn: parent
                            text: "👁"
                            font.pixelSize: 10
                            color: ShotState.revealWatermark ? "#11111b" : "#6c7086"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShotState.revealWatermark = !ShotState.revealWatermark
                    }
                }

                // Instant Real-Time Dual-Stage Contrast Scanner Button
                Rectangle {
                    id: scanButton
                    anchors.verticalCenter: parent.verticalCenter
                    width: 76
                    height: 24
                    radius: 6
                    color: ShotState.scanMode ? "#ff007f" : "#24273a"
                    border.color: ShotState.scanMode ? "#ff007f" : "#494d64"
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "🔬"
                            font.pixelSize: 11
                        }
                        Text {
                            text: ShotState.scanMode ? "BOOST ON" : "SCAN"
                            color: ShotState.scanMode ? "#ffffff" : Style.text
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.hasSelection) {
                                root.notify("Scanner", "Drag a box around an image on your screen first.", false);
                                return;
                            }
                            ShotState.scanMode = !ShotState.scanMode;
                        }
                    }
                }

                // ---- Real-Time Contrast Pivot Controls (Active in SCAN MODE) ----
                Row {
                    visible: ShotState.scanMode
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter

                    // Dark background preset (e.g. Discord, terminal, dark editor)
                    Rectangle {
                        width: 44
                        height: 22
                        radius: 4
                        color: ShotState.scanThreshold > 0.1 ? "#ff007f" : "#313244"
                        Text {
                            anchors.centerIn: parent
                            text: "DARK"
                            color: "#ffffff"
                            font.pixelSize: 9
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ShotState.scanThreshold = 0.38
                        }
                    }

                    // Light background preset (e.g. white web pages, documents)
                    Rectangle {
                        width: 44
                        height: 22
                        radius: 4
                        color: ShotState.scanThreshold < -0.1 ? "#ff007f" : "#313244"
                        Text {
                            anchors.centerIn: parent
                            text: "LIGHT"
                            color: "#ffffff"
                            font.pixelSize: 9
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ShotState.scanThreshold = -0.38
                        }
                    }

                    // Smooth Threshold Scrubber Track
                    Rectangle {
                        id: scrubberTrack
                        width: 65
                        height: 12
                        radius: 6
                        color: "#181825"
                        border.color: "#45475a"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            id: scrubberHandle
                            width: 12
                            height: 12
                            radius: 6
                            color: "#ffffff"
                            x: Math.max(0, Math.min(scrubberTrack.width - width, (scrubberTrack.width - width) * ((ShotState.scanThreshold + 0.8) / 1.6)))

                            MouseArea {
                                anchors.fill: parent
                                drag.target: parent
                                drag.axis: Drag.XAxis
                                drag.minimumX: 0
                                drag.maximumX: scrubberTrack.width - scrubberHandle.width
                                onPositionChanged: {
                                    var progress = scrubberHandle.x / (scrubberTrack.width - scrubberHandle.width);
                                    ShotState.scanThreshold = -0.8 + progress * 1.6;
                                }
                            }
                        }
                    }
                }

                // Clear button
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

    // ---- Deferred grab -------------------------------------------------------
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

    // ---- Automatic microdot watermark scanning --------------------------------
    // Whenever the selection settles (created, moved, or resized -- see the
    // onSelXChanged/onSelYChanged/onSelWChanged/onSelHChanged handlers up
    // top), we grab the RAW captured screen (`shot`, not captureRoot -- see
    // note below) under the selection, look for the microdot pattern, and
    // fire a notify-send if a watermark checksum validates. Fully in-process:
    // no external script or separate run needed.
    //
    // Deliberately grabs `shot` rather than `captureRoot`: captureRoot also
    // contains this session's own AnnotationCanvas, including its own live
    // watermarkLayer (if you've typed a watermark to embed in THIS export).
    // Grabbing captureRoot would blend your own outgoing watermark into the
    // pixels you're trying to decode. `shot` is just the frozen screen
    // capture, so it only reflects what was actually on screen already.

    property string _lastWatermarkText: ""

    Timer {
        id: watermarkScanTimer
        interval: 450
        repeat: false
        onTriggered: root.scanSelectionForWatermark()
    }

    function _restartWatermarkScan() {
        if (root.hasSelection && !root.exporting && root.ready)
            watermarkScanTimer.restart();
    }

    Image {
        id: decodeBackdropImage
        visible: false
        cache: false
        onStatusChanged: if (status === Image.Ready) root._runWatermarkDecode()
    }

    Canvas {
        id: decodeCanvas
        visible: false
        width: 1
        height: 1
    }

    function scanSelectionForWatermark() {
        if (!hasSelection || exporting || selW < ShotState.wmDotPitch * 4 || selH < ShotState.wmDotPitch * 4)
            return;
        // Cap the decode region in device pixels so a huge selection can't
        // stall the UI thread -- this feature is for scanning an on-screen
        // image, not the whole desktop.
        var capPx = 1400;
        if (selW * captureScale > capPx || selH * captureScale > capPx)
            return;

        shot.grabToImage(function (result) {
            if (!result)
                return;
            var path = "/tmp/quickshot-wm-decode.png";
            result.saveToFile(path);
            decodeBackdropImage.source = "file://" + path + "?t=" + new Date().getTime();
        });
    }

    function _runWatermarkDecode() {
        var scale = root.captureScale;
        var sx = Math.round(root.selX * scale);
        var sy = Math.round(root.selY * scale);
        var sw = Math.max(1, Math.round(root.selW * scale));
        var sh = Math.max(1, Math.round(root.selH * scale));

        decodeCanvas.width = sw;
        decodeCanvas.height = sh;
        var ctx = decodeCanvas.getContext("2d");
        ctx.reset();
        ctx.imageSmoothingEnabled = false;
        ctx.drawImage(decodeBackdropImage, sx, sy, sw, sh, 0, 0, sw, sh);

        var imageData;
        try {
            imageData = ctx.getImageData(0, 0, sw, sh);
        } catch (e) {
            return;
        }

        var text = root._decodeMicrodots(imageData.data, sw, sh);
        if (text && text !== root._lastWatermarkText) {
            root._lastWatermarkText = text;
            root.notifyWatermarkMatch(text);
        } else if (!text) {
            // Selection moved off the marked region -- allow re-notifying
            // if the same recipient turns up again later (e.g. after
            // panning the selection back over it).
            root._lastWatermarkText = "";
        }
    }

    // Brute-forces every grid phase, averages luminance per tile-cell across
    // every tile repeat + every occurrence of that cell in the selection,
    // and tries to decode+validate at each phase. Mirrors decode_watermark.py.
    function _decodeMicrodots(data, w, h) {
        var pitch = ShotState.wmDotPitch;
        var cols = ShotState.wmTileCols;
        var rows = ShotState.wmTileRows;
        var bitCount = ShotState.wmBitCount;

        var best = null;
        var bestSpread = 0;

        for (var py = 0; py < pitch; py++) {
            for (var px = 0; px < pitch; px++) {
                var sums = new Float64Array(bitCount);
                var counts = new Int32Array(bitCount);

                for (var y = py, gy = 0; y < h; y += pitch, gy++) {
                    var row = gy % rows;
                    var base = row * cols;
                    for (var x = px, gx = 0; x < w; x += pitch, gx++) {
                        var idx = base + (gx % cols);
                        var p = (y * w + x) * 4;
                        var lum = 0.299 * data[p] + 0.587 * data[p + 1] + 0.114 * data[p + 2];
                        sums[idx] += lum;
                        counts[idx] += 1;
                    }
                }

                var means = new Float64Array(bitCount);
                var minV = Infinity, maxV = -Infinity;
                for (var i = 0; i < bitCount; i++) {
                    var c = counts[i] || 1;
                    means[i] = sums[i] / c;
                    if (means[i] < minV) minV = means[i];
                    if (means[i] > maxV) maxV = means[i];
                }
                var spread = maxV - minV;
                if (spread < 2.0)
                    continue; // essentially flat -- no pattern at this phase

                var threshold = (maxV + minV) / 2.0;
                var bits = new Array(bitCount);
                for (var b = 0; b < bitCount; b++)
                    bits[b] = means[b] < threshold ? 1 : 0; // dots render darker

                var text = root._bitsToText(bits);
                if (text !== null && spread > bestSpread) {
                    best = text;
                    bestSpread = spread;
                }
            }
        }
        return best;
    }

    function _bitsToText(bits) {
        var sync = ShotState.wmSyncNibble;
        for (var i = 0; i < 4; i++)
            if (bits[i] !== sync[i]) return null;

        var length = 0;
        for (var j = 4; j < 8; j++)
            length = (length << 1) | bits[j];
        if (length < 0 || length > 7)
            return null;

        var payloadStart = 8;
        var payloadEnd = payloadStart + 8 * length;
        if (payloadEnd + 8 > bits.length)
            return null;

        var bytes = [];
        for (var k = 0; k < length; k++) {
            var byte = 0;
            for (var b2 = 0; b2 < 8; b2++)
                byte = (byte << 1) | bits[payloadStart + k * 8 + b2];
            bytes.push(byte);
        }

        var checksum = 0;
        for (var b3 = 0; b3 < 8; b3++)
            checksum = (checksum << 1) | bits[payloadEnd + b3];

        var sum = 0;
        for (var m = 0; m < bytes.length; m++)
            sum = (sum + bytes[m]) & 0xff;
        if (sum !== checksum)
            return null;

        var str = "";
        for (var n = 0; n < bytes.length; n++) {
            if (bytes[n] < 32 || bytes[n] > 126)
                return null; // not printable ASCII -- reject as a false positive
            str += String.fromCharCode(bytes[n]);
        }
        return str;
    }

    function notifyWatermarkMatch(text) {
        Quickshell.execDetached([
            "notify-send", "-a", "Quickshot", "-u", "critical",
            "-i", "dialog-warning",
            "Watermark detected",
            "This region was watermarked for: " + text
        ]);
    }

    // ---- Geometry helpers ----------------------------------------------------
    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    function setSel(x, y, w, h) {
        selX = x; selY = y; selW = w; selH = h;
    }

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

    // ---- Keyboard ------------------------------------------------------------
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

    function cancel() {
        Qt.quit();
    }

    // ---- Export --------------------------------------------------------------
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
        if (ok && mode === "copy") {
            Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < " + ShotState.shQuote(path)]);
            notify("Copied to clipboard", path, false);
        } else if (ok && mode === "save") {
            notify("Screenshot saved", path, true);
        } else if (ok && mode === "ocr") {
            var ocrCmd = [
                "sh", "-c",
                "if ! command -v tesseract >/dev/null 2>&1; then " +
                "  notify-send -a Quickshot \"OCR Error\" \"Tesseract is not installed.\"; " +
                "  rm -f " + ShotState.shQuote(path) + "; " +
                "  exit 1; " +
                "fi; " +
                "if ! command -v wl-copy >/dev/null 2>&1; then " +
                "  notify-send -a Quickshot \"OCR Error\" \"wl-copy is not installed.\"; " +
                "  rm -f " + ShotState.shQuote(path) + "; " +
                "  exit 1; " +
                "fi; " +
                "text=$(tesseract " + ShotState.shQuote(path) + " stdout 2>/dev/null | tr -d '\\f' | sed '/./,$!d'); " +
                "if [ -n \"$text\" ]; then " +
                "  printf \"%s\" \"$text\" | wl-copy; " +
                "  notify-send -a Quickshot \"Text Copied\" \"$text\"; " +
                "else " +
                "  notify-send -a Quickshot \"OCR Failed\" \"No text found in the selected region.\"; " +
                "fi; " +
                "rm -f " + ShotState.shQuote(path)
            ];
            Quickshell.execDetached(ocrCmd);
        }
        Qt.quit();
    }

    function notify(summary, path, withFile) {
        Quickshell.execDetached([
            "notify-send", "-a", "Quickshot",
            "-i", withFile ? path : "image-x-generic",
            summary, path
        ]);
    }

    // ---- Color picking logic -------------------------------------------------
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

    // ---- Self-test -----------------------------------------------------------
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
