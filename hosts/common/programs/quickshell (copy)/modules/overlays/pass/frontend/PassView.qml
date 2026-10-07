import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../../../common"
import "../backend"
import "../../../style" as Style
import "../../../common/Utils.js" as Utils

Item {
    id: viewRoot

    required property PassEngine engine
    property var theme: null
    property var settingsManager: null

    readonly property int fieldHeight: settingsManager
        ? settingsManager.getWindowFieldHeight("pass", 52) : 52
    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize : 16

    readonly property int controlBorderWidth: (settingsManager && settingsManager.controlBorderWidth)
        ? settingsManager.controlBorderWidth
        : ((theme && theme.controlBorderWidth) ? theme.controlBorderWidth : 2)

    readonly property var inputPad: Utils.getSafeInputPadding(settingsManager)

    signal completed()

    function clearAndFocus(q) {
        searchField.text = q || "";
        engine.searchQuery = q || "";
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    Component.onCompleted: Qt.callLater(() => searchField.forceActiveFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => searchField.forceActiveFocus())

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 16

        // Universal Shape Search Box
        Item {
            id: searchBox
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
                borderWidth: viewRoot.controlBorderWidth
                slantWidth: 14
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: viewRoot.inputPad.left
                anchors.rightMargin: viewRoot.inputPad.right
                spacing: 10

                Text {
                    id: keyIcon
                    text: "🔑"
                    font.pixelSize: Math.min(26, Math.max(16, parent.height * 0.42))
                }

                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                    font.pixelSize: Math.min(viewRoot.overlayFontSize + 2, Math.max(13, parent.height * 0.42))
                    color: (theme && theme.base05) ? theme.base05 : "yellow"
                    selectByMouse: true
                    focus: true
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    onTextChanged: engine.searchQuery = text

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search password store... [Tab to complete, Esc to close]"
                        color: (theme && theme.base0B) ? theme.base0B : "#666"
                        font.pixelSize: parent.font.pixelSize
                        font.family: parent.font.family
                        visible: parent.text === "" && !parent.activeFocus
                        elide: Text.ElideRight
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Tab) {
                            if (engine.topKey !== "") {
                                searchField.text = engine.topKey;
                                searchField.cursorPosition = searchField.text.length;
                                event.accepted = true;
                            }
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (engine.filteredModel.count > 0) {
                                engine.decryptAndCopy(engine.filteredModel.get(engine.selectedIndex).key);
                                viewRoot.completed();
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (engine.selectedIndex < engine.filteredModel.count - 1) {
                                engine.selectedIndex++;
                                passListView.positionViewAtIndex(engine.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (engine.selectedIndex > 0) {
                                engine.selectedIndex--;
                                passListView.positionViewAtIndex(engine.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        ListView {
            id: passListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: engine.filteredModel
            currentIndex: engine.selectedIndex

            delegate: Item {
                id: passDelegateItem
                readonly property bool isSelected: index === engine.selectedIndex
                width: passListView.width - 12
                height: 50

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    color: passDelegateItem.isSelected ? ((theme && theme.base02) ? theme.base02 : "#333") : "transparent"
                    borderColor: passDelegateItem.isSelected ? "#00e5ff" : ((theme && theme.base03) ? theme.base03 : "#444")
                    borderWidth: viewRoot.controlBorderWidth
                    slantWidth: 10
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.max(14, viewRoot.inputPad.left)
                    anchors.rightMargin: Math.max(14, viewRoot.inputPad.right)
                    spacing: 10

                    Text { text: "🔒"; font.pixelSize: 16 }
                    Text {
                        text: model.key
                        font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                        font.pixelSize: viewRoot.overlayFontSize
                        color: passDelegateItem.isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#ccc"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        visible: passDelegateItem.isSelected
                        width: 70
                        height: 26
                        radius: 4
                        color: "#00e5ff"
                        Text { anchors.centerIn: parent; text: "↵ Copy"; font.bold: true; font.pixelSize: 11; color: "#000" }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        engine.selectedIndex = index;
                        engine.decryptAndCopy(model.key);
                        viewRoot.completed();
                    }
                }
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }
}
