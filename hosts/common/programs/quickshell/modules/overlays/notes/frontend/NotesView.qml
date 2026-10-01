import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend" as Backend

Item {
    id: viewRoot

    required property Backend.NotesEngine engine
    property var theme: null

    readonly property int fieldHeight: (shell && shell.settingsManager)
        ? shell.settingsManager.getWindowFieldHeight("notes", 52) : 52
    readonly property int overlayFontSize: (shell && shell.settingsManager && shell.settingsManager.overlayFontSize > 0)
        ? shell.settingsManager.overlayFontSize : 16

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
        anchors.margins: (viewRoot.theme && viewRoot.theme.globalPadding) ? viewRoot.theme.globalPadding : 16
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: viewRoot.fieldHeight
            Layout.minimumHeight: viewRoot.fieldHeight
            Layout.maximumHeight: viewRoot.fieldHeight
            height: viewRoot.fieldHeight
            radius: 8
            color: (theme && theme.base00) ? theme.base00 : "#11111b"
            border.width: noteInput.activeFocus ? 2 : 1
            border.color: noteInput.activeFocus ? ((theme && theme.base05) ? theme.base05 : "yellow") : ((theme && theme.base03) ? theme.base03 : "#45475a")

            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 10
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
                            if (engine.selectedIndex < engine.filteredModel.count - 1) engine.selectedIndex++;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (engine.selectedIndex > 0) engine.selectedIndex--;
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

            delegate: Rectangle {
                id: noteCard
                readonly property bool isSelected: index === engine.selectedIndex
                width: notesList.width - 12
                height: Math.max(54, noteContentColumn.implicitHeight + 28)
                radius: 6
                color: isSelected ? ((theme && theme.base02) ? theme.base02 : "#333") : "transparent"
                border.width: isSelected ? 2 : 1
                border.color: isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#444"

                RowLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 14
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
                            color: isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#ccc"
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
