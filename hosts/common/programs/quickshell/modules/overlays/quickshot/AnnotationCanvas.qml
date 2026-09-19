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

    // ---- Repeating Watermark Layer (Pure QML) -------------------------------
    Item {
        id: watermarkLayer
        anchors.fill: parent
        z: -1 // Sits behind drawn annotations
        clip: true
        enabled: false // Never intercepts mouse gestures

        visible: Boolean(ShotState.watermarkText && ShotState.watermarkText.trim().length > 0)

        // High visibility (0.80) when preview switch is ON; stealth (0.009) when OFF or exporting
        opacity: (ShotState.revealWatermark && !ShotState.finishing) ? 0.80 : ShotState.watermarkOpacity

        readonly property int cols: Math.max(1, Math.ceil(width / 240) + 8)
        readonly property int rows: Math.max(1, Math.ceil(height / 130) + 8)

        Grid {
            anchors.centerIn: parent
            rotation: -30
            columns: watermarkLayer.cols
            spacing: 85

            Repeater {
                model: watermarkLayer.cols * watermarkLayer.rows
                delegate: Text {
                    text: ShotState.watermarkText
                    color: "#ffffff"
                    style: ShotState.revealWatermark ? Text.Outline : Text.Normal
                    styleColor: "#000000"
                    font.pixelSize: 28                 // Large 28px glyphs
                    font.bold: true                    // Solid 3px strokes
                    font.capitalization: Font.AllUppercase // Open letters won't clog under contrast
                    font.letterSpacing: 4              // Clean separation between characters
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
