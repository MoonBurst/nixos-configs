import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend"
import "../../../style" as Style
import "../../../common/Utils.js" as Utils

Item {
    id: viewRoot

    required property CalcEngine engine
    property var theme: null
    property var settingsManager: null

    readonly property int fieldHeight: settingsManager
        ? settingsManager.getWindowFieldHeight("calc", 54) : 54
    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize : 18

    readonly property int controlBorderWidth: (settingsManager && settingsManager.controlBorderWidth)
        ? settingsManager.controlBorderWidth
        : ((theme && theme.controlBorderWidth) ? theme.controlBorderWidth : 2)

    readonly property var inputPad: Utils.getSafeInputPadding(settingsManager)

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
        anchors.margins: 10
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
                borderColor: calcField.activeFocus
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
                        var inGrid = engine.resultString.indexOf("\n") !== -1;
                        var rowCount = inGrid ? engine.resultString.split("\n").length : 0;

                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (inGrid) {
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
                        } else if (inGrid && (event.key === Qt.Key_Down || event.key === Qt.Key_Up ||
                                             event.key === Qt.Key_Right || event.key === Qt.Key_Left)) {
                            var cols = 3;
                            var cur = engine.selectedGridIndex;
                            if (event.key === Qt.Key_Down)       cur += cols;
                            else if (event.key === Qt.Key_Up)    cur -= cols;
                            else if (event.key === Qt.Key_Right) cur += 1;
                            else if (event.key === Qt.Key_Left)  cur -= 1;
                            if (cur < 0) cur = 0;
                            if (cur >= rowCount) cur = rowCount - 1;
                            engine.selectedGridIndex = cur;
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Style.ShapeBox {
                anchors.fill: parent
                role: "input"
                color: (theme && theme.base00) ? theme.base00 : "#11111b"
                borderColor: (theme && theme.base03) ? theme.base03 : "#45475a"
                borderWidth: viewRoot.controlBorderWidth
                slantWidth: 14
            }

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
                        delegate: Item {
                            readonly property var parts: modelData.split("|")
                            readonly property string cCode: parts.length > 3 ? parts[1] : ""
                            readonly property string cVal: parts.length > 3 ? parts[3] : modelData
                            readonly property bool isSelected: index === engine.selectedGridIndex
                            width: Math.floor((parent.width - 20) / 3)
                            height: Math.floor((parent.height - 30) / 4)

                            Style.ShapeBox {
                                anchors.fill: parent
                                role: "input"
                                color: parent.isSelected ? ((theme && theme.base02) ? theme.base02 : "#333") : "transparent"
                                borderColor: parent.isSelected ? "#04f100" : ((theme && theme.base03) ? theme.base03 : "#45475a")
                                borderWidth: viewRoot.controlBorderWidth
                                slantWidth: 8
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: cCode
                                    font.bold: true
                                    font.pixelSize: Math.max(11, viewRoot.overlayFontSize - 4)
                                    color: isSelected ? "#04f100" : "yellow"
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: cVal
                                    font.bold: true
                                    font.pixelSize: Math.max(14, viewRoot.overlayFontSize)
                                    color: isSelected ? "#04f100" : "yellow"
                                }
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
