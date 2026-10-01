import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15

Rectangle {
    id: inspectorRoot

    property string windowId: ""
    property var settingsManager: null
    property var theme: null

    property int defaultW: 840
    property int defaultH: 600
    property int defaultFH: 52
    property int defaultIS: 38
    property bool hasField: false
    property bool hasIcon: false
    property string defaultPolicy: "lazy"

    signal doneRequested()

    // PINNED TO STATIC SCREEN POSITION: Fixed to right side of viewport
    anchors.right: parent ? parent.right : undefined
    anchors.rightMargin: 40
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    z: 99999

    width: 320
    height: contentCol.implicitHeight + 28
    radius: (theme && theme.defaultCardRadius) ? theme.defaultCardRadius : 10
    color: (theme && theme.base00) ? theme.base00 : "#11111b"
    border.color: (theme && theme.base05) ? theme.base05 : "yellow"
    border.width: (theme && theme.globalBorderWidth) ? theme.globalBorderWidth : 2
    clip: true

    readonly property color base00: (theme && theme.base00) ? theme.base00 : "#11111b"
    readonly property color base02: (theme && theme.base02) ? theme.base02 : "#313244"
    readonly property color base03: (theme && theme.base03) ? theme.base03 : "#45475a"
    readonly property color base05: (theme && theme.base05) ? theme.base05 : "yellow"
    readonly property color base08: (theme && theme.base08) ? theme.base08 : "#ff5555"
    readonly property color base0C: (theme && theme.base0C) ? theme.base0C : "#04f100"
    readonly property int liveFontSize: (settingsManager && settingsManager.overlayFontSize > 0) ? settingsManager.overlayFontSize : 15

    MouseArea {
        anchors.fill: parent
        preventStealing: true
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Header
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "📐 " + inspectorRoot.windowId.toUpperCase()
                font.bold: true
                font.pixelSize: Math.max(12, inspectorRoot.liveFontSize - 1)
                color: inspectorRoot.base05
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Rectangle {
                width: 70; height: 26; radius: 4
                color: doneHov.hovered ? inspectorRoot.base05 : inspectorRoot.base02
                border.color: inspectorRoot.base05; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "✓ Done"
                    font.bold: true
                    font.pixelSize: 11
                    color: doneHov.hovered ? inspectorRoot.base00 : inspectorRoot.base05
                }
                HoverHandler { id: doneHov }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: inspectorRoot.doneRequested()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: inspectorRoot.base03 }

        // Width Slider
        CyberSlider {
            label: "Width"
            from: 400; to: 1600; stepSize: 20; unit: "px"
            value: settingsManager ? settingsManager.getWindowWidth(inspectorRoot.windowId, inspectorRoot.defaultW) : inspectorRoot.defaultW
            fontSize: inspectorRoot.liveFontSize - 2
            theme: inspectorRoot.theme; Layout.fillWidth: true
            onValueModified: (v) => { if (settingsManager) settingsManager.setWindowProp(inspectorRoot.windowId, "width", v); }
        }

        // Height Slider
        CyberSlider {
            label: "Height"
            from: 250; to: 1050; stepSize: 25; unit: "px"
            value: settingsManager ? settingsManager.getWindowHeight(inspectorRoot.windowId, inspectorRoot.defaultH) : inspectorRoot.defaultH
            fontSize: inspectorRoot.liveFontSize - 2
            theme: inspectorRoot.theme; Layout.fillWidth: true
            onValueModified: (v) => { if (settingsManager) settingsManager.setWindowProp(inspectorRoot.windowId, "height", v); }
        }

        // Search Field Height
        CyberSlider {
            visible: inspectorRoot.hasField
            label: "Field Height"
            from: 36; to: 200; stepSize: 2; unit: "px"
            value: settingsManager ? settingsManager.getWindowFieldHeight(inspectorRoot.windowId, inspectorRoot.defaultFH) : inspectorRoot.defaultFH
            fontSize: inspectorRoot.liveFontSize - 2
            theme: inspectorRoot.theme; Layout.fillWidth: true
            onValueModified: (v) => { if (settingsManager) settingsManager.setWindowProp(inspectorRoot.windowId, "fieldHeight", v); }
        }

        // Icon Size
        CyberSlider {
            visible: inspectorRoot.hasIcon
            label: "Icon Size"
            from: 20; to: 100; stepSize: 2; unit: "px"
            value: settingsManager ? settingsManager.getWindowIconSize(inspectorRoot.windowId, inspectorRoot.defaultIS) : inspectorRoot.defaultIS
            fontSize: inspectorRoot.liveFontSize - 2
            theme: inspectorRoot.theme; Layout.fillWidth: true
            onValueModified: (v) => {
                if (settingsManager) {
                    settingsManager.setWindowProp(inspectorRoot.windowId, "iconSize", v);
                    settingsManager.setWindowProp(inspectorRoot.windowId, "imageSize", v);
                }
            }
        }

        // Loading Mode Selector
        RowLayout {
            Layout.fillWidth: true; spacing: 6

            Text {
                text: "Mode:"
                font.bold: true; font.pixelSize: 11
                color: inspectorRoot.base05
            }

            Rectangle {
                readonly property bool isEager: (settingsManager ? settingsManager.getWindowLoadPolicy(inspectorRoot.windowId, inspectorRoot.defaultPolicy) : inspectorRoot.defaultPolicy) === "eager"
                Layout.fillWidth: true; height: 24; radius: 4
                color: isEager ? inspectorRoot.base0C : inspectorRoot.base02
                border.color: isEager ? inspectorRoot.base0C : inspectorRoot.base05; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "⚡ Eager"
                    font.bold: true; font.pixelSize: 10
                    color: parent.isEager ? "#000" : inspectorRoot.base05
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (settingsManager) settingsManager.setWindowLoadPolicy(inspectorRoot.windowId, "eager")
                }
            }

            Rectangle {
                readonly property bool isLazy: (settingsManager ? settingsManager.getWindowLoadPolicy(inspectorRoot.windowId, inspectorRoot.defaultPolicy) : inspectorRoot.defaultPolicy) === "lazy"
                Layout.fillWidth: true; height: 24; radius: 4
                color: isLazy ? inspectorRoot.base05 : inspectorRoot.base02
                border.color: inspectorRoot.base05; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "🍃 Lazy"
                    font.bold: true; font.pixelSize: 10
                    color: parent.isLazy ? parent.base00 : inspectorRoot.base05
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (settingsManager) settingsManager.setWindowLoadPolicy(inspectorRoot.windowId, "lazy")
                }
            }
        }
    }
}
