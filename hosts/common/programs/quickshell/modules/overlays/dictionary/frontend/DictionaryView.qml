import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend"
import "../../../style" as Style

Item {
    id: viewRoot

    required property DictionaryEngine engine
    property var theme: null
    property var settingsManager: null

    readonly property int fieldHeight: settingsManager
        ? settingsManager.getWindowFieldHeight("dictionary", 52) : 52
    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize : 16

    signal completed()

    function clearAndFocus(word) {
        dictField.text = word || "";
        if (word && word.trim() !== "") engine.fetch(word.trim());
        Qt.callLater(() => dictField.forceActiveFocus());
    }

    Component.onCompleted: Qt.callLater(() => dictField.forceActiveFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => dictField.forceActiveFocus())

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: (viewRoot.theme && viewRoot.theme.globalPadding) ? viewRoot.theme.globalPadding : 16
        spacing: 16

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
                borderColor: dictField.activeFocus
                    ? ((theme && theme.base05) ? theme.base05 : "yellow")
                    : ((theme && theme.base03) ? theme.base03 : "#45475a")
                borderWidth: dictField.activeFocus ? 2 : 1
                slantWidth: 14
            }

            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 10
                Text { text: "📖"; font.pixelSize: Math.max(16, viewRoot.fieldHeight * 0.38) }
                TextInput {
                    id: dictField
                    Layout.fillWidth: true
                    font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                    font.pixelSize: viewRoot.overlayFontSize
                    color: (theme && theme.base05) ? theme.base05 : "yellow"
                    selectByMouse: true
                    focus: true
                    verticalAlignment: TextInput.AlignVCenter

                    Text {
                        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                        text: "Type word to look up... [Enter to search]"
                        color: "#666"; font.pixelSize: viewRoot.overlayFontSize
                        visible: parent.text === "" && !parent.activeFocus
                    }
                    onAccepted: engine.fetch(text)
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (engine.definitionEntries.length > 0 && engine.definitionEntries[0].type === "definition") {
                                if (engine.copySelected()) viewRoot.completed();
                            } else {
                                engine.fetch(text);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (engine.selectedIndex < engine.definitionEntries.length - 1) engine.selectedIndex++;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (engine.selectedIndex > 0) engine.selectedIndex--;
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        ListView {
            id: defListView
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 10
            model: engine.definitionEntries
            currentIndex: engine.selectedIndex

            delegate: Item {
                id: defCard
                readonly property bool isSelected: index === engine.selectedIndex
                width: defListView.width - 12
                height: Math.max(54, defText.implicitHeight + 24)

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    color: defCard.isSelected ? ((theme && theme.base02) ? theme.base02 : "#333") : "transparent"
                    borderColor: defCard.isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#444"
                    borderWidth: defCard.isSelected ? 2 : 1
                    slantWidth: 10
                }

                Text {
                    id: defText
                    anchors.fill: parent; anchors.margins: 12
                    text: modelData.text
                    font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                    font.pixelSize: viewRoot.overlayFontSize
                    color: defCard.isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#ccc"
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
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
