import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import "../../../style" as Style
import "../../../common/Utils.js" as Utils

Item {
    id: viewRoot

    property var shell: null
    property Item dragTarget: null
    property real dragMaxX: 0
    property real dragMaxY: 0
    property bool isPreviewMode: false
    property bool isCardActive: true
    property int currentScreenIndex: 0

    readonly property var settingsManager: (shell && shell.settingsManager) ? shell.settingsManager : null
    readonly property var theme: (shell && shell.theme) ? shell.theme : null

    readonly property color themeBase00: (theme && theme.base00) ? theme.base00 : "#11111b"
    readonly property color themeBase01: (theme && theme.base01) ? theme.base01 : "#181825"
    readonly property color themeBase02: (theme && theme.base02) ? theme.base02 : "#313244"
    readonly property color themeBase03: (theme && theme.base03) ? theme.base03 : "#45475a"
    readonly property color themeBase05: (theme && theme.base05) ? theme.base05 : "yellow"
    readonly property color themeBase08: (theme && theme.base08) ? theme.base08 : "#ff5555"
    readonly property color themeBase09: (theme && theme.base09) ? theme.base09 : "#fe8019"
    readonly property color themeBase0C: (theme && theme.base0C) ? theme.base0C : "#04f100"
    readonly property color themeBase0D: (theme && theme.base0D) ? theme.base0D : "#003399"
    readonly property string themeFont: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
    readonly property int globalBorderWidth: (theme && theme.globalBorderWidth !== undefined) ? theme.globalBorderWidth : 3
    readonly property int controlBorderWidth: (settingsManager && settingsManager.controlBorderWidth) ? settingsManager.controlBorderWidth : 2
    readonly property var inputPad: Utils.getSafeInputPadding(settingsManager)
    readonly property var safePad: Utils.getSafeCardPadding(settingsManager)

    readonly property color activeBorderColor: (theme && theme.base03) ? theme.base03 : "#003399"
    readonly property color inactiveBorderColor: (theme && theme.base0D) ? theme.base0D : "#003399"

    // Grid layout adapts to the window aspect ratio: wide windows get 6 columns,
    // taller-than-wide windows fall back to 5, 4, or 3 columns.
    readonly property int crewCount: 18
    readonly property int crewSpacing: 8
    readonly property int gridColumns: {
        var aspect = width / Math.max(1, height);
        if (aspect >= 1.25) return 6;
        if (aspect >= 0.95) return 5;
        if (aspect >= 0.70) return 4;
        return 3;
    }
    readonly property int gridRows: Math.max(1, Math.ceil(crewCount / gridColumns))
    readonly property real cellW: Math.max(20, (crewGrid.width  - (gridColumns - 1) * crewSpacing) / gridColumns)
    readonly property real cellH: Math.max(20, (crewGrid.height - (gridRows    - 1) * crewSpacing) / gridRows)
    readonly property real iconD:  Math.max(16, Math.min(cellW, cellH) * 0.55)
    readonly property int  nameSize: Math.max(8, Math.min(16, Math.floor(Math.min(cellW, cellH) * 0.18)))
    readonly property int  headerFontSize: Math.max(11, Math.min(18, Math.floor(height * 0.032)))

    signal closeRequested()
    signal screenSelected(int index)

    property var crewmates: [
        { name: "Red",     hex: "#C51111", darkHex: "#7A0808", dead: false },
        { name: "Blue",    hex: "#132ED1", darkHex: "#09158E", dead: false },
        { name: "Green",   hex: "#117F2D", darkHex: "#0A4D1A", dead: false },
        { name: "Pink",    hex: "#ED54BA", darkHex: "#AB2B87", dead: false },
        { name: "Orange",  hex: "#EF7D0D", darkHex: "#B04B00", dead: false },
        { name: "Yellow",  hex: "#F5F557", darkHex: "#C2B219", dead: false },
        { name: "Black",   hex: "#3F474E", darkHex: "#1E1F26", dead: false },
        { name: "White",   hex: "#D6E0F0", darkHex: "#8394BF", dead: false },
        { name: "Purple",  hex: "#6B2FBB", darkHex: "#3B177C", dead: false },
        { name: "Brown",   hex: "#71491E", darkHex: "#46290C", dead: false },
        { name: "Cyan",    hex: "#38FEDC", darkHex: "#24A894", dead: false },
        { name: "Lime",    hex: "#50EF39", darkHex: "#249514", dead: false },
        { name: "Maroon",  hex: "#5F1F2E", darkHex: "#370914", dead: false },
        { name: "Rose",    hex: "#ECC0D3", darkHex: "#A9768B", dead: false },
        { name: "Banana",  hex: "#FFFEA7", darkHex: "#C5C073", dead: false },
        { name: "Gray",    hex: "#758593", darkHex: "#465058", dead: false },
        { name: "Tan",     hex: "#918877", darkHex: "#5E5648", dead: false },
        { name: "Coral",   hex: "#D76464", darkHex: "#963434", dead: false }
    ]

    property var crewModel: []

    function initModel() {
        var arr = [];
        for (var i = 0; i < crewmates.length; i++) {
            arr.push(Object.assign({}, crewmates[i]));
        }
        crewModel = arr;
    }

    Component.onCompleted: initModel()

    function toggleColor(idx) {
        if (idx < 0 || idx >= crewModel.length) return;
        var copy = crewModel.slice();
        copy[idx].dead = !copy[idx].dead;
        crewModel = copy;
    }

    function resetAll() {
        var copy = crewModel.slice();
        for (var i = 0; i < copy.length; i++) {
            copy[i].dead = false;
        }
        crewModel = copy;
    }

    readonly property int aliveCount: {
        var count = 0;
        for (var i = 0; i < crewModel.length; i++) {
            if (!crewModel[i].dead) count++;
        }
        return count;
    }

    readonly property int deadCount: crewModel.length - aliveCount

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: viewRoot.safePad.h
        anchors.rightMargin: viewRoot.safePad.h
        anchors.topMargin: viewRoot.safePad.v
        anchors.bottomMargin: viewRoot.safePad.v
        spacing: 12

        Rectangle {
            visible: viewRoot.isPreviewMode
            Layout.fillWidth: true
            height: 24
            radius: 4
            color: viewRoot.themeBase0C
            Text {
                anchors.centerIn: parent
                text: "👁 AMONG US PREVIEW — Click to Close"
                font.bold: true; font.pixelSize: 10; color: "#000"
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: viewRoot.closeRequested()
            }
        }

        Item {
            id: titleBarBox
            Layout.fillWidth: true
            height: Math.max(38, viewRoot.headerFontSize * 2.6)

            Style.ShapeBox {
                anchors.fill: parent
                role: "input"
                color: viewRoot.themeBase01
                borderColor: viewRoot.isCardActive ? viewRoot.activeBorderColor : viewRoot.inactiveBorderColor
                borderWidth: viewRoot.controlBorderWidth
                slantWidth: 10
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                drag.target: viewRoot.dragTarget
                drag.minimumX: 0
                drag.minimumY: 0
                drag.maximumX: viewRoot.dragMaxX
                drag.maximumY: viewRoot.dragMaxY
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.max(14, viewRoot.inputPad.left)
                anchors.rightMargin: Math.max(14, viewRoot.inputPad.right)
                spacing: 8

                Text {
                    text: "ඞ AMONG US"
                    font.family: viewRoot.themeFont
                    font.pixelSize: viewRoot.headerFontSize
                    font.bold: true
                    color: viewRoot.themeBase05
                }

                Row {
                    spacing: 4
                    visible: Quickshell.screens.length > 1

                    Repeater {
                        model: Quickshell.screens
                        delegate: Item {
                            width: scrText.implicitWidth + 16
                            height: 24
                            z: 10

                            Style.ShapeBox {
                                anchors.fill: parent
                                role: "input"
                                slantWidth: 6
                                color: viewRoot.currentScreenIndex === index ? viewRoot.themeBase05 : viewRoot.themeBase02
                                borderColor: viewRoot.themeBase05
                                borderWidth: viewRoot.controlBorderWidth
                            }

                            Text {
                                id: scrText
                                anchors.centerIn: parent
                                text: modelData.name || ("Scr " + (index + 1))
                                font.pixelSize: Math.max(9, viewRoot.headerFontSize - 6)
                                font.bold: true
                                color: viewRoot.currentScreenIndex === index ? viewRoot.themeBase00 : viewRoot.themeBase05
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: viewRoot.screenSelected(index)
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: viewRoot.aliveCount + " alive • " + viewRoot.deadCount + " dead"
                    font.family: "monospace"
                    font.pixelSize: Math.max(10, viewRoot.headerFontSize - 4)
                    font.bold: true
                    color: viewRoot.deadCount > 0 ? viewRoot.themeBase09 : viewRoot.themeBase0C
                }

                Item {
                    width: Math.max(64, viewRoot.headerFontSize * 5)
                    height: 26
                    z: 10

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 6
                        color: resetHov.hovered ? viewRoot.themeBase05 : "transparent"
                        borderColor: viewRoot.themeBase05
                        borderWidth: viewRoot.controlBorderWidth
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "↺ Reset"
                        font.bold: true
                        font.pixelSize: Math.max(10, viewRoot.headerFontSize - 4)
                        color: resetHov.hovered ? viewRoot.themeBase00 : viewRoot.themeBase05
                    }

                    HoverHandler { id: resetHov }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: viewRoot.resetAll()
                    }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    z: 10
                    color: closeHov.hovered ? viewRoot.themeBase08 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.bold: true
                        font.pixelSize: 13
                        color: closeHov.hovered ? "#000000" : viewRoot.themeBase05
                    }

                    HoverHandler { id: closeHov }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: viewRoot.closeRequested()
                    }
                }
            }
        }

        Grid {
            id: crewGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: viewRoot.gridColumns
            columnSpacing: viewRoot.crewSpacing
            rowSpacing: viewRoot.crewSpacing

            Repeater {
                model: viewRoot.crewModel

                delegate: Item {
                    id: crewCard
                    readonly property var crewItem: modelData
                    readonly property bool isDead: crewItem.dead

                    width: viewRoot.cellW
                    height: viewRoot.cellH

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 8
                        color: crewCard.isDead ? "#121218" : "#1a1a24"
                        borderColor: crewCard.isDead ? "#2a2a38" : crewItem.hex
                        borderWidth: viewRoot.controlBorderWidth
                    }

                    opacity: isDead ? 0.28 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: Math.max(2, viewRoot.cellH * 0.05)

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: viewRoot.iconD
                            height: viewRoot.iconD * 1.15
                            radius: viewRoot.iconD * 0.4
                            color: isDead ? "#333333" : crewItem.hex
                            border.color: isDead ? "#222222" : crewItem.darkHex
                            border.width: 1.5

                            Rectangle {
                                x: parent.width * 0.28
                                y: parent.height * 0.25
                                width: parent.width * 0.65
                                height: parent.height * 0.35
                                radius: height / 2
                                color: isDead ? "#555555" : "#99d9ea"

                                Rectangle {
                                    x: parent.width * 0.15
                                    y: parent.height * 0.15
                                    width: parent.width * 0.4
                                    height: parent.height * 0.35
                                    radius: height / 2
                                    color: "#ffffff"
                                    opacity: 0.8
                                }
                            }

                            Text {
                                visible: crewCard.isDead
                                anchors.centerIn: parent
                                text: "✕"
                                font.bold: true
                                font.pixelSize: parent.width * 0.75
                                color: "#ff4444"
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: crewItem.name.toUpperCase()
                            font.family: viewRoot.themeFont
                            font.pixelSize: viewRoot.nameSize
                            font.bold: true
                            font.strikeout: crewCard.isDead
                            color: crewCard.isDead ? "#555566" : viewRoot.themeBase05
                            elide: Text.ElideRight
                            width: Math.max(10, viewRoot.cellW - 4)
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: viewRoot.toggleColor(index)
                    }
                }
            }
        }
    }
}
