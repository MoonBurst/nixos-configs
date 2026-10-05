import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend"
import "../../../style" as Style

Item {
    id: viewRoot

    required property UnicodeEngine engine
    property var theme: null
    property var settingsManager: null

    readonly property int fieldHeight: settingsManager
        ? settingsManager.getWindowFieldHeight("unicode", 52) : 52
    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize : 16

    signal completed()

    function clearAndFocus() {
        searchField.clear();
        engine.query = "";
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    Component.onCompleted: Qt.callLater(() => searchField.forceActiveFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => searchField.forceActiveFocus())

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: (viewRoot.theme && viewRoot.theme.globalPadding) ? viewRoot.theme.globalPadding : 16
        spacing: 16

        // Universal Shape Search Bar
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: viewRoot.fieldHeight
            Layout.minimumHeight: viewRoot.fieldHeight
            Layout.maximumHeight: viewRoot.fieldHeight
            height: viewRoot.fieldHeight

            Style.ShapeBox {
                anchors.fill: parent
                role: "input"
                color: (theme && theme.base00) ? theme.base00 : "#11111b"
                borderColor: searchField.activeFocus
                    ? ((theme && theme.base05) ? theme.base05 : "yellow")
                    : ((theme && theme.base03) ? theme.base03 : "#45475a")
                borderWidth: searchField.activeFocus ? 2 : 1
                slantWidth: 14
            }

            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 10
                Text { text: "🔣"; font.pixelSize: Math.max(16, viewRoot.fieldHeight * 0.38) }
                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                    font.pixelSize: viewRoot.overlayFontSize
                    color: (theme && theme.base05) ? theme.base05 : "yellow"
                    selectByMouse: true
                    focus: true
                    verticalAlignment: TextInput.AlignVCenter
                    onTextChanged: engine.query = text

                    Text {
                        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                        text: "Search unicode glyphs and symbols..."
                        color: "#666"; font.pixelSize: viewRoot.overlayFontSize
                        visible: parent.text === "" && !parent.activeFocus
                    }

                    Keys.onPressed: (event) => {
                        var cols = Math.max(1, Math.floor(symGrid.width / symGrid.cellWidth));
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (engine.copySelected()) viewRoot.completed();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right) {
                            if (engine.selectedIndex < engine.filteredItems.length - 1) {
                                engine.selectedIndex++;
                                symGrid.positionViewAtIndex(engine.selectedIndex, GridView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left) {
                            if (engine.selectedIndex > 0) {
                                engine.selectedIndex--;
                                symGrid.positionViewAtIndex(engine.selectedIndex, GridView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (engine.selectedIndex + cols < engine.filteredItems.length) {
                                engine.selectedIndex += cols;
                                symGrid.positionViewAtIndex(engine.selectedIndex, GridView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (engine.selectedIndex - cols >= 0) {
                                engine.selectedIndex -= cols;
                                symGrid.positionViewAtIndex(engine.selectedIndex, GridView.Contain);
                            }
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        GridView {
            id: symGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: Math.floor(width / Math.max(4, Math.floor(width / 115)))
            cellHeight: 90
            model: engine.filteredItems
            currentIndex: engine.selectedIndex

            delegate: Item {
                id: cellRoot
                readonly property bool isSelected: index === engine.selectedIndex
                width: symGrid.cellWidth
                height: symGrid.cellHeight

                Item {
                    anchors.fill: parent
                    anchors.margins: 4

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        color: cellRoot.isSelected ? ((theme && theme.base02) ? theme.base02 : "#333") : (gHover.hovered ? "#222" : "transparent")
                        borderColor: cellRoot.isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : (gHover.hovered ? "#555" : "#333")
                        borderWidth: cellRoot.isSelected ? 2 : 1
                        slantWidth: 8
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        Text {
                            text: modelData.symbol
                            font.pixelSize: 32
                            color: (theme && theme.base05) ? theme.base05 : "yellow"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: modelData.name.split(" ")[0]
                            font.pixelSize: Math.max(9, viewRoot.overlayFontSize - 6)
                            color: cellRoot.isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#aaa"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    HoverHandler { id: gHover }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            engine.selectedIndex = index;
                            if (engine.copySelected()) viewRoot.completed();
                        }
                    }
                }
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }
}
