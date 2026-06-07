import QtQuick

// A single draggable resize handle. It reports drag positions in the coordinate
// space of `reference` (the overlay content item) so the owner can recompute the
// selection rectangle without worrying about the handle's own moving origin.
Item {
    id: handle

    property string role: "br"
    property real cx: 0
    property real cy: 0
    property Item reference: parent

    signal moved(real gx, real gy)
    signal finished()

    width: Style.handleSize
    height: Style.handleSize
    x: cx - width / 2
    y: cy - height / 2

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: Style.handleFill
        border.color: Style.handleBorder
        border.width: 1.5
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -8 // generous hit target around the visible square
        preventStealing: true
        cursorShape: handle.cursorForRole(handle.role)
        onPositionChanged: function (mouse) {
            var p = mapToItem(handle.reference, mouse.x, mouse.y);
            handle.moved(p.x, p.y);
        }
        onReleased: handle.finished()
    }

    function cursorForRole(r) {
        switch (r) {
        case "tl":
        case "br":
            return Qt.SizeFDiagCursor;
        case "tr":
        case "bl":
            return Qt.SizeBDiagCursor;
        case "t":
        case "b":
            return Qt.SizeVerCursor;
        case "l":
        case "r":
            return Qt.SizeHorCursor;
        }
        return Qt.ArrowCursor;
    }
}
