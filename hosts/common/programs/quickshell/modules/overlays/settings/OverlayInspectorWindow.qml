import "../../common" as Common
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import "../../settings"

PanelWindow {
    id: inspectorWindow

    property var shell: null
    readonly property var safeShell: (typeof shell !== "undefined" && shell) ? shell : null
    readonly property var settingsManager: safeShell ? safeShell.settingsManager : null
    readonly property var theme: safeShell ? safeShell.theme : null

    readonly property string previewId: settingsManager ? settingsManager.previewWindow : ""
    visible: previewId !== ""

    screen: safeShell?.primaryScreen ?? Quickshell.screens[0] ?? null

    WlrLayershell.namespace: "quickshell-inspector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        right: true
    }
    margins {
        top: 60
        right: 40
    }

    implicitWidth: 340
    implicitHeight: inspectorCard.implicitHeight
    color: "transparent"

    mask: Region {
        item: inspectorCard
    }

    readonly property var targetConfig: {
        var map = {
            "launcher":   { name: "App Launcher",        defW: 840,  defH: 700, defFH: 52, defIS: 38, hasField: true,  hasIcon: true  },
            "calc":       { name: "Calculator",          defW: 820,  defH: 580, defFH: 54, defIS: 32, hasField: true,  hasIcon: false },
            "clipboard":  { name: "Clipboard Manager",   defW: 1080, defH: 700, defFH: 52, defIS: 36, hasField: true,  hasIcon: false },
            "dictionary": { name: "Dictionary",          defW: 820,  defH: 600, defFH: 52, defIS: 32, hasField: true,  hasIcon: false },
            "unicode":    { name: "Unicode Search",      defW: 780,  defH: 600, defFH: 52, defIS: 32, hasField: true,  hasIcon: false },
            "notes":      { name: "Quick Notes",         defW: 840,  defH: 650, defFH: 52, defIS: 32, hasField: true,  hasIcon: false },
            "pass":       { name: "Password Store",      defW: 820,  defH: 600, defFH: 52, defIS: 32, hasField: true,  hasIcon: false },
            "power":      { name: "Power & Session",     defW: 720,  defH: 560, defFH: 52, defIS: 36, hasField: false, hasIcon: false },
            "todo":       { name: "Todo Task Board",     defW: 860,  defH: 740, defFH: 58, defIS: 32, hasField: true,  hasIcon: false },
            "gemini":     { name: "Gemini AI",           defW: 880,  defH: 720, defFH: 52, defIS: 32, hasField: true,  hasIcon: false },
            "settings":   { name: "Settings",            defW: 1040, defH: 760, defFH: 52, defIS: 32, hasField: false, hasIcon: false },
            "web":        { name: "Web Search",          defW: 780,  defH: 320, defFH: 54, defIS: 32, hasField: true,  hasIcon: false },
            "email":      { name: "Email Client",        defW: 1500, defH: 900, defFH: 48, defIS: 32, hasField: true,  hasIcon: false },
            "amogus":     { name: "Among Us",            defW: 580,  defH: 440, defFH: 38, defIS: 32, hasField: false, hasIcon: false },
            "rng":        { name: "Dice / RNG",          defW: 580,  defH: 840, defFH: 40, defIS: 32, hasField: false, hasIcon: false }
        };
        return map[previewId] || { name: previewId.toUpperCase(), defW: 840, defH: 650, defFH: 52, defIS: 32, hasField: false, hasIcon: false };
    }

    function closePreview() {
        if (settingsManager) {
            settingsManager.previewWindow = "";
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: inspectorWindow.visible
        onActivated: inspectorWindow.closePreview()
    }

    Rectangle {
        id: inspectorCard
        width: 340
        implicitHeight: contentCol.implicitHeight + 28
        height: implicitHeight
        radius: (theme && theme.defaultCardRadius) ? theme.defaultCardRadius : 10
        color: (theme && theme.base00) ? theme.base00 : "#11111b"
        border.color: (theme && theme.base05) ? theme.base05 : "yellow"
        border.width: (theme && theme.globalBorderWidth) ? theme.globalBorderWidth : 2

        readonly property color base00: (theme && theme.base00) ? theme.base00 : "#11111b"
        readonly property color base02: (theme && theme.base02) ? theme.base02 : "#313244"
        readonly property color base03: (theme && theme.base03) ? theme.base03 : "#45475a"
        readonly property color base05: (theme && theme.base05) ? theme.base05 : "yellow"
        readonly property color base0C: (theme && theme.base0C) ? theme.base0C : "#04f100"
        readonly property int liveFontSize: (settingsManager && settingsManager.overlayFontSize > 0) ? settingsManager.overlayFontSize : 15

        ColumnLayout {
            id: contentCol
            width: parent.width - 28
            x: 14; y: 14
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "📐 " + inspectorWindow.targetConfig.name.toUpperCase()
                    font.bold: true
                    font.pixelSize: Math.max(12, inspectorCard.liveFontSize - 1)
                    color: inspectorCard.base05
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: 70; height: 26; radius: 4
                    color: doneHov.hovered ? inspectorCard.base05 : inspectorCard.base02
                    border.color: inspectorCard.base05; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "✓ Done"
                        font.bold: true
                        font.pixelSize: 11
                        color: doneHov.hovered ? inspectorCard.base00 : inspectorCard.base05
                    }
                    HoverHandler { id: doneHov }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: inspectorWindow.closePreview()
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: inspectorCard.base03 }

            // Width Slider
            CyberSlider {
                label: "Width"
                from: 400; to: 1600; stepSize: 20; unit: "px"
                value: settingsManager ? settingsManager.getWindowWidth(inspectorWindow.previewId, inspectorWindow.targetConfig.defW) : inspectorWindow.targetConfig.defW
                fontSize: inspectorCard.liveFontSize - 2
                theme: inspectorWindow.theme; Layout.fillWidth: true
                onValueModified: (v) => { if (settingsManager) settingsManager.setWindowProp(inspectorWindow.previewId, "width", v); }
            }

            // Height Slider
            CyberSlider {
                label: "Height"
                from: 250; to: 1050; stepSize: 25; unit: "px"
                value: settingsManager ? settingsManager.getWindowHeight(inspectorWindow.previewId, inspectorWindow.targetConfig.defH) : inspectorWindow.targetConfig.defH
                fontSize: inspectorCard.liveFontSize - 2
                theme: inspectorWindow.theme; Layout.fillWidth: true
                onValueModified: (v) => { if (settingsManager) settingsManager.setWindowProp(inspectorWindow.previewId, "height", v); }
            }

            // Field Height Slider (if applicable)
            CyberSlider {
                visible: inspectorWindow.targetConfig.hasField
                label: "Field Height"
                from: 36; to: 200; stepSize: 2; unit: "px"
                value: settingsManager ? settingsManager.getWindowFieldHeight(inspectorWindow.previewId, inspectorWindow.targetConfig.defFH) : inspectorWindow.targetConfig.defFH
                fontSize: inspectorCard.liveFontSize - 2
                theme: inspectorWindow.theme; Layout.fillWidth: true
                onValueModified: (v) => { if (settingsManager) settingsManager.setWindowProp(inspectorWindow.previewId, "fieldHeight", v); }
            }

            // Icon Size Slider (if applicable)
            CyberSlider {
                visible: inspectorWindow.targetConfig.hasIcon
                label: "Icon Size"
                from: 20; to: 100; stepSize: 2; unit: "px"
                value: settingsManager ? settingsManager.getWindowIconSize(inspectorWindow.previewId, inspectorWindow.targetConfig.defIS) : inspectorWindow.targetConfig.defIS
                fontSize: inspectorCard.liveFontSize - 2
                theme: inspectorWindow.theme; Layout.fillWidth: true
                onValueModified: (v) => {
                    if (settingsManager) {
                        settingsManager.setWindowProp(inspectorWindow.previewId, "iconSize", v);
                        settingsManager.setWindowProp(inspectorWindow.previewId, "imageSize", v);
                    }
                }
            }

            // Apply to All Overlays Button
            Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 6
                color: applyAllHov.hovered ? inspectorCard.base0C : inspectorCard.base02
                border.color: inspectorCard.base0C
                border.width: 1.5

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "🌐"
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Apply Size to All Overlays"
                        font.bold: true
                        font.pixelSize: 11
                        color: applyAllHov.hovered ? "#000000" : inspectorCard.base0C
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: applyAllHov }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (settingsManager) {
                            settingsManager.applyDimensionsToAll(inspectorWindow.previewId);
                        }
                    }
                }
            }

            // Loading Mode Selector
            RowLayout {
                Layout.fillWidth: true; spacing: 6

                Text {
                    text: "Mode:"
                    font.bold: true; font.pixelSize: 11
                    color: inspectorCard.base05
                }

                Rectangle {
                    readonly property bool isEager: (settingsManager ? settingsManager.getWindowLoadPolicy(inspectorWindow.previewId, "lazy") : "lazy") === "eager"
                    Layout.fillWidth: true; height: 24; radius: 4
                    color: isEager ? inspectorCard.base0C : inspectorCard.base02
                    border.color: isEager ? inspectorCard.base0C : inspectorCard.base05; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "⚡ Eager"
                        font.bold: true; font.pixelSize: 10
                        color: parent.isEager ? "#000" : inspectorCard.base05
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (settingsManager) settingsManager.setWindowLoadPolicy(inspectorWindow.previewId, "eager")
                    }
                }

                Rectangle {
                    readonly property bool isLazy: (settingsManager ? settingsManager.getWindowLoadPolicy(inspectorWindow.previewId, "lazy") : "lazy") === "lazy"
                    Layout.fillWidth: true; height: 24; radius: 4
                    color: isLazy ? inspectorCard.base05 : inspectorCard.base02
                    border.color: inspectorCard.base05; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "🍃 Lazy"
                        font.bold: true; font.pixelSize: 10
                        color: parent.isLazy ? inspectorCard.base00 : inspectorCard.base05
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (settingsManager) settingsManager.setWindowLoadPolicy(inspectorWindow.previewId, "lazy")
                    }
                }
            }
        }
    }
}
