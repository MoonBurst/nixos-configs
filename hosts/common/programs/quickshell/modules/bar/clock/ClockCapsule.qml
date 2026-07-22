// ClockCapsule.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import Quickshell
import Quickshell.Wayland

import "../../style"

Item {
    id: clockBox

    anchors.fill: parent

    // =========================================================================
    // SAFE STRONGLY-TYPED THEME FALLBACKS
    // =========================================================================
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeBorderWidth: (shell && shell.theme && typeof shell.theme.globalBorderWidth !== "undefined") ? shell.theme.globalBorderWidth : 3
    readonly property real themeHalfB: themeBorderWidth / 2
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property color themeBase05: (shell && shell.theme && typeof shell.theme.base05 !== "undefined") ? shell.theme.base05 : "yellow"
    readonly property color themeBase00: (shell && shell.theme && typeof shell.theme.base00 !== "undefined") ? shell.theme.base00 : "black"
    readonly property color themeBase02: (shell && shell.theme && typeof shell.theme.base02 !== "undefined") ? shell.theme.base02 : "#222222"
    // =========================================================================

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: "Left"
        slantRight: "Right"
    }

    property var barWindow: null
    property string dateStr: "12:00:00 PM"

    Timer {
        id: clockPollerTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var date = new Date()
            clockBox.dateStr = date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
        }
    }

    Text {
        id: clockText
        anchors.fill: parent

        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: themePadding
        anchors.bottomMargin: themePadding

        color: themeBase05
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: clockBox.dateStr
    }

    HoverHandler {
        id: clockHoverTracker
    }

    // ============================================================================
    // THE TIMEZONE MATRIX POPUP WINDOW (Directly Instantiated)
    // ============================================================================
    SlantedTooltip {
        id: timezoneClockWindow

        moduleItem: clockBox
        barWindow: clockBox.barWindow
        tooltipActive: clockHoverTracker.hovered

        // Unified style configuration
        backgroundStyle: "Hexagon"
        alignSide: "Center"

        tooltipHeight: 520
        collapsedCoreWidth: 130
        expandedCoreWidth: 1390
        topOffset: 8

        Item {
            id: popupContent
            anchors.fill: parent

            SystemClock { id: popupTime; precision: SystemClock.Seconds }

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

            Item {
                id: mainCard
                anchors.fill: parent

                readonly property real borderW: themeBorderWidth
                readonly property real halfB: themeHalfB
                readonly property color colorBase05: themeBase05
                readonly property color colorBase02: themeBase02
                readonly property string fontFamily: themeFontFamily
                readonly property real sw: 45

                Column {
                    anchors.fill: parent
                    anchors.leftMargin: themePadding + mainCard.sw
                    anchors.rightMargin: themePadding + mainCard.sw
                    anchors.topMargin: themePadding
                    anchors.bottomMargin: themePadding
                    spacing: 24

                    Item {
                        id: headerBlock
                        width: parent.width
                        height: 54

                        readonly property real sw: 12

                        state: timezoneClockWindow.innerLayoutTrigger ? "visible" : "hidden"

                        states: [
                            State {
                                name: "hidden"
                                PropertyChanges { target: headerBlock; opacity: 0; scale: 0.9 }
                            },
                            State {
                                name: "visible"
                                PropertyChanges { target: headerBlock; opacity: 1; scale: 1.0 }
                            }
                        ]

                        transitions: [
                            Transition {
                                from: "hidden"; to: "visible"
                                ParallelAnimation {
                                    NumberAnimation { target: headerBlock; properties: "opacity,scale"; duration: 250; easing.type: Easing.OutCubic }
                                }
                            },
                            Transition {
                                from: "visible"; to: "hidden"
                                NumberAnimation { target: headerBlock; property: "opacity"; duration: 100 }
                            }
                        ]

                        Shape {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.samples: 4

                            ShapePath {
                                strokeColor: mainCard.colorBase05
                                strokeWidth: mainCard.borderW
                                fillColor: "transparent"
                                joinStyle: ShapePath.MiterJoin

                                startX: headerBlock.sw + themeHalfB
                                startY: themeHalfB
                                PathLine { x: headerBlock.width - headerBlock.sw - themeHalfB; y: themeHalfB }
                                PathLine { x: headerBlock.width - themeHalfB; y: headerBlock.height / 2 }
                                PathLine { x: headerBlock.width - headerBlock.sw - themeHalfB; y: headerBlock.height - themeHalfB }
                                PathLine { x: headerBlock.sw + themeHalfB; y: headerBlock.height - themeHalfB }
                                PathLine { x: themeHalfB; y: headerBlock.height / 2 }
                                PathLine { x: headerBlock.sw + themeHalfB; y: themeHalfB }
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

                            delegate: Item {
                                id: categoryCard

                                width: timezoneGridMatrix.width > 0 ? (timezoneGridMatrix.width - (3 * timezoneGridMatrix.spacing)) / 4 : 0
                                height: innerColumnLayout ? innerColumnLayout.height + 40 : 0

                                readonly property real targetWidth: width
                                readonly property real targetHeight: height
                                readonly property real sw: 14

                                Item {
                                    id: cardContainer
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top

                                    width: animWidth
                                    height: animHeight

                                    property real animWidth: 40
                                    property real animHeight: 0
                                    property real contentOpacity: 0

                                    state: timezoneClockWindow.innerLayoutTrigger ? "visible" : "hidden"

                                    states: [
                                        State {
                                            name: "hidden"
                                            PropertyChanges { target: cardContainer; animHeight: 0; animWidth: 40; contentOpacity: 0 }
                                        },
                                        State {
                                            name: "visible"
                                            PropertyChanges { target: cardContainer; animHeight: categoryCard.targetHeight; animWidth: categoryCard.targetWidth; contentOpacity: 1 }
                                        }
                                    ]

                                    transitions: [
                                        Transition {
                                            from: "hidden"; to: "visible"
                                            SequentialAnimation {
                                                NumberAnimation {
                                                    target: cardContainer
                                                    property: "animHeight"
                                                    duration: 250
                                                    easing.type: Easing.OutCubic
                                                }
                                                NumberAnimation {
                                                    target: cardContainer
                                                    property: "animWidth"
                                                    duration: 200
                                                    easing.type: Easing.OutCubic
                                                }
                                                NumberAnimation {
                                                    target: cardContainer
                                                    property: "contentOpacity"
                                                    duration: 150
                                                    easing.type: Easing.OutQuad
                                                }
                                            }
                                        },
                                        Transition {
                                            from: "visible"; to: "hidden"
                                            SequentialAnimation {
                                                NumberAnimation {
                                                    target: cardContainer
                                                    property: "contentOpacity"
                                                    duration: 100
                                                    easing.type: Easing.InQuad
                                                }
                                                NumberAnimation {
                                                    target: cardContainer
                                                    property: "animWidth"
                                                    duration: 120
                                                    easing.type: Easing.InCubic
                                                }
                                                NumberAnimation {
                                                    target: cardContainer
                                                    property: "animHeight"
                                                    duration: 150
                                                    easing.type: Easing.InCubic
                                                }
                                            }
                                        }
                                    ]

                                    Canvas {
                                        id: cardOutline
                                        anchors.fill: parent

                                        readonly property real borderW: mainCard.borderW
                                        readonly property real halfB: themeHalfB
                                        readonly property color colorBase05: mainCard.colorBase05
                                        readonly property real sw: categoryCard.sw

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();

                                            ctx.lineWidth = borderW;
                                            ctx.strokeStyle = colorBase05;
                                            ctx.fillStyle = "transparent";

                                            var topChamferY = Math.min(height / 2, sw + halfB);
                                            var bottomChamferY = Math.max(height / 2, height - sw - halfB);
                                            var bottomY = Math.max(halfB, height - halfB);

                                            ctx.beginPath();
                                            ctx.moveTo(sw + halfB, halfB);
                                            ctx.lineTo(width - sw - halfB, halfB);
                                            ctx.lineTo(width - halfB, topChamferY);
                                            ctx.lineTo(width - halfB, bottomChamferY);
                                            ctx.lineTo(width - sw - halfB, bottomY);
                                            ctx.lineTo(sw + halfB, bottomY);
                                            ctx.lineTo(halfB, bottomChamferY);
                                            ctx.lineTo(halfB, topChamferY);
                                            ctx.closePath();

                                            ctx.fill();
                                            ctx.stroke();
                                        }

                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                    }

                                    Column {
                                        id: innerColumnLayout
                                        anchors.centerIn: parent
                                        width: categoryCard.targetWidth - ((themePadding + categoryCard.sw) * 2)
                                        spacing: 14
                                        opacity: cardContainer.contentOpacity
                                        visible: opacity > 0

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

                                                readonly property bool isLocalZone: modelData.offset === popupContent.systemOffset

                                                // Declared first to completely silence forward-reference warnings
                                                Text {
                                                    id: timeDisplay
                                                    text: popupContent.getTimezoneTime(modelData.offset)
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    font.pixelSize: 25
                                                    font.bold: parent.isLocalZone
                                                    font.family: mainCard.fontFamily
                                                    color: mainCard.colorBase05
                                                }

                                                Text {
                                                    text: modelData.name + " (" + modelData.code + ")"
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.right: timeDisplay.left
                                                    anchors.rightMargin: themePadding
                                                    elide: Text.ElideRight

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
        }
    }
}
