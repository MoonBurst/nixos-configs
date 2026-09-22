import QtQuick

// Owns the annotation model and the in-progress draft, and renders both on top
// of the frozen screenshot.
Item {
    id: canvas

    property var annotations: []
    property var draft: null
    property Item backdrop: null
    property var editing: null

    property var _penPoints: null

    signal editStarted()
    signal editFinished()

    // ---- Repeating Microdot Watermark Layer (Pure QML) ----------------------
    //
    // Encodes ShotState.watermarkText as a grid of dots tiled edge-to-edge
    // across the canvas, instead of human-readable tiled text. A human sees
    // faint noise (or nothing); overlay.qml's automatic scan-on-selection
    // recovers the text from a captured screenshot, and the standalone
    // decode_watermark.py can do the same for an already-exported file.
    //
    // Bit layout: see the comment above ShotState's wm* properties, which
    // this layer reads its pitch/tile size/sync marker from, so the encoder
    // here and the decoder in overlay.qml can never drift out of sync.
    Item {
        id: watermarkLayer
        anchors.fill: parent
        z: -1 // Sits behind drawn annotations
        clip: true
        enabled: false // Never intercepts mouse gestures

        visible: Boolean(ShotState.watermarkText && ShotState.watermarkText.trim().length > 0)

        // High-visibility, larger, outlined dots when the preview switch is
        // ON so a human can confirm placement; small faint gray dots
        // otherwise (including always during export, regardless of the
        // preview switch -- gated by !ShotState.finishing).
        readonly property bool previewing: ShotState.revealWatermark && !ShotState.finishing
        opacity: previewing ? 0.9 : ShotState.watermarkDotOpacity

        readonly property int dotPitch: ShotState.wmDotPitch
        readonly property int tileCols: ShotState.wmTileCols
        readonly property int tileRows: ShotState.wmTileRows
        readonly property int bitCount: ShotState.wmBitCount

        readonly property var tileBits: buildTileBits(ShotState.watermarkText)

        function buildTileBits(text) {
            var s = String(text || "");
            var bytes = [];
            for (var i = 0; i < s.length && bytes.length < 7; i++)
                bytes.push(s.charCodeAt(i) & 0xff);
            var len = bytes.length;
            var checksum = 0;
            for (var j = 0; j < bytes.length; j++)
                checksum = (checksum + bytes[j]) & 0xff;

            var bits = ShotState.wmSyncNibble.slice();
            for (var b = 3; b >= 0; b--)
                bits.push((len >> b) & 1); // length nibble
            for (var k = 0; k < bytes.length; k++)
                for (var b2 = 7; b2 >= 0; b2--)
                    bits.push((bytes[k] >> b2) & 1); // payload, MSB first
            for (var b3 = 7; b3 >= 0; b3--)
                bits.push((checksum >> b3) & 1); // checksum byte
            while (bits.length < bitCount)
                bits.push(bits.length % 2); // filler
            return bits.slice(0, bitCount);
        }

        readonly property int repeatX: Math.max(1, Math.ceil(width / (tileCols * dotPitch)) + 1)
        readonly property int repeatY: Math.max(1, Math.ceil(height / (tileRows * dotPitch)) + 1)

        Repeater {
            model: watermarkLayer.repeatX * watermarkLayer.repeatY
            delegate: Item {
                required property int index
                readonly property int tx: index % watermarkLayer.repeatX
                readonly property int ty: Math.floor(index / watermarkLayer.repeatX)
                x: tx * watermarkLayer.tileCols * watermarkLayer.dotPitch
                y: ty * watermarkLayer.tileRows * watermarkLayer.dotPitch
                width: watermarkLayer.tileCols * watermarkLayer.dotPitch
                height: watermarkLayer.tileRows * watermarkLayer.dotPitch

                Repeater {
                    model: watermarkLayer.bitCount
                    delegate: Rectangle {
                        required property int index
                        readonly property int col: index % watermarkLayer.tileCols
                        readonly property int row: Math.floor(index / watermarkLayer.tileCols)
                        readonly property bool on: watermarkLayer.tileBits[index] === 1
                        visible: on
                        x: col * watermarkLayer.dotPitch
                        y: row * watermarkLayer.dotPitch
                        width: watermarkLayer.previewing ? 6 : 3
                        height: width
                        radius: width / 2
                        // Mid-gray, not white: perturbs both light and dark
                        // backgrounds instead of vanishing on light ones.
                        color: watermarkLayer.previewing ? "#ffffff" : "#808080"
                        border.color: watermarkLayer.previewing ? "#000000" : "transparent"
                        border.width: watermarkLayer.previewing ? 1 : 0
                    }
                }
            }
        }
    }

    // ---- Committed annotations ----------------------------------------------
    Repeater {
        model: canvas.annotations
        delegate: AnnotationShape {
            required property var modelData
            ann: modelData
            backdrop: canvas.backdrop
        }
    }

    // ---- Live draft ----------------------------------------------------------
    AnnotationShape {
        ann: canvas.draft
        backdrop: canvas.backdrop
        visible: canvas.draft !== null
    }

    // ---- Gesture API ---------------------------------------------------------
    function beginDraft(gx, gy) {
        if (canvas.editing)
            finishEditing();

        var t = ShotState.tool;
        if (t === "text") {
            startTextEdit(gx, gy);
            return;
        }
        if (t === "counter") {
            pushAnnotation({
                type: "counter",
                x1: gx, y1: gy,
                color: String(ShotState.strokeColor),
                           number: ShotState.counterValue,
                           fontSize: ShotState.fontSize
            });
            ShotState.counterValue += 1;
            return;
        }
        if (t === "pen") {
            canvas._penPoints = [{ x: gx, y: gy }];
            canvas.draft = { type: "pen", points: canvas._penPoints.slice(),
                color: String(ShotState.strokeColor), width: ShotState.strokeWidth };
                return;
        }
        canvas.draft = makeDraft(t, gx, gy, gx, gy);
    }

    function updateDraft(gx, gy) {
        if (!canvas.draft)
            return;
        if (canvas.draft.type === "pen") {
            canvas._penPoints.push({ x: gx, y: gy });
            canvas.draft = { type: "pen", points: canvas._penPoints.slice(),
                color: canvas.draft.color, width: canvas.draft.width };
        } else {
            var d = canvas.draft;
            canvas.draft = makeDraft(d.type, d.x1, d.y1, gx, gy);
        }
    }

    function endDraft() {
        if (!canvas.draft)
            return;
        var d = canvas.draft;
        canvas.draft = null;
        canvas._penPoints = null;
        if (d.type === "pen") {
            if (d.points.length >= 2)
                pushAnnotation(d);
        } else if (Math.abs(d.x2 - d.x1) >= 3 || Math.abs(d.y2 - d.y1) >= 3) {
            pushAnnotation(d);
        }
    }

    function makeDraft(t, x1, y1, x2, y2) {
        return {
            type: t,
            x1: x1, y1: y1, x2: x2, y2: y2,
            color: String(ShotState.strokeColor),
            width: ShotState.strokeWidth
        };
    }

    function pushAnnotation(a) {
        canvas.annotations = canvas.annotations.concat([a]);
    }

    function translateAll(dx, dy) {
        if ((dx === 0 && dy === 0) || canvas.annotations.length === 0)
            return;
        canvas.annotations = canvas.annotations.map(function (a) {
            var b = {};
            for (var k in a)
                b[k] = a[k];
            if (b.x1 !== undefined) b.x1 += dx;
            if (b.y1 !== undefined) b.y1 += dy;
            if (b.x2 !== undefined) b.x2 += dx;
            if (b.y2 !== undefined) b.y2 += dy;
            if (b.points)
                b.points = b.points.map(function (p) { return { x: p.x + dx, y: p.y + dy }; });
            return b;
        });
    }

    function startTextEdit(gx, gy) {
        canvas.editing = {
            type: "text",
            x1: gx, y1: gy,
            text: "",
            color: String(ShotState.strokeColor),
            fontSize: ShotState.fontSize
        };
        canvas.editStarted();
    }

    function finishEditing() {
        var e = canvas.editing;
        canvas.editing = null;
        if (e && e.text && e.text.trim().length > 0)
            pushAnnotation(e);
        canvas.editFinished();
    }

    function cancelEditing() {
        canvas.editing = null;
        canvas.editFinished();
    }

    function undo() {
        if (canvas.editing) {
            cancelEditing();
            return;
        }
        if (canvas.annotations.length > 0)
            canvas.annotations = canvas.annotations.slice(0, canvas.annotations.length - 1);
    }

    function clearAll() {
        cancelEditing();
        canvas.annotations = [];
        ShotState.counterValue = 1;
    }

    function commitDraft() {
        if (canvas.editing)
            finishEditing();
        if (canvas.draft)
            endDraft();
    }
}
