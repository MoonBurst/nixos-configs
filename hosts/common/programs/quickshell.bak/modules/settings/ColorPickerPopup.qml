import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../style"

Item {
    id: pickerRoot

    property color currentColor: "#f7f700"
    property string targetProperty: ""
    property var theme: null

    signal colorSelected(string propName, string hexStr)
    signal closed()

    anchors.fill: parent
    visible: false
    z: 9999

    // Close on backdrop click
    MouseArea {
        anchors.fill: parent
        onClicked: pickerRoot.close()
    }

    function openPicker(propName, initialColor) {
        targetProperty = propName;
        currentColor = initialColor;
        hexInputField.text = initialColor.toString();
        parseRgbToHsv(initialColor);
        visible = true;
    }

    function close() {
        visible = false;
        pickerRoot.closed();
    }

    // HSV State
    property real currentH: 0.16  // 0.0 - 1.0 (Hue)
    property real currentS: 1.0   // 0.0 - 1.0 (Saturation)
    property real currentV: 1.0   // 0.0 - 1.0 (Value/Brightness)

    function updateColorFromHsv() {
        var col = Qt.hsva(currentH, currentS, currentV, 1.0);
        currentColor = col;
        hexInputField.text = col.toString();
    }

    function parseRgbToHsv(col) {
        var r = col.r, g = col.g, b = col.b;
        var max = Math.max(r, g, b), min = Math.min(r, g, b);
        var d = max - min;
        currentV = max;
        currentS = max === 0 ? 0 : d / max;

        if (max === min) {
            currentH = 0;
        } else {
            if (max === r) currentH = (g - b) / d + (g < b ? 6 : 0);
            else if (max === g) currentH = (b - r) / d + 2;
            else if (max === b) currentH = (r - g) / d + 4;
            currentH /= 6;
        }
        svCanvas.requestPaint();
    }

    // Modal Box
    Rectangle {
        id: pickerBox
        width: 380
        height: 440
        anchors.centerIn: parent
        radius: 12
        color: (theme && theme.base00) ? theme.base00 : "#11111b"
        border.color: (theme && theme.base05) ? theme.base05 : "yellow"
        border.width: (theme && theme.globalBorderWidth) ? theme.globalBorderWidth : 2
        clip: true

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: "🎨 GUI COLOR PICKER"
                font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                font.pixelSize: (theme && theme.globalFontSize) ? theme.globalFontSize : 14
                font.bold: true
                color: (theme && theme.base05) ? theme.base05 : "yellow"
            }

            // 1. 2D SATURATION & VALUE CANVAS
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 180

                Canvas {
                    id: svCanvas
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();

                        // Base pure hue fill
                        ctx.fillStyle = Qt.hsva(pickerRoot.currentH, 1.0, 1.0, 1.0);
                        ctx.fillRect(0, 0, width, height);

                        // Horizontal white gradient (Saturation: 0 -> 1)
                        var gradWhite = ctx.createLinearGradient(0, 0, width, 0);
                        gradWhite.addColorStop(0, "rgba(255,255,255,1)");
                        gradWhite.addColorStop(1, "rgba(255,255,255,0)");
                        ctx.fillStyle = gradWhite;
                        ctx.fillRect(0, 0, width, height);

                        // Vertical black gradient (Value: 1 -> 0)
                        var gradBlack = ctx.createLinearGradient(0, 0, 0, height);
                        gradBlack.addColorStop(0, "rgba(0,0,0,0)");
                        gradBlack.addColorStop(1, "rgba(0,0,0,1)");
                        ctx.fillStyle = gradBlack;
                        ctx.fillRect(0, 0, width, height);
                    }
                }

                // Drag indicator ring
                Rectangle {
                    width: 14; height: 14; radius: 7
                    x: Math.max(0, Math.min(parent.width - width, pickerRoot.currentS * parent.width - width/2))
                    y: Math.max(0, Math.min(parent.height - height, (1.0 - pickerRoot.currentV) * parent.height - height/2))
                    color: "transparent"
                    border.color: "#ffffff"; border.width: 2
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    function updatePos(mouse) {
                        pickerRoot.currentS = Math.max(0.0, Math.min(1.0, mouse.x / parent.width));
                        pickerRoot.currentV = Math.max(0.0, Math.min(1.0, 1.0 - (mouse.y / parent.height)));
                        pickerRoot.updateColorFromHsv();
                    }
                    onPressed: (mouse) => updatePos(mouse)
                    onPositionChanged: (mouse) => updatePos(mouse)
                }
            }

            // 2. HUE SPECTRUM SLIDER
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 26

                Canvas {
                    id: hueCanvas
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d");
                        var grad = ctx.createLinearGradient(0, 0, width, 0);
                        var stops = ["#ff0000", "#ffff00", "#00ff00", "#00ffff", "#0000ff", "#ff00ff", "#ff0000"];
                        for (var i = 0; i < stops.length; i++) {
                            grad.addColorStop(i / (stops.length - 1), stops[i]);
                        }
                        ctx.fillStyle = grad;
                        ctx.fillRect(0, 0, width, height);
                    }
                }

                Rectangle {
                    width: 8; height: parent.height + 4
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(parent.width - width, pickerRoot.currentH * parent.width - width/2))
                    color: "transparent"
                    border.color: "#ffffff"; border.width: 2
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    function updateHue(mouse) {
                        pickerRoot.currentH = Math.max(0.0, Math.min(1.0, mouse.x / parent.width));
                        svCanvas.requestPaint();
                        pickerRoot.updateColorFromHsv();
                    }
                    onPressed: (mouse) => updateHue(mouse)
                    onPositionChanged: (mouse) => updateHue(mouse)
                }
            }

            // 3. COLOR PREVIEW & QUICK PRESETS
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 44; height: 32; radius: 6
                    color: pickerRoot.currentColor
                    border.color: "#ffffff"; border.width: 1.5
                }

                TextField {
                    id: hexInputField
                    Layout.fillWidth: true
                    text: pickerRoot.currentColor.toString()
                    font.family: "monospace"
                    font.pixelSize: 13
                    color: (theme && theme.base05) ? theme.base05 : "yellow"
                    background: Rectangle {
                        color: (theme && theme.base02) ? theme.base02 : "#1e1e2e"
                        border.color: (theme && theme.base03) ? theme.base03 : "#45475a"
                        border.width: 1; radius: 6
                    }
                    onTextChanged: {
                        if (text.length === 7 && text.startsWith("#")) {
                            pickerRoot.currentColor = text;
                            pickerRoot.parseRgbToHsv(pickerRoot.currentColor);
                        }
                    }
                }
            }

            // Preset Swatches
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: ["#11111b", "#003399", "#f7f700", "#ff5555", "#a6e3a1", "#675ddb", "#fabd2f", "#ffffff"]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 4
                        color: modelData
                        border.width: 1; border.color: "#ffffff"

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pickerRoot.currentColor = modelData;
                                hexInputField.text = modelData;
                                pickerRoot.parseRgbToHsv(Qt.color(modelData));
                            }
                        }
                    }
                }
            }

            // 4. ACTION BUTTONS
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true; height: 34; radius: 6
                    color: (theme && theme.base02) ? theme.base02 : "#313244"
                    border.color: (theme && theme.base03) ? theme.base03 : "#45475a"; border.width: 1
                    Text { anchors.centerIn: parent; text: "Cancel"; font.bold: true; color: (theme && theme.base05) ? theme.base05 : "yellow" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pickerRoot.close() }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 34; radius: 6
                    color: (theme && theme.base05) ? theme.base05 : "yellow"
                    Text { anchors.centerIn: parent; text: "✔ Apply Color"; font.bold: true; color: "#11111b" }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pickerRoot.colorSelected(pickerRoot.targetProperty, pickerRoot.currentColor.toString());
                            pickerRoot.close();
                        }
                    }
                }
            }
        }
    }
}
