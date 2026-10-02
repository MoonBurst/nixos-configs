import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15

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
    contentHeight: tab1Layout.implicitHeight + 80
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

    ColumnLayout {
        id: tab1Layout
        width: parent.width - 16
        spacing: panelRoot.livePadding

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
    }
}
