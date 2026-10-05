import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../../../settings"
import "../../../style" as Style

Flickable {
    id: root
    required property var panelRoot
    required property var guiColorPicker

    readonly property var settingsManager: panelRoot.settingsManager

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    flickableDirection: Flickable.VerticalFlick
    pressDelay: 120
    contentWidth: width
    contentHeight: tab1Layout.implicitHeight + 120
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

    ColumnLayout {
        id: tab1Layout
        width: parent.width - 16
        spacing: panelRoot.livePadding

        Text {
            text: "🎨 PALETTE & SYSTEM ACCENT COLORS"
            font.family: panelRoot.liveFontFamily
            font.pixelSize: panelRoot.liveFontSize + 1
            font.bold: true
            color: panelRoot.liveBase0C
        }

        Repeater {
            model: [
                { name: "Primary Background (base00)", prop: "customBase00", def: "#0f0f0f" },
                { name: "Slanted Bar Border (base03)", prop: "customBase03", def: "#003399" },
                { name: "Primary Accent / Text (base05)", prop: "customBase05", def: "#f7f700" },
                { name: "Danger / Alert Red (base08)", prop: "customBase08", def: "#ff0000" },
                { name: "Warning / Orange (base09)", prop: "customBase09", def: "#fe8019" },
                { name: "Success / Green (base0C)", prop: "customBase0C", def: "#04f100" },
                { name: "Accent Blue / Focus (base0D)", prop: "customBase0D", def: "#003399" }
            ]
            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: Math.max(34, panelRoot.liveFontSize * 2)
                    height: width
                    radius: 6
                    color: settingsManager ? settingsManager[modelData.prop] : modelData.def
                    border.width: panelRoot.liveBorderWidth
                    border.color: "#ffffff"
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: guiColorPicker.openPicker(modelData.prop, parent.color)
                    }
                }

                Text {
                    text: modelData.name
                    font.family: panelRoot.liveFontFamily
                    font.pixelSize: panelRoot.liveFontSize
                    color: panelRoot.liveBase05
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: panelRoot.liveBase03
        }

        Text {
            text: "📐 OVERLAY SHAPES & ANGLE ADJUSTMENTS"
            font.family: panelRoot.liveFontFamily
            font.pixelSize: panelRoot.liveFontSize + 1
            font.bold: true
            color: panelRoot.liveBase0C
        }

        // 1. Overlay Window Cards Shape Selector: Each button renders in its own shape style
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Overlay Window Cards Shape:"
                font.bold: true
                color: panelRoot.liveBase05
                font.pixelSize: panelRoot.liveFontSize - 1
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: [
                        { id: "rounded", label: "Rounded Rectangle", desc: "Clean modern rounded borders" },
                        { id: "slant",   label: "Slanted Box",       desc: "Cyberpunk angled parallel edges" },
                        { id: "hexagon", label: "Hexagon (Wide Top)", desc: "Chamfered hexagonal card geometry" }
                    ]
                    delegate: Item {
                        readonly property bool isSelected: (settingsManager ? settingsManager.overlayCardShape : "rounded") === modelData.id
                        Layout.fillWidth: true
                        height: Math.max(54, panelRoot.liveFontSize * 2.8)

                        Style.ShapeBox {
                            anchors.fill: parent
                            shapeType: modelData.id
                            role: "custom"
                            slantWidth: 16
                            hexCut: 14
                            radius: 8
                            color: isSelected ? panelRoot.liveBase05 : panelRoot.liveBase00
                            borderColor: isSelected ? panelRoot.liveBase05 : panelRoot.liveBase03
                            borderWidth: panelRoot.liveBorderWidth
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            width: parent.width - 24

                            Text {
                                text: (modelData.id === "rounded" ? "▢ " : (modelData.id === "slant" ? "▱ " : "⬡ ")) + modelData.label
                                font.bold: true
                                font.pixelSize: Math.max(12, panelRoot.liveFontSize - 1)
                                color: isSelected ? panelRoot.liveBase00 : panelRoot.liveBase05
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: modelData.desc
                                font.pixelSize: 10
                                color: isSelected ? "#333333" : "#888888"
                                anchors.horizontalCenter: parent.horizontalCenter
                                elide: Text.ElideRight
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (settingsManager) settingsManager.overlayCardShape = modelData.id
                        }
                    }
                }
            }
        }

        // Slant Direction Options: Left (\ \), Right (/ /), Center (\ /)
        ColumnLayout {
            visible: (settingsManager ? settingsManager.overlayCardShape : "rounded") === "slant"
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Slant Direction for Cards:"
                font.bold: true
                color: panelRoot.liveBase05
                font.pixelSize: panelRoot.liveFontSize - 1
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: [
                        { id: "left",   label: "\\ Left Slant",   sL: "Left",  sR: "Left" },
                        { id: "right",  label: "/ Right Slant",  sL: "Right", sR: "Right" },
                        { id: "center", label: "\\ / Center",     sL: "Left",  sR: "Right" }
                    ]
                    delegate: Item {
                        readonly property bool isCur: (settingsManager ? settingsManager.overlaySlantDirection : "left") === modelData.id
                        Layout.fillWidth: true
                        height: 38

                        Style.ShapeBox {
                            anchors.fill: parent
                            shapeType: "slant"
                            role: "custom"
                            slantWidth: 14
                            slantLeft: modelData.sL
                            slantRight: modelData.sR
                            color: isCur ? panelRoot.liveBase05 : panelRoot.liveBase00
                            borderColor: isCur ? panelRoot.liveBase05 : panelRoot.liveBase03
                            borderWidth: panelRoot.liveBorderWidth
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.bold: true
                            font.pixelSize: Math.max(11, panelRoot.liveFontSize - 2)
                            color: isCur ? panelRoot.liveBase00 : panelRoot.liveBase05
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (settingsManager) settingsManager.overlaySlantDirection = modelData.id
                        }
                    }
                }
            }
        }

        // Sliders for Card Slant Angle and Hexagon Chamfer Cut
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            CyberSlider {
                visible: (settingsManager ? settingsManager.overlayCardShape : "rounded") === "slant"
                label: "Overlay Slant Width / Angle"
                from: 8; to: 100; stepSize: 2; unit: "px"
                value: settingsManager ? settingsManager.overlaySlantAngle : 32
                fontSize: panelRoot.liveFontSize - 2
                theme: panelRoot.theme; Layout.fillWidth: true
                onValueModified: (v) => { if (settingsManager) settingsManager.overlaySlantAngle = Math.round(v); }
            }

            CyberSlider {
                visible: (settingsManager ? settingsManager.overlayCardShape : "rounded") === "hexagon"
                label: "Overlay Hexagon Corner Cut (Wide Top)"
                from: 8; to: 120; stepSize: 2; unit: "px"
                value: settingsManager ? settingsManager.overlayHexagonCut : 36
                fontSize: panelRoot.liveFontSize - 2
                theme: panelRoot.theme; Layout.fillWidth: true
                onValueModified: (v) => { if (settingsManager) settingsManager.overlayHexagonCut = Math.round(v); }
            }
        }

        // 2. Input Fields Shape Selector: Each button renders in its own shape style
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Input Fields & Bubble Selectors Shape:"
                font.bold: true
                color: panelRoot.liveBase05
                font.pixelSize: panelRoot.liveFontSize - 1
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: [
                        { id: "rounded", label: "Standard Rounded", desc: "Soft border curves" },
                        { id: "slant",   label: "Slanted Parallelogram", desc: "Angled input fields" },
                        { id: "hexagon", label: "Hexagonal Chamfer", desc: "Corner chamfered inputs" }
                    ]
                    delegate: Item {
                        readonly property bool isSelected: (settingsManager ? settingsManager.inputFieldShape : "rounded") === modelData.id
                        Layout.fillWidth: true
                        height: Math.max(54, panelRoot.liveFontSize * 2.8)

                        Style.ShapeBox {
                            anchors.fill: parent
                            shapeType: modelData.id
                            role: "custom"
                            slantWidth: 16
                            hexCut: 14
                            radius: 8
                            color: isSelected ? panelRoot.liveBase0C : panelRoot.liveBase00
                            borderColor: isSelected ? panelRoot.liveBase0C : panelRoot.liveBase03
                            borderWidth: panelRoot.liveBorderWidth
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            width: parent.width - 24

                            Text {
                                text: (modelData.id === "rounded" ? "▢ " : (modelData.id === "slant" ? "▱ " : "⬡ ")) + modelData.label
                                font.bold: true
                                font.pixelSize: Math.max(12, panelRoot.liveFontSize - 1)
                                color: isSelected ? "#000000" : panelRoot.liveBase0C
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: modelData.desc
                                font.pixelSize: 10
                                color: isSelected ? "#112211" : "#888888"
                                anchors.horizontalCenter: parent.horizontalCenter
                                elide: Text.ElideRight
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (settingsManager) settingsManager.inputFieldShape = modelData.id
                        }
                    }
                }
            }
        }

        // Sliders for Input Slant Angle and Hexagon Chamfer Cut
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            CyberSlider {
                visible: (settingsManager ? settingsManager.inputFieldShape : "rounded") === "slant"
                label: "Input Field Slant Angle"
                from: 4; to: 40; stepSize: 1; unit: "px"
                value: settingsManager ? settingsManager.inputSlantAngle : 14
                fontSize: panelRoot.liveFontSize - 2
                theme: panelRoot.theme; Layout.fillWidth: true
                onValueModified: (v) => { if (settingsManager) settingsManager.inputSlantAngle = Math.round(v); }
            }

            CyberSlider {
                visible: (settingsManager ? settingsManager.inputFieldShape : "rounded") === "hexagon"
                label: "Input Hexagon Chamfer Cut"
                from: 4; to: 40; stepSize: 1; unit: "px"
                value: settingsManager ? settingsManager.inputHexagonCut : 14
                fontSize: panelRoot.liveFontSize - 2
                theme: panelRoot.theme; Layout.fillWidth: true
                onValueModified: (v) => { if (settingsManager) settingsManager.inputHexagonCut = Math.round(v); }
            }
        }
    }
}
