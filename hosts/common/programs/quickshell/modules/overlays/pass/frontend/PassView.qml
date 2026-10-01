import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../../../common"
import "../backend"

Item {
    id: viewRoot

    required property PassEngine engine
    property var theme: null

    readonly property int fieldHeight: (shell && shell.settingsManager)
        ? shell.settingsManager.getWindowFieldHeight("pass", 52) : 52
    readonly property int overlayFontSize: (shell && shell.settingsManager && shell.settingsManager.overlayFontSize > 0)
        ? shell.settingsManager.overlayFontSize : 16

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
        anchors.margins: (viewRoot.theme && viewRoot.theme.globalPadding) ? viewRoot.theme.globalPadding : 16
        spacing: 16

        // Unified Centered Search Box
        Rectangle {
            id: searchBox
            Layout.fillWidth: true
            Layout.preferredHeight: viewRoot.fieldHeight
            Layout.minimumHeight: viewRoot.fieldHeight
            Layout.maximumHeight: viewRoot.fieldHeight
            height: viewRoot.fieldHeight
            radius: 8
            color: (theme && theme.base00) ? theme.base00 : "#11111b"
            border.width: searchField.activeFocus ? 2 : 1
            border.color: searchField.activeFocus ? ((theme && theme.base05) ? theme.base05 : "yellow") : ((theme && theme.base03) ? theme.base03 : "#45475a")

            Text {
                id: keyIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "🔑"
                font.pixelSize: Math.min(26, Math.max(16, parent.height * 0.42))
            }

            TextInput {
                id: searchField
                anchors.left: keyIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                font.pixelSize: Math.min(viewRoot.overlayFontSize + 2, Math.max(13, parent.height * 0.42))
                color: (theme && theme.base05) ? theme.base05 : "yellow"
                selectByMouse: true
                focus: true
                clip: true
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

        ListView {
            id: passListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: engine.filteredModel
            currentIndex: engine.selectedIndex

            delegate: Rectangle {
                readonly property bool isSelected: index === engine.selectedIndex
                width: passListView.width - 12
                height: 50
                radius: 6
                color: isSelected ? ((theme && theme.base02) ? theme.base02 : "#333") : "transparent"
                border.width: isSelected ? 2 : 1
                border.color: isSelected ? "#00e5ff" : "#444"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text { text: "🔒"; font.pixelSize: 16 }
                    Text {
                        text: model.key
                        font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                        font.pixelSize: viewRoot.overlayFontSize
                        color: isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#ccc"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        visible: isSelected
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
