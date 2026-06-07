import QtQuick

// Floating control panel: tool palette, colour picker, stroke-width picker and
// the copy / save / undo / clear / cancel actions. It only mutates ShotState
// for tool selection; the action buttons are surfaced as signals so the owning
// overlay can run the grab/export logic.
Rectangle {
    id: bar

    signal undo()
    signal clearAll()
    signal copy()
    signal save()
    signal cancel()

    radius: Style.toolbarRadius
    color: Style.panel
    border.color: Style.panelBorder
    border.width: 1

    implicitWidth: layout.implicitWidth + Style.toolbarPadding * 2
    implicitHeight: layout.implicitHeight + Style.toolbarPadding * 2

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: Style.toolbarSpacing

        // ---- Tools -----------------------------------------------------------
        Repeater {
            model: ShotState.tools
            delegate: IconButton {
                required property var modelData
                glyph: modelData.icon
                tip: modelData.tip
                checked: ShotState.tool === modelData.id
                onClicked: ShotState.tool = modelData.id
            }
        }

        ToolbarSeparator {}

        // ---- Colours ---------------------------------------------------------
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: Style.annotationPalette
                delegate: Item {
                    id: swatch
                    required property var modelData
                    width: Style.buttonSize
                    height: Style.buttonSize

                    readonly property bool selected: Qt.colorEqual(ShotState.strokeColor, swatch.modelData)

                    Rectangle {
                        anchors.centerIn: parent
                        width: Style.swatchSize
                        height: Style.swatchSize
                        radius: width / 2
                        color: swatch.modelData
                        border.width: swatch.selected ? 3 : 1
                        border.color: swatch.selected ? Style.accent : Style.panelBorder
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShotState.strokeColor = swatch.modelData
                    }
                }
            }
        }

        ToolbarSeparator {}

        // ---- Stroke width ----------------------------------------------------
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: Style.strokeWidths
                delegate: Item {
                    id: widthOption
                    required property var modelData
                    width: Style.buttonSize
                    height: Style.buttonSize

                    readonly property bool selected: ShotState.strokeWidth === widthOption.modelData

                    Rectangle {
                        anchors.fill: parent
                        radius: Style.buttonRadius
                        color: widthOption.selected ? Style.panelRaised : "transparent"
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(widthOption.modelData + 6, Style.swatchSize)
                        height: width
                        radius: width / 2
                        color: widthOption.selected ? Style.accent : Style.textMuted
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShotState.strokeWidth = widthOption.modelData
                    }
                }
            }
        }

        ToolbarSeparator {}

        // ---- Actions ---------------------------------------------------------
        IconButton { glyph: "⟲"; tip: "Undo (Ctrl+Z)"; onClicked: bar.undo() }
        IconButton { glyph: "✕"; tip: "Clear annotations"; onClicked: bar.clearAll() }
        IconButton {
            glyph: "⧉"; tip: "Copy to clipboard (Enter)"
            tint: Style.accent; checked: true; onClicked: bar.copy()
        }
        IconButton { glyph: "⭳"; tip: "Save to file (Ctrl+S)"; onClicked: bar.save() }
        IconButton { glyph: "⎋"; tip: "Cancel (Esc)"; onClicked: bar.cancel() }
    }
}
