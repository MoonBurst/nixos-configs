import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend"

Item {
    id: viewRoot

    required property WebSearchEngine engine
    property var theme: null

    readonly property int fieldHeight: (shell && shell.settingsManager)
        ? shell.settingsManager.getWindowFieldHeight("web", 54) : 54
    readonly property int overlayFontSize: (shell && shell.settingsManager && shell.settingsManager.overlayFontSize > 0)
        ? shell.settingsManager.overlayFontSize : 16

    signal completed()

    function clearAndFocus(q) {
        searchField.text = q || "";
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    Component.onCompleted: Qt.callLater(() => searchField.forceActiveFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => searchField.forceActiveFocus())

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 700)
        spacing: 16

        Text {
            text: "🌐 WEB SEARCH"
            font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
            font.pixelSize: viewRoot.overlayFontSize + 2
            font.bold: true
            color: (theme && theme.base05) ? theme.base05 : "yellow"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: viewRoot.fieldHeight
            Layout.minimumHeight: viewRoot.fieldHeight
            Layout.maximumHeight: viewRoot.fieldHeight
            height: viewRoot.fieldHeight
            radius: 8
            color: (theme && theme.base00) ? theme.base00 : "#11111b"
            border.width: searchField.activeFocus ? 2 : 1
            border.color: searchField.activeFocus ? ((theme && theme.base05) ? theme.base05 : "yellow") : ((theme && theme.base03) ? theme.base03 : "#45475a")

            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 10
                Text { text: "🔍"; font.pixelSize: Math.max(16, viewRoot.fieldHeight * 0.38) }
                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                    font.pixelSize: viewRoot.overlayFontSize
                    color: (theme && theme.base05) ? theme.base05 : "yellow"
                    selectByMouse: true
                    focus: true
                    verticalAlignment: TextInput.AlignVCenter

                    Text {
                        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                        text: "Type search query and press [Enter]..."
                        color: "#666"; font.pixelSize: viewRoot.overlayFontSize
                        visible: parent.text === "" && !parent.activeFocus
                    }
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            engine.search(text);
                            viewRoot.completed();
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 6
            color: btnHov.hovered ? ((theme && theme.base05) ? theme.base05 : "yellow") : ((theme && theme.base03) ? theme.base03 : "#003399")

            Text {
                anchors.centerIn: parent
                text: searchField.text.trim().length > 0 ? "Search Startpage for \"" + searchField.text.trim() + "\"" : "Search with Startpage"
                color: btnHov.hovered ? "#000" : ((theme && theme.base05) ? theme.base05 : "yellow")
                font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                font.pixelSize: viewRoot.overlayFontSize
                font.bold: true
                elide: Text.ElideRight
            }

            HoverHandler { id: btnHov }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    engine.search(searchField.text);
                    viewRoot.completed();
                }
            }
        }
    }
}
