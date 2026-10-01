import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend"

Item {
    id: viewRoot

    required property CalcEngine engine
    property var theme: null

    readonly property int fieldHeight: (shell && shell.settingsManager)
        ? shell.settingsManager.getWindowFieldHeight("calc", 54) : 54
    readonly property int overlayFontSize: (shell && shell.settingsManager && shell.settingsManager.overlayFontSize > 0)
        ? shell.settingsManager.overlayFontSize : 18

    signal completed()
    function clearAndFocus(expr) {
        calcField.text = expr || "";
        if (expr) engine.evaluate(expr);
        Qt.callLater(() => calcField.forceActiveFocus());
    }
    Component.onCompleted: Qt.callLater(() => calcField.forceActiveFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => calcField.forceActiveFocus())

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: (viewRoot.theme && viewRoot.theme.globalPadding) ? viewRoot.theme.globalPadding : 16
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            height: viewRoot.fieldHeight
            radius: 8
            color: (theme && theme.base00) ? theme.base00 : "#11111b"
            border.width: calcField.activeFocus ? 2 : 1
            border.color: calcField.activeFocus ? ((theme && theme.base05) ? theme.base05 : "yellow") : ((theme && theme.base03) ? theme.base03 : "#45475a")

            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 10
                Text { text: "🧮"; font.pixelSize: Math.max(16, viewRoot.fieldHeight * 0.4) }
                TextInput {
                    id: calcField
                    Layout.fillWidth: true
                    font.family: "monospace"
                    font.pixelSize: Math.min(viewRoot.overlayFontSize, Math.max(13, viewRoot.fieldHeight * 0.42))
                    font.bold: true
                    color: (theme && theme.base05) ? theme.base05 : "yellow"
                    selectByMouse: true
                    onTextChanged: engine.expression = text

                    Text {
                        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                        text: "Type math or units (50 * 12, $10 in eur, 50kg in lbs)..."
                        color: "#666"; font.pixelSize: Math.min(viewRoot.overlayFontSize, Math.max(13, viewRoot.fieldHeight * 0.42)); visible: parent.text === "" && !parent.activeFocus
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (engine.resultString.indexOf("\n") !== -1) {
                                var rows = engine.resultString.split("\n");
                                if (engine.selectedGridIndex >= 0 && engine.selectedGridIndex < rows.length) {
                                    var p = rows[engine.selectedGridIndex].split("|");
                                    engine.copyResult(p.length > 3 ? (p[3] + " " + p[1]) : rows[engine.selectedGridIndex]);
                                    viewRoot.completed();
                                }
                            } else if (engine.resultString !== "") {
                                engine.copyResult(engine.resultString);
                                viewRoot.completed();
                            }
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: (theme && theme.base00) ? theme.base00 : "#11111b"
            border.width: 1; border.color: (theme && theme.base03) ? theme.base03 : "#45475a"

            Item {
                anchors.fill: parent
                visible: engine.resultString !== "" && engine.resultString.indexOf("\n") === -1
                Column {
                    anchors.centerIn: parent; spacing: 12
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: engine.resultString; font.family: "monospace"; font.pixelSize: Math.max(32, viewRoot.overlayFontSize * 2.2); font.bold: true; color: (theme && theme.base05) ? theme.base05 : "yellow" }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Press [Enter] to copy result"; font.pixelSize: Math.max(11, viewRoot.overlayFontSize - 4); color: "#04f100" }
                }
            }

            Item {
                anchors.fill: parent; anchors.margins: 14
                visible: engine.resultString.indexOf("\n") !== -1
                Grid {
                    anchors.fill: parent; columns: 3; columnSpacing: 10; rowSpacing: 10
                    Repeater {
                        model: engine.resultString.split("\n")
                        delegate: Rectangle {
                            readonly property var parts: modelData.split("|")
                            readonly property string cCode: parts.length > 3 ? parts[1] : ""
                            readonly property string cVal: parts.length > 3 ? parts[3] : modelData
                            readonly property bool isSelected: index === engine.selectedGridIndex
                            width: Math.floor((parent.width - 20) / 3)
                            height: Math.floor((parent.height - 30) / 4)
                            radius: 6
                            color: isSelected ? ((theme && theme.base02) ? theme.base02 : "#333") : "transparent"
                            border.color: isSelected ? "#04f100" : "#444"
                            border.width: isSelected ? 2 : 1
                            Column {
                                anchors.fill: parent; anchors.margins: 8; spacing: 4
                                Text { text: cCode; font.bold: true; font.pixelSize: Math.max(11, viewRoot.overlayFontSize - 4); color: isSelected ? "#04f100" : "yellow" }
                                Text { text: cVal; font.bold: true; font.pixelSize: Math.max(14, viewRoot.overlayFontSize); color: isSelected ? "#04f100" : "yellow" }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    engine.selectedGridIndex = index;
                                    engine.copyResult(cVal + " " + cCode);
                                    viewRoot.completed();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
