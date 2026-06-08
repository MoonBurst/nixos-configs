import Quickshell
import Quickshell.Wayland
import QtQuick

// A full-screen, click-through-free overlay for a single monitor. It freezes the
// screen with a ScreencopyView, lets the user rubber-band a region, annotate it,
// and then copies or saves the cropped result.
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

    // ---- Selection state (overlay-local logical coordinates) -----------------
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0
    property bool hasSelection: false
    property bool creating: false
    property bool exporting: false

    readonly property bool ready: shot.hasContent
    // Headless end-to-end validation hook (QUICKSHOT_SELFTEST=1): scripts a
    // selection + annotations + export so the whole pipeline can be checked.
    readonly property string selfTestMode: {
        var v = Quickshell.env("QUICKSHOT_SELFTEST");
        return v ? String(v) : "";
    }
    readonly property bool selfTest: selfTestMode === "1" || selfTestMode === "2"
    onReadyChanged: if (ready && selfTest) Qt.callLater(runSelfTest)
    // True unless another monitor has already claimed the selection.
    readonly property bool active: ShotState.ownsSelection(modelData.name)
    // True only on the monitor that actually owns the selection.
    readonly property bool isOwner: ShotState.activeScreen === modelData.name
    readonly property bool showChrome: ready && !exporting && (creating || hasSelection)
    // Logical -> native pixel ratio, used to report/export at full resolution.
    readonly property real captureScale: shot.sourceSize.width > 0
                                         ? shot.sourceSize.width / Math.max(1, width) : 1

    // Pending grab mode ("copy" | "save" | "selftest").
    property string _mode: ""

    // Route global key shortcuts to whichever overlay owns the selection.
    Connections {
        target: ShotState
        function onCopyRequested() { if (root.isOwner) root.exportRegion("copy"); }
        function onSaveRequested() { if (root.isOwner) root.exportRegion("save"); }
        function onUndoRequested() { if (root.isOwner) canvas.undo(); }
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: function (event) { root.onKey(event); }

        // 1. Exportable scene: frozen screenshot + annotations. Only this subtree
        //    is captured by grabToImage; everything below is selection chrome.
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
                    // live:false captures exactly one frozen frame. The context
                    // auto-captures when it becomes ready, so we must NOT call
                    // captureFrame() before then (it would only warn). The
                    // fallback Timer below re-requests if that frame never lands.
                    live: false
                    paintCursor: false
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

        // Keep requesting a frame until the compositor delivers one.
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

        // 2. Dimming veil — four rectangles tiled around the selection so the
        //    selected region stays at full brightness. With no selection the
        //    bottom rectangle covers the whole screen.
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

        // 3. Selection outline.
        Rectangle {
            visible: root.showChrome
            x: root.selX
            y: root.selY
            width: root.selW
            height: root.selH
            color: "transparent"
            border.color: Style.selectionBorder
            border.width: Style.selectionBorderWidth
        }

        // 4. Dimension badge.
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

        // 5. Pre-selection hint.
        Rectangle {
            visible: root.ready && root.active && !root.hasSelection && !root.creating
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
                text: "Drag to select a region    •    Esc to cancel"
            }
        }

        // 6. Region creation (rubber band) — active before a selection exists.
        MouseArea {
            id: creator
            anchors.fill: parent
            enabled: root.active && !root.hasSelection && root.ready
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

        // 7. Move the selection (select tool only).
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
                // Annotations travel with the selection.
                canvas.translateAll(dx, dy);
            }
        }

        // 8. Draw annotations (any draw tool).
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

        // 8b. Inline text editor. Declared after drawArea so it hit-tests above
        //     it — clicks on the text box reach the editor (caret/selection),
        //     while clicks elsewhere in the selection still start a new box.
        //     It is outside the captured subtree, so the live editor is never
        //     part of the exported image (the committed Text annotation is).
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

        // 9. Resize handles (select tool only).
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

        // 10. Toolbar.
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
            onCancel: root.cancel()
        }
    }

    // ---- Deferred grab -------------------------------------------------------
    Timer {
        id: grabTimer
        interval: 24
        repeat: false
        onTriggered: {
            // No explicit targetSize: Qt renders the item's logical size scaled
            // by the window's devicePixelRatio, which equals the ScreencopyView's
            // native texture resolution — a crisp, correctly-sized native crop.
            // Passing a native-px targetSize would double-apply the DPR.
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

    // Safety net: if the grab callback never fires, recover instead of hanging.
    Timer {
        id: exportWatchdog
        interval: 2500
        repeat: false
        onTriggered: root.abortExport()
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
        map[Qt.Key_X] = "pixelate";
        if (map[e.key] !== undefined) {
            ShotState.tool = map[e.key];
            e.accepted = true;
        }
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

        // Reframe the clip to the selection and shift the scene up/left so the
        // region aligns to the clip's origin (single-grab crop).
        exportClip.x = rx;
        exportClip.y = ry;
        exportClip.width = rw;
        exportClip.height = rh;
        captureRoot.x = -rx;
        captureRoot.y = -ry;

        root._mode = mode;
        grabTimer.start();
    }

    // Restore the live state after a failed/aborted grab so the user can retry.
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
                 : "/tmp/quickshot-selftest.png";
        var ok = result.saveToFile(path);
        if (ok && mode === "copy") {
            Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < " + ShotState.shQuote(path)]);
            notify("Copied to clipboard", path, false);
        } else if (ok && mode === "save") {
            notify("Screenshot saved", path, true);
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

    // ---- Self-test (headless validation) -------------------------------------
    function runSelfTest() {
        // Only the first monitor to become ready drives the test.
        if (!ShotState.ownsSelection(modelData.name))
            return;
        ShotState.claimScreen(modelData.name);
        if (!isOwner || ShotState.finishing)
            return;

        setSel(80, 80, Math.min(520, width - 160), Math.min(360, height - 160));
        hasSelection = true;

        if (selfTestMode === "2") {
            // Drive the real interactive draft path for the tools reported broken.
            gestureStroke("rect", 110, 110, 320, 230);
            gestureStroke("highlight", 130, 300, 360, 345);
            ShotState.tool = "counter"; canvas.beginDraft(170, 165); canvas.endDraft();
            ShotState.tool = "counter"; canvas.beginDraft(240, 200); canvas.endDraft();
            gestureStroke("ellipse", 360, 120, 540, 250);
            gestureStroke("arrow", 140, 270, 430, 360);
            // Exercise the move path: shift the selection and the annotations
            // together. If they travel as one, the crop frames them identically.
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
            { type: "pixelate", x1: 380, y1: 270, x2: 540, y2: 380 }
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
