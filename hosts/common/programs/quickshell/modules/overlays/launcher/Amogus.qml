import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15

Item {
    id: amogusRoot
    anchors.fill: parent
    focus: true

    property var shell: null
    readonly property var theme: (shell && shell.theme) ? shell.theme : null

    // 18 Official Among Us Astronaut Colors
    property var crewmates: [
        { name: "Red",     hex: "#C51111", darkHex: "#7A0808", visor: "#8397A7", dead: false },
        { name: "Blue",    hex: "#132ED1", darkHex: "#09158E", visor: "#8397A7", dead: false },
        { name: "Green",   hex: "#117F2D", darkHex: "#0A4D1A", visor: "#8397A7", dead: false },
        { name: "Pink",    hex: "#ED54BA", darkHex: "#AB2B87", visor: "#8397A7", dead: false },
        { name: "Orange",  hex: "#EF7D0D", darkHex: "#B04B00", visor: "#8397A7", dead: false },
        { name: "Yellow",  hex: "#F5F557", darkHex: "#C2B219", visor: "#8397A7", dead: false },
        { name: "Black",   hex: "#3F474E", darkHex: "#1E1F26", visor: "#8397A7", dead: false },
        { name: "White",   hex: "#D6E0F0", darkHex: "#8394BF", visor: "#8397A7", dead: false },
        { name: "Purple",  hex: "#6B2FBB", darkHex: "#3B177C", visor: "#8397A7", dead: false },
        { name: "Brown",   hex: "#71491E", darkHex: "#46290C", visor: "#8397A7", dead: false },
        { name: "Cyan",    hex: "#38FEDC", darkHex: "#24A894", visor: "#8397A7", dead: false },
        { name: "Lime",    hex: "#50EF39", darkHex: "#249514", visor: "#8397A7", dead: false },
        { name: "Maroon",  hex: "#5F1F2E", darkHex: "#370914", visor: "#8397A7", dead: false },
        { name: "Rose",    hex: "#ECC0D3", darkHex: "#A9768B", visor: "#8397A7", dead: false },
        { name: "Banana",  hex: "#FFFEA7", darkHex: "#C5C073", visor: "#8397A7", dead: false },
        { name: "Gray",    hex: "#758593", darkHex: "#465058", visor: "#8397A7", dead: false },
        { name: "Tan",     hex: "#918877", darkHex: "#5E5648", visor: "#8397A7", dead: false },
        { name: "Coral",   hex: "#D76464", darkHex: "#963434", visor: "#8397A7", dead: false }
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

    // Hotkey: press 'R' to reset all colors to lit
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_R) {
            amogusRoot.resetAll();
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // Top Status & Reset Toolbar
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "ඞ AMONG US CREWMATE TRACKER"
                font.family: theme ? theme.fontFamily : "monospace"
                font.pixelSize: 18
                font.bold: true
                color: theme ? theme.base05 : "yellow"
            }

            Rectangle {
                height: 26
                width: statsText.implicitWidth + 16
                radius: 13
                color: "#181825"
                border.color: theme ? theme.base03 : "#45475a"
                border.width: 1

                Text {
                    id: statsText
                    anchors.centerIn: parent
                    text: "Alive: " + amogusRoot.aliveCount + " | Out: " + amogusRoot.deadCount
                    font.family: "monospace"
                    font.pixelSize: 12
                    font.bold: true
                    color: amogusRoot.deadCount > 0 ? (theme ? theme.base09 : "#fe8019") : (theme ? theme.base0C : "#04f100")
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: resetBtnText.implicitWidth + 24
                height: 32
                radius: 6
                color: resetHover.hovered ? (theme ? theme.base05 : "yellow") : "transparent"
                border.color: theme ? theme.base05 : "yellow"
                border.width: 1.5

                Text {
                    id: resetBtnText
                    anchors.centerIn: parent
                    text: "↺ Reset All (R)"
                    font.family: theme ? theme.fontFamily : "monospace"
                    font.pixelSize: 12
                    font.bold: true
                    color: resetHover.hovered ? "#11111b" : (theme ? theme.base05 : "yellow")
                }

                HoverHandler { id: resetHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: amogusRoot.resetAll()
                }
            }
        }

        // 6 x 3 Responsive Astronaut Grid
        Grid {
            id: crewGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 6
            columnSpacing: 10
            rowSpacing: 10

            readonly property real cardW: (width - (5 * 10)) / 6
            readonly property real cardH: (height - (2 * 10)) / 3

            Repeater {
                model: amogusRoot.crewModel

                delegate: Rectangle {
                    id: crewCard
                    readonly property var crewItem: modelData
                    readonly property bool isDead: crewItem.dead

                    width: crewGrid.cardW
                    height: crewGrid.cardH
                    radius: 10

                    // Dim out completely when eliminated
                    color: isDead ? "#121218" : "#1e1e2e"
                    border.width: isDead ? 1 : 2
                    border.color: isDead ? "#333344" : crewItem.hex
                    opacity: isDead ? 0.30 : 1.0

                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        // Stylized Among Us Astronaut Visor Badge
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.parent.width * 0.45, 46)
                            height: width * 1.15
                            radius: width * 0.4
                            color: isDead ? "#3c3836" : crewItem.hex
                            border.color: isDead ? "#222222" : crewItem.darkHex
                            border.width: 2

                            // Visor glass
                            Rectangle {
                                x: parent.width * 0.28
                                y: parent.height * 0.25
                                width: parent.width * 0.65
                                height: parent.height * 0.35
                                radius: height / 2
                                color: isDead ? "#555555" : "#99d9ea"
                                border.color: "#ffffff"
                                border.width: 1

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

                            // Backpack
                            Rectangle {
                                x: -parent.width * 0.22
                                y: parent.height * 0.35
                                width: parent.width * 0.25
                                height: parent.height * 0.5
                                radius: 3
                                color: isDead ? "#222222" : crewItem.darkHex
                                z: -1
                            }

                            // Dead / Eliminated Cross Mark
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
                            font.family: theme ? theme.fontFamily : "monospace"
                            font.pixelSize: 11
                            font.bold: true
                            font.strikeout: crewCard.isDead
                            color: crewCard.isDead ? "#666677" : (theme ? theme.base05 : "yellow")
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: amogusRoot.toggleColor(index)
                    }
                }
            }
        }
    }
}
