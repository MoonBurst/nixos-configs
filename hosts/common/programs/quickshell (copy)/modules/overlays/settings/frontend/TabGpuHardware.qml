import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../../../settings"

Flickable {
    id: root
    required property var panelRoot

    readonly property var settingsManager: panelRoot.settingsManager
    readonly property var theme: panelRoot.theme

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    flickableDirection: Flickable.VerticalFlick
    pressDelay: 120
    contentWidth: width
    contentHeight: tab2Layout.implicitHeight + 80
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

    ColumnLayout {
        id: tab2Layout
        width: parent.width - 16
        spacing: 16

        Text {
            text: "🎮 GPU ALERT THRESHOLDS & MONITORING"
            font.family: panelRoot.liveFontFamily
            font.pixelSize: panelRoot.liveFontSize + 1
            font.bold: true
            color: panelRoot.liveBase0C
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Select GPU:"
                font.bold: true
                color: panelRoot.liveBase05
                font.pixelSize: panelRoot.liveFontSize - 1
            }

            Repeater {
                model: (settingsManager && settingsManager.availableGpuCards) ? settingsManager.availableGpuCards : [{ id: "card0", name: "GPU 0" }, { id: "card1", name: "GPU 1" }]
                delegate: Rectangle {
                    readonly property bool isSelected: panelRoot.editingGpuCard === modelData.id
                    width: gpuPillText.implicitWidth + 24
                    height: Math.max(30, panelRoot.liveFontSize * 1.8)
                    radius: 6
                    color: isSelected ? panelRoot.liveBase05 : panelRoot.liveBase02
                    border.color: panelRoot.liveBase05
                    border.width: 1

                    Text {
                        id: gpuPillText
                        anchors.centerIn: parent
                        text: modelData.name || modelData.id
                        font.bold: true
                        font.pixelSize: Math.max(10, panelRoot.liveFontSize - 2)
                        color: isSelected ? panelRoot.liveBase00 : panelRoot.liveBase05
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            panelRoot.editingGpuCard = modelData.id;
                            if (settingsManager) settingsManager.activeGpuCard = modelData.id;
                        }
                    }
                }
            }
        }

        CyberSlider {
            label: (panelRoot.editingGpuCard === "card1" ? "GPU 1" : "GPU 0") + " Temperature Warning Threshold"
            from: 40; to: 95; stepSize: 1; unit: "°C"
            value: settingsManager ? settingsManager.getGpuTempWarn(panelRoot.editingGpuCard) : 70
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme
            onValueModified: (v) => { if (settingsManager) settingsManager.setGpuThreshold(panelRoot.editingGpuCard, "tempWarn", v); }
        }

        CyberSlider {
            label: (panelRoot.editingGpuCard === "card1" ? "GPU 1" : "GPU 0") + " Temperature Danger Threshold"
            from: 50; to: 105; stepSize: 1; unit: "°C"
            value: settingsManager ? settingsManager.getGpuTempDanger(panelRoot.editingGpuCard) : 80
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme
            onValueModified: (v) => { if (settingsManager) settingsManager.setGpuThreshold(panelRoot.editingGpuCard, "tempDanger", v); }
        }

        CyberSlider {
            label: (panelRoot.editingGpuCard === "card1" ? "GPU 1" : "GPU 0") + " Free VRAM Warning Threshold"
            from: 1; to: 16; stepSize: 1; unit: "GiB"
            value: settingsManager ? settingsManager.getGpuVramWarn(panelRoot.editingGpuCard) : 4
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme
            onValueModified: (v) => { if (settingsManager) settingsManager.setGpuThreshold(panelRoot.editingGpuCard, "vramWarn", v); }
        }

        CyberSlider {
            label: (panelRoot.editingGpuCard === "card1" ? "GPU 1" : "GPU 0") + " Free VRAM Danger Threshold"
            from: 0; to: 8; stepSize: 1; unit: "GiB"
            value: settingsManager ? settingsManager.getGpuVramDanger(panelRoot.editingGpuCard) : 2
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme
            onValueModified: (v) => { if (settingsManager) settingsManager.setGpuThreshold(panelRoot.editingGpuCard, "vramDanger", v); }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: panelRoot.liveBase03 }

        CyberSlider {
            label: "Hardware Polling Interval"
            from: 1000; to: 10000; stepSize: 500; unit: "ms"
            value: settingsManager ? settingsManager.hardwarePollInterval : 2000
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme
            onValueModified: (v) => { if (settingsManager) settingsManager.hardwarePollInterval = Math.round(v); }
        }
    }
}
