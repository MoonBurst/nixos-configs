import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend"

Item {
    id: viewRoot

    required property ClipboardEngine engine
    property var theme: null

    readonly property int fieldHeight: (shell && shell.settingsManager)
        ? shell.settingsManager.getWindowFieldHeight("clipboard", 52) : 52
    readonly property int overlayFontSize: (shell && shell.settingsManager && shell.settingsManager.overlayFontSize > 0)
        ? shell.settingsManager.overlayFontSize : 15

    signal completed()

    function clearAndFocus() {
        searchField.clear();
        engine.loadClipboard();
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    Component.onCompleted: Qt.callLater(() => searchField.forceActiveFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => searchField.forceActiveFocus())

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: (viewRoot.theme && viewRoot.theme.globalPadding) ? viewRoot.theme.globalPadding : 16
        spacing: 14

        // 1. Fixed-Height Search Bar Row (Does not stretch across window)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: viewRoot.fieldHeight
            Layout.minimumHeight: viewRoot.fieldHeight
            Layout.maximumHeight: viewRoot.fieldHeight
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: (theme && theme.base00) ? theme.base00 : "#11111b"
                border.width: searchField.activeFocus ? 2 : 1
                border.color: searchField.activeFocus ? ((theme && theme.base05) ? theme.base05 : "yellow") : ((theme && theme.base03) ? theme.base03 : "#45475a")

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "📋"
                        font.pixelSize: Math.max(16, viewRoot.fieldHeight * 0.38)
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                        font.pixelSize: viewRoot.overlayFontSize
                        color: (theme && theme.base05) ? theme.base05 : "yellow"
                        selectByMouse: true
                        focus: true
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: engine.refreshFilter(text)

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search clipboard history... [image: for shots, Del to remove]"
                            color: "#666"
                            font.pixelSize: viewRoot.overlayFontSize
                            visible: parent.text === "" && !parent.activeFocus
                            elide: Text.ElideRight
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Down) {
                                if (engine.selectedIndex < engine.filteredClipboardModel.count - 1) {
                                    engine.selectedIndex++; engine.updatePreview();
                                    clipList.positionViewAtIndex(engine.selectedIndex, ListView.Contain);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                if (engine.selectedIndex > 0) {
                                    engine.selectedIndex--; engine.updatePreview();
                                    clipList.positionViewAtIndex(engine.selectedIndex, ListView.Contain);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                engine.copySelected();
                                viewRoot.completed();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Delete) {
                                engine.deleteSelected();
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 100
                Layout.fillHeight: true
                radius: 8
                color: wipeHov.hovered ? "#ff5555" : ((theme && theme.base00) ? theme.base00 : "#11111b")
                border.width: 1
                border.color: "#ff5555"

                Text {
                    anchors.centerIn: parent
                    text: "🗑️ Wipe"
                    font.bold: true
                    font.pixelSize: 13
                    color: wipeHov.hovered ? "#000" : "#ff5555"
                }

                HoverHandler { id: wipeHov }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: engine.wipeHistory()
                }
            }
        }

        // 2. Expandable Content Area (List + Preview Panel)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            ListView {
                id: clipList
                Layout.preferredWidth: Math.round(viewRoot.width * 0.48)
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: engine.filteredClipboardModel
                currentIndex: engine.selectedIndex

                delegate: Rectangle {
                    readonly property bool isSelected: index === engine.selectedIndex
                    width: clipList.width - 12
                    height: model.isImage ? 80 : 54
                    radius: 6
                    color: isSelected ? ((theme && theme.base02) ? theme.base02 : "#333") : "transparent"
                    border.width: isSelected ? 2 : 1
                    border.color: isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#444"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 12

                        Rectangle {
                            visible: model.isImage
                            width: 60
                            height: 60
                            radius: 4
                            color: "#000"
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: model.isImage && model.imagePath ? ("file://" + model.imagePath) : ""
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        Text {
                            text: model.text
                            font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                            font.pixelSize: viewRoot.overlayFontSize
                            color: isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#ccc"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            engine.selectedIndex = index;
                            engine.updatePreview();
                        }
                        onDoubleClicked: {
                            engine.selectedIndex = index;
                            engine.copySelected();
                            viewRoot.completed();
                        }
                    }
                }
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: (theme && theme.base00) ? theme.base00 : "#11111b"
                border.width: 1
                border.color: (theme && theme.base03) ? theme.base03 : "#45475a"
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 14
                    visible: engine.previewImage !== ""
                    source: engine.previewImage
                    fillMode: Image.PreserveAspectFit
                }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 14
                    visible: engine.previewImage === ""
                    clip: true
                    TextArea {
                        text: engine.previewText
                        wrapMode: Text.WrapAnywhere
                        readOnly: true
                        selectByMouse: true
                        color: (theme && theme.base05) ? theme.base05 : "yellow"
                        font.family: "monospace"
                        font.pixelSize: viewRoot.overlayFontSize
                        background: null
                    }
                }
            }
        }
    }
}
