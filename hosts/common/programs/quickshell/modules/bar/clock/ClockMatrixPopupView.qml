import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import Quickshell

Item {
    id: root

    implicitWidth: 1480
    implicitHeight: 520

    SystemClock { id: popupTime; precision: SystemClock.Seconds }

    // Helper property to dynamically read your system's current hourly offset
    readonly property int systemOffset: popupTime.date ? -Math.round(popupTime.date.getTimezoneOffset() / 60) : -5

    function getTimezoneTime(offsetHours) {
        if (!popupTime || !popupTime.date) return "--:-- --";

        let localDate = new Date(popupTime.date.getTime());
        let utc = localDate.getTime() + (localDate.getTimezoneOffset() * 60000);
        let nd = new Date(utc + (3600000 * offsetHours));

        let hours = nd.getHours();
        let minutes = nd.getMinutes();
        let ampm = hours >= 12 ? "PM" : "AM";

        hours = hours % 12;
        hours = hours ? hours : 12;

        let hh = hours < 10 ? "0" + hours : hours;
        let mm = minutes < 10 ? "0" + minutes : minutes;

        return hh + ":" + mm + " " + ampm;
    }

    // Outer Main Widget Card Profile Container (Drawn as a Widescreen Hexagon)
    Item {
        id: mainCard
        anchors.fill: parent

        readonly property real borderW: (shell && shell.theme) ? (shell.theme.globalBorderWidth || 3) : 3
        readonly property real halfB: borderW / 2
        readonly property color colorBase05: (shell && shell.theme) ? (shell.theme.base05 || "yellow") : "yellow"
        readonly property color colorBase00: (shell && shell.theme) ? (shell.theme.base00 || "black") : "black"
        readonly property color colorBase02: (shell && shell.theme) ? (shell.theme.base02 || "#222222") : "#222222"
        readonly property string fontFamily: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"

        // Hexagon pointed offset
        readonly property real sw: 45

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                strokeColor: mainCard.colorBase05
                strokeWidth: mainCard.borderW
                fillColor: mainCard.colorBase00
                joinStyle: ShapePath.MiterJoin

                // 6-Point Horizontal Hexagon Path Loop
                startX: mainCard.sw + mainCard.halfB
                startY: mainCard.halfB
                PathLine { x: mainCard.width - mainCard.sw - mainCard.halfB; y: mainCard.halfB }
                PathLine { x: mainCard.width - mainCard.halfB; y: mainCard.height / 2 }
                PathLine { x: mainCard.width - mainCard.sw - mainCard.halfB; y: mainCard.height - mainCard.halfB }
                PathLine { x: mainCard.sw + mainCard.halfB; y: mainCard.height - mainCard.halfB }
                PathLine { x: mainCard.halfB; y: mainCard.height / 2 }
                PathLine { x: mainCard.sw + mainCard.halfB; y: mainCard.halfB }
            }
        }

        Column {
            anchors.fill: parent
            // Extra left/right margins to prevent inner contents from clipping on pointed sides
            anchors.leftMargin: shell.theme.globalPadding + mainCard.sw
            anchors.rightMargin: shell.theme.globalPadding + mainCard.sw
            anchors.topMargin: shell.theme.globalPadding
            anchors.bottomMargin: shell.theme.globalPadding
            spacing: 24

            // Centered Header Title enclosed inside its own slanted Hexagon Bubble
            Item {
                id: headerBlock
                width: parent.width
                height: 54

                readonly property real sw: 12

                Shape {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.samples: 4

                    ShapePath {
                        strokeColor: mainCard.colorBase05
                        strokeWidth: mainCard.borderW
                        fillColor: "transparent"
                        joinStyle: ShapePath.MiterJoin

                        startX: headerBlock.sw + mainCard.halfB
                        startY: mainCard.halfB
                        PathLine { x: headerBlock.width - headerBlock.sw - mainCard.halfB; y: mainCard.halfB }
                        PathLine { x: headerBlock.width - mainCard.halfB; y: headerBlock.height / 2 }
                        PathLine { x: headerBlock.width - headerBlock.sw - mainCard.halfB; y: headerBlock.height - mainCard.halfB }
                        PathLine { x: headerBlock.sw + mainCard.halfB; y: headerBlock.height - mainCard.halfB }
                        PathLine { x: mainCard.halfB; y: headerBlock.height / 2 }
                        PathLine { x: headerBlock.sw + mainCard.halfB; y: mainCard.halfB }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "🌐 GLOBAL TIMEZONE METRIC MATRIX"
                    font.family: mainCard.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                    color: mainCard.colorBase05
                }
            }

            Row {
                id: timezoneGridMatrix
                width: parent.width
                spacing: 16

                Repeater {
                    model: [
                        {
                            title: "AMERICAS",
                            zones: [
                                { name: "Midway", code: "SST", offset: -11 },
                                { name: "Hawaii", code: "HST", offset: -10 },
                                { name: "Alaska", code: "AKDT", offset: -8 },
                                { name: "Pacific", code: "PDT", offset: -7 },
                                { name: "Mountain", code: "MDT", offset: -6 },
                                { name: "Central", code: "CDT", offset: -5 }
                            ]
                        },
                        {
                            title: "ATLANTIC & WEST",
                            zones: [
                                { name: "Eastern", code: "EDT", offset: -4 },
                                { name: "Atlantic", code: "AST", offset: -3 },
                                { name: "Greenland", code: "WGST", offset: -2 },
                                { name: "Mid-Atlantic", code: "EGT", offset: -1 },
                                { name: "Azores", code: "AZOST", offset: 0 },
                                { name: "UTC / GMT", code: "UTC", offset: 0 }
                            ]
                        },
                        {
                            title: "EMEA & CENTRAL",
                            zones: [
                                { name: "London", code: "BST", offset: 1 },
                                { name: "Central EU", code: "CEST", offset: 2 },
                                { name: "Eastern EU", code: "EEST", offset: 3 },
                                { name: "Moscow", code: "MSK", offset: 3 },
                                { name: "Dubai", code: "GST", offset: 4 },
                                { name: "Karachi", code: "PKT", offset: 5 }
                            ]
                        },
                        {
                            title: "ASIA PACIFIC",
                            zones: [
                                { name: "Dhaka", code: "BST", offset: 6 },
                                { name: "Bangkok", code: "ICT", offset: 7 },
                                { name: "Beijing / HK", code: "CST", offset: 8 },
                                { name: "Tokyo", code: "JST", offset: 9 },
                                { name: "Sydney", code: "AEST", offset: 10 },
                                { name: "Auckland", code: "NZST", offset: 12 }
                            ]
                        }
                    ]

                    // Slanted Vertical Hexagon Category Delegate Blocks
                    delegate: Item {
                        id: categoryCard
                        width: (timezoneGridMatrix.width - (3 * timezoneGridMatrix.spacing)) / 4
                        height: innerColumnLayout.height + 40 // Height padding to clear the bottom hex point

                        readonly property real sw: 14

                        Shape {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.samples: 4

                            ShapePath {
                                strokeColor: mainCard.colorBase05
                                strokeWidth: mainCard.borderW
                                fillColor: "transparent"
                                joinStyle: ShapePath.MiterJoin

                                startX: categoryCard.sw + mainCard.halfB
                                startY: mainCard.halfB
                                PathLine { x: categoryCard.width - categoryCard.sw - mainCard.halfB; y: mainCard.halfB }
                                PathLine { x: categoryCard.width - mainCard.halfB; y: categoryCard.height / 2 }
                                PathLine { x: categoryCard.width - categoryCard.sw - mainCard.halfB; y: categoryCard.height - mainCard.halfB }
                                PathLine { x: categoryCard.sw + mainCard.halfB; y: categoryCard.height - mainCard.halfB }
                                PathLine { x: mainCard.halfB; y: categoryCard.height / 2 }
                                PathLine { x: categoryCard.sw + mainCard.halfB; y: mainCard.halfB }
                            }
                        }

                        Column {
                            id: innerColumnLayout
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: shell.theme.globalPadding + categoryCard.sw
                            anchors.rightMargin: shell.theme.globalPadding + categoryCard.sw
                            anchors.topMargin: shell.theme.globalPadding
                            spacing: 14

                            Text {
                                width: parent.width
                                text: modelData.title
                                font.bold: true
                                font.pixelSize: 18
                                font.family: mainCard.fontFamily
                                color: mainCard.colorBase05
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            Repeater {
                                model: modelData.zones

                                delegate: Item {
                                    width: parent.width
                                    height: 34

                                    readonly property bool isLocalZone: modelData.offset === root.systemOffset

                                    Text {
                                        text: modelData.name + " (" + modelData.code + ")"
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: timeDisplay.left
                                        anchors.rightMargin: shell.theme.globalPadding
                                        elide: Text.ElideRight

                                        font.pixelSize: 25
                                        font.bold: parent.isLocalZone
                                        font.family: mainCard.fontFamily
                                        color: mainCard.colorBase05
                                    }

                                    Text {
                                        id: timeDisplay
                                        text: root.getTimezoneTime(modelData.offset)
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter

                                        font.pixelSize: 25
                                        font.bold: parent.isLocalZone
                                        font.family: mainCard.fontFamily
                                        color: mainCard.colorBase05
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
