import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import "../../../style"
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
    contentHeight: tab0Layout.implicitHeight + 80
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

    ColumnLayout {
        id: tab0Layout
        width: parent.width - 16
        spacing: panelRoot.livePadding

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            CyberToggle {
                label: "Follow Stylix Theme"
                checked: settingsManager ? settingsManager.useStylix : false
                theme: panelRoot.theme
                fontSize: panelRoot.liveFontSize
                onToggled: (st) => {
                    if (settingsManager) settingsManager.useStylix = st;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "🎨 Stylix Colors:"
                font.bold: true
                color: panelRoot.liveBase05
                font.pixelSize: Math.max(12, panelRoot.liveFontSize - 1)
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(32, panelRoot.liveFontSize * 1.9)
                radius: 6
                color: panelRoot.liveBase00
                border.color: panelRoot.liveBase03
                border.width: 1

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    text: "Nix Base16 Color Definitions (theme.nix)"
                    font.family: "monospace"
                    font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                    color: panelRoot.liveBase05
                    elide: Text.ElideMiddle
                }
            }

            Rectangle {
                id: copyNixBtn
                implicitWidth: copyBtnRow.implicitWidth + 28
                implicitHeight: Math.max(32, panelRoot.liveFontSize * 1.9)
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                radius: 6
                color: copyBtnHov.hovered ? panelRoot.liveBase05 : panelRoot.liveBase02
                border.color: panelRoot.liveBase05
                border.width: 1

                Row {
                    id: copyBtnRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "📋"
                        font.pixelSize: Math.max(12, panelRoot.liveFontSize - 2)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Copy Nix Colors"
                        font.bold: true
                        font.pixelSize: Math.max(11, panelRoot.liveFontSize - 3)
                        color: copyBtnHov.hovered ? panelRoot.liveBase00 : panelRoot.liveBase05
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: copyBtnHov }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (settingsManager) {
                            var block = settingsManager.getNixColorBlock();
                            Quickshell.clipboardText = block;
                            Quickshell.execDetached(["notify-send", "-a", "Settings", "🎨 Copied Nix Colors", "Base16 theme block copied to clipboard."]);
                        }
                    }
                }
            }
        }

        CyberSlider {
            label: "Global Overlays Text / Font Size"
            from: 11; to: 32; stepSize: 1; unit: "px"
            value: settingsManager ? settingsManager.overlayFontSize : 16
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme
            onValueModified: (v) => { if (settingsManager) settingsManager.overlayFontSize = Math.round(v); }
        }

        CyberSlider {
            label: "Top Bar Height"
            from: 32; to: 64; stepSize: 2; unit: "px"
            value: settingsManager ? settingsManager.barHeight : 42
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme
            onValueModified: (v) => { if (settingsManager) settingsManager.barHeight = Math.round(v); }
        }

        CyberSlider {
            label: "Capsule Spacing"
            from: -100; to: 20; stepSize: 1; unit: "px"
            value: settingsManager ? settingsManager.capsuleSpacing : 2
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme
            onValueModified: (v) => { if (settingsManager) settingsManager.capsuleSpacing = v; }
        }

        CyberSlider {
            label: "Global Font Size (Bar)"
            from: 10; to: 24; stepSize: 1; unit: "px"
            value: settingsManager ? settingsManager.globalFontSize : 14
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme
            onValueModified: (v) => { if (settingsManager) { settingsManager.useStylix = false; settingsManager.globalFontSize = v; } }
        }

        CyberSlider {
            label: "Capsule Slant Width"
            from: 4; to: 24; stepSize: 1; unit: "px"
            value: settingsManager ? settingsManager.slantWidth : 12
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme
            onValueModified: (v) => { if (settingsManager) { settingsManager.useStylix = false; settingsManager.slantWidth = v; } }
        }

        // Slider goes up to 12px
        CyberSlider {
            label: "Window & Card Border Width"
            from: 1; to: 12; stepSize: 1; unit: "px"
            value: settingsManager ? settingsManager.globalBorderWidth : 3
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme
            onValueModified: (v) => { if (settingsManager) { settingsManager.useStylix = false; settingsManager.globalBorderWidth = Math.round(v); } }
        }

        // Slider goes up to 12px
        CyberSlider {
            label: "Inner Element & Button Border Width"
            from: 1; to: 12; stepSize: 1; unit: "px"
            value: settingsManager ? settingsManager.controlBorderWidth : 2
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme
            onValueModified: (v) => { if (settingsManager) settingsManager.controlBorderWidth = Math.round(v); }
        }
    }
}
