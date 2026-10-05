import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../../../settings"

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
                    border.width: 2
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

        // 1. Overlay Window Cards Shape Selector
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
                spacing: 10

                Repeater {
                    model: [
                        { id: "rounded", label: "⬛ Rounded Rectangle", desc: "Clean modern rounded borders" },
                        { id: "slant",   label: "▱ Slanted Box",       desc: "Cyberpunk angled parallel edges" },
                        { id: "hexagon", label: "⬡ Hexagon (Wide Top)", desc: "Chamfered hexagonal card geometry" }
                    ]
                    delegate: Rectangle {
                        readonly property bool isSelected: (settingsManager ? settingsManager.overlayCardShape : "rounded") === modelData.id
                        Layout.fillWidth: true
                        height: Math.max(40, panelRoot.liveFontSize * 2.2)
                        radius: 8
                        color: isSelected ? panelRoot.liveBase05 : panelRoot.liveBase00
                        border.color: panelRoot.liveBase05
                        border.width: isSelected ? 2 : 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                text: modelData.label
                                font.bold: true
                                font.pixelSize: Math.max(11, panelRoot.liveFontSize - 2)
                                color: isSelected ? panelRoot.liveBase00 : panelRoot.liveBase05
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: modelData.desc
                                font.pixelSize: 9
                                color: isSelected ? "#333" : "#888"
                                anchors.horizontalCenter: parent.horizontalCenter
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

        // Live Sliders for Card Slant Angle and Hexagon Chamfer Cut
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

        // 2. Input Fields & Bubble Selectors Shape Selector
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
                spacing: 10

                Repeater {
                    model: [
                        { id: "rounded", label: "⬛ Standard Rounded", desc: "Soft border curves" },
                        { id: "slant",   label: "▱ Slanted Parallelogram", desc: "Angled input fields" },
                        { id: "hexagon", label: "⬡ Hexagonal Chamfer", desc: "Corner chamfered inputs" }
                    ]
                    delegate: Rectangle {
                        readonly property bool isSelected: (settingsManager ? settingsManager.inputFieldShape : "rounded") === modelData.id
                        Layout.fillWidth: true
                        height: Math.max(40, panelRoot.liveFontSize * 2.2)
                        radius: 8
                        color: isSelected ? panelRoot.liveBase0C : panelRoot.liveBase00
                        border.color: panelRoot.liveBase0C
                        border.width: isSelected ? 2 : 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                text: modelData.label
                                font.bold: true
                                font.pixelSize: Math.max(11, panelRoot.liveFontSize - 2)
                                color: isSelected ? "#000000" : panelRoot.liveBase0C
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: modelData.desc
                                font.pixelSize: 9
                                color: isSelected ? "#222" : "#888"
                                anchors.horizontalCenter: parent.horizontalCenter
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

        // Live Sliders for Input Slant Angle and Hexagon Chamfer Cut
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
