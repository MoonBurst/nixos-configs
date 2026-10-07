import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend" as Backend
import "../../../style" as Style
import "../../../common/Utils.js" as Utils

Item {
    id: viewRoot

    required property Backend.NotesEngine engine
    property var theme: null
    property var settingsManager: null

    readonly property int fieldHeight: settingsManager
        ? settingsManager.getWindowFieldHeight("notes", 52) : 52
    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize : 16

    readonly property int controlBorderWidth: (settingsManager && settingsManager.controlBorderWidth)
        ? settingsManager.controlBorderWidth
        : ((theme && theme.controlBorderWidth) ? theme.controlBorderWidth : 2)

    readonly property var inputPad: Utils.getSafeInputPadding(settingsManager)

    signal completed()

    function clearAndFocus(n) {
        noteInput.text = n || "";
        engine.searchQuery = n || "";
        Qt.callLater(() => noteInput.forceActiveFocus());
    }

    Component.onCompleted: Qt.callLater(() => noteInput.forceActiveFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => noteInput.forceActiveFocus())

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 14

        // Universal Shape Input Bar
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
                borderColor: noteInput.activeFocus
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
                Text { text: "📝"; font.pixelSize: Math.max(16, viewRoot.fieldHeight * 0.38) }

                TextInput {
                    id: noteInput
                    Layout.fillWidth: true
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                    font.pixelSize: viewRoot.overlayFontSize
                    color: (theme && theme.base05) ? theme.base05 : "yellow"
                    selectByMouse: true
                    focus: true

                    Text {
                        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                        text: "Type note to save [Enter to add, Del to remove]..."
                        color: "#666"; font.pixelSize: viewRoot.overlayFontSize
                        visible: parent.text === "" && !parent.activeFocus
                    }

                    onTextChanged: engine.searchQuery = text

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (text.trim() !== "") {
                                engine.addNote(text);
                                text = "";
                            } else {
                                if (engine.copySelected()) viewRoot.completed();
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (engine.selectedIndex < engine.filteredModel.count - 1) {
                                engine.selectedIndex++;
                                notesList.positionViewAtIndex(engine.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (engine.selectedIndex > 0) {
                                engine.selectedIndex--;
                                notesList.positionViewAtIndex(engine.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete) {
                            engine.deleteNoteAt(engine.selectedIndex);
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        ListView {
            id: notesList
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8
            model: engine.filteredModel
            currentIndex: engine.selectedIndex

            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 10000
            maximumFlickVelocity: 15000

            delegate: Item {
                id: noteCard
                readonly property bool isSelected: index === engine.selectedIndex
                width: notesList.width - 12
                height: Math.max(54, noteContentColumn.implicitHeight + 28)

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    color: noteCard.isSelected ? ((theme && theme.base02) ? theme.base02 : "#333") : "transparent"
                    borderColor: noteCard.isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : ((theme && theme.base03) ? theme.base03 : "#45475a")
                    borderWidth: viewRoot.controlBorderWidth
                    slantWidth: 10
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.max(14, viewRoot.inputPad.left)
                    anchors.rightMargin: Math.max(14, viewRoot.inputPad.right)
                    spacing: 14
                    Text { text: "📌"; font.pixelSize: Math.max(16, viewRoot.overlayFontSize) }

                    ColumnLayout {
                        id: noteContentColumn
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        Text {
                            visible: model.timestamp !== ""
                            text: model.timestamp
                            font.pixelSize: Math.max(10, viewRoot.overlayFontSize - 5)
                            font.bold: true; color: "#fe8019"
                        }
                        Text {
                            id: contentTxt
                            text: model.content
                            font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                            font.pixelSize: viewRoot.overlayFontSize
                            color: noteCard.isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#ccc"
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        width: 28; height: 28; radius: 4; color: "transparent"; border.color: "#ff5555"; border.width: 1
                        Layout.alignment: Qt.AlignVCenter
                        Text { anchors.centerIn: parent; text: "✕"; color: "#ff5555"; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: engine.deleteNoteAt(index) }
                    }
                }

                MouseArea {
                    anchors.fill: parent; z: -1
                    onClicked: {
                        engine.selectedIndex = index;
                        if (engine.copySelected()) viewRoot.completed();
                    }
                }
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }
}
