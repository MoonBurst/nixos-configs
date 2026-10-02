import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import "../../../style"
import "../../../settings"

Item {
    id: panelRoot

    property var shell: null
    property var settingsManager: (shell && shell.settingsManager) ? shell.settingsManager : null
    readonly property var theme: (shell && shell.theme) ? shell.theme : null

    readonly property int liveFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize
        : ((theme && theme.globalFontSize) ? theme.globalFontSize : 16)

    readonly property int liveBorderWidth: (theme && theme.globalBorderWidth) ? theme.globalBorderWidth : 2
    readonly property int livePadding: (theme && theme.globalPadding) ? theme.globalPadding : 12
    readonly property int liveSlantWidth: (theme && theme.slantWidth) ? theme.slantWidth : 8
    readonly property color liveBase00: (theme && theme.base00) ? theme.base00 : "#0f0f0f"
    readonly property color liveBase02: (theme && theme.base02) ? theme.base02 : "#1e1e2e"
    readonly property color liveBase03: (theme && theme.base03) ? theme.base03 : "#003399"
    readonly property color liveBase05: (theme && theme.base05) ? theme.base05 : "#f7f700"
    readonly property color liveBase08: (theme && theme.base08) ? theme.base08 : "#ff0000"
    readonly property color liveBase09: (theme && theme.base09) ? theme.base09 : "#fe8019"
    readonly property color liveBase0C: (theme && theme.base0C) ? theme.base0C : "#04f100"
    readonly property string liveFontFamily: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"

    property string editingGpuCard: settingsManager ? settingsManager.activeGpuCard : "card0"

    function slantLeftFor(section) { return (section === "right") ? "Right" : "Left"; }
    function slantRightFor(section) { return (section === "left") ? "Left" : "Right"; }
    function slantGlyphFor(section) {
        if (section === "center") return "\\ /";
        if (section === "right") return "/ /";
        return "\\ \\";
    }

    readonly property int chipSlantWidth: Math.max(4, Math.min(panelRoot.liveSlantWidth, 8))

    anchors.fill: parent
    property int activeTab: 0

    onActiveTabChanged: {
        if (settingsManager && activeTab !== 4 && settingsManager.previewWindow !== "") {
            settingsManager.previewWindow = "";
        }
    }

    onVisibleChanged: {
        if (!visible && settingsManager) {
            settingsManager.previewCapsule = "";
            settingsManager.previewWindow = "";
        }
    }

    ColorPickerPopup {
        id: guiColorPicker
        theme: panelRoot.theme
        onColorSelected: function(propName, hexStr) {
            if (settingsManager && settingsManager[propName] !== undefined) {
                settingsManager.useStylix = false;
                settingsManager[propName] = hexStr;
            }
        }
        onSaveToStylixRequested: function(propName, hexStr) {
            if (settingsManager) {
                settingsManager.saveColorToStylix(propName, hexStr);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: panelRoot.livePadding

        // Tab Headers
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: ["Stylix & Sliders", "Color Palette", "GPU & Hardware", "Bar Layout & Slants", "Overlays & Windows"]
                delegate: Item {
                    Layout.fillWidth: true
                    height: Math.max(34, panelRoot.liveFontSize * 2.0)
                    clip: true

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"; slantRight: "Left"
                        slantWidth: panelRoot.liveSlantWidth
                        color: panelRoot.activeTab === index ? panelRoot.liveBase05 : "transparent"
                        borderColor: panelRoot.liveBase05
                        borderWidth: panelRoot.liveBorderWidth
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: panelRoot.liveSlantWidth + 2
                        anchors.rightMargin: panelRoot.liveSlantWidth + 2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        font.family: panelRoot.liveFontFamily
                        font.pixelSize: Math.max(10, Math.min(14, panelRoot.liveFontSize - 3))
                        font.bold: true
                        elide: Text.ElideRight
                        color: panelRoot.activeTab === index ? panelRoot.liveBase00 : panelRoot.liveBase05
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: panelRoot.activeTab = index
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: panelRoot.liveBorderWidth
            color: panelRoot.liveBase03
        }

        // TAB VIEWS
        TabStylixSliders {
            panelRoot: panelRoot
            visible: panelRoot.activeTab === 0
        }

        TabColorPalette {
            panelRoot: panelRoot
            guiColorPicker: guiColorPicker
            visible: panelRoot.activeTab === 1
        }

        TabGpuHardware {
            panelRoot: panelRoot
            visible: panelRoot.activeTab === 2
        }

        TabBarLayout {
            panelRoot: panelRoot
            visible: panelRoot.activeTab === 3
        }

        TabOverlaysWindows {
            panelRoot: panelRoot
            guiColorPicker: guiColorPicker
            visible: panelRoot.activeTab === 4
        }
    }
}
