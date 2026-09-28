import QtQuick
import Quickshell
import "../../style"

Item {
    id: clockBox
    property var barWindow: null
    property string moduleName: "clock"
    property string slantLeft: "Left"
    property string slantRight: "Right"
    property int slantWidth: (shell && shell.theme && shell.theme.slantWidth) ? shell.theme.slantWidth : 12

    readonly property color themeBase05: (shell && shell.theme) ? shell.theme.base05 : "yellow"
    readonly property color themeBase00: (shell && shell.theme) ? shell.theme.base00 : "black"
    readonly property color themeBase02: (shell && shell.theme) ? shell.theme.base02 : "#222222"
    readonly property int themeFontSize: (shell && shell.theme) ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"

    property string dateStr: "12:00 PM"

    implicitWidth: Math.max(180, clockText.implicitWidth + bg.leftPadding + bg.rightPadding + 36)
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: clockBox.slantLeft
        slantRight: clockBox.slantRight
        slantWidth: clockBox.slantWidth
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var date = new Date();
            clockBox.dateStr = date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
        }
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        color: themeBase05
        font.family: themeFontFamily
        font.pixelSize: themeFontSize + 1
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: clockBox.dateStr
        clip: false
    }

    HoverHandler { id: clockHoverTracker }

    SlantedTooltip {
        id: timezoneClockWindow
        moduleItem: clockBox
        barWindow: clockBox.barWindow
        tooltipActive: clockHoverTracker.hovered
        backgroundStyle: "Hexagon"
        alignSide: "Center"
        topOffset: 8

        // Extra wide 1440px viewport for generous outer and inner gaps
        expandedCoreWidth: 1440
        tooltipHeight: 650

        Item {
            id: popupContent
            anchors.fill: parent

            SystemClock {
                id: popupTime
                precision: timezoneClockWindow.visible ? SystemClock.Seconds : SystemClock.Minutes
            }

            // Formats target timezone from UTC timestamp
            function getTimezoneTime(offsetHours) {
                if (!popupTime || !popupTime.date) return "--:-- --";
                var d = popupTime.date;
                var targetMs = d.getTime() + (offsetHours * 3600000);
                var targetDate = new Date(targetMs);

                var h = targetDate.getUTCHours();
                var m = targetDate.getUTCMinutes();
                var ampm = h >= 12 ? "PM" : "AM";
                var displayH = h % 12;
                if (displayH === 0) displayH = 12;
                var hStr = displayH < 10 ? ("0" + displayH) : ("" + displayH);
                var mStr = m < 10 ? ("0" + m) : ("" + m);
                return hStr + ":" + mStr + " " + ampm;
            }

            // Dynamically checks if this zone matches your actual system time on the bar
            function isLocalMatch(targetTimeStr) {
                if (!popupTime || !popupTime.date) return false;
                var localH = popupTime.date.getHours();
                var localM = popupTime.date.getMinutes();
                var ampm = localH >= 12 ? "PM" : "AM";
                var disH = localH % 12;
                if (disH === 0) disH = 12;
                var hStr = disH < 10 ? ("0" + disH) : ("" + disH);
                var mStr = localM < 10 ? ("0" + localM) : ("" + localM);
                return targetTimeStr === (hStr + ":" + mStr + " " + ampm);
            }

            Column {
                anchors.fill: parent
                // 36px side margins create an intentional gap from the outer hexagon frame
                anchors.leftMargin: 36
                anchors.rightMargin: 36
                anchors.topMargin: 22
                anchors.bottomMargin: 24
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🌐 GLOBAL TIMEZONE METRIC MATRIX"
                    font.family: clockBox.themeFontFamily
                    font.pixelSize: 22
                    font.bold: true
                    color: clockBox.themeBase05
                }

                Row {
                    width: parent.width
                    spacing: 18

                    Repeater {
                        model: [
                            {
                                title: "AMERICAS",
                                zones: [
                                    { name: "Hawaii", code: "HST", offset: -10 },
                                    { name: "Alaska", code: "AKST", offset: -9 },
                                    { name: "Pacific", code: "PST", offset: -8 },
                                    { name: "Mountain", code: "MST", offset: -7 },
                                    { name: "Central", code: "CST", offset: -6 },
                                    { name: "Eastern", code: "EST", offset: -5 }
                                ]
                            },
                            {
                                title: "ATLANTIC",
                                zones: [
                                    { name: "Atlantic", code: "AST", offset: -4 },
                                    { name: "Newfoundland", code: "NST", offset: -3.5 },
                                    { name: "Greenland", code: "WGT", offset: -2 },
                                    { name: "Mid-Atlantic", code: "CVT", offset: -1 },
                                    { name: "Azores", code: "AZOT", offset: -1 },
                                    { name: "UTC / GMT", code: "UTC", offset: 0 }
                                ]
                            },
                            {
                                title: "EMEA",
                                zones: [
                                    { name: "London", code: "GMT", offset: 0 },
                                    { name: "Paris / Berlin", code: "CET", offset: 1 },
                                    { name: "Athens / Cairo", code: "EET", offset: 2 },
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
                                    { name: "Singapore / HK", code: "SGT", offset: 8 },
                                    { name: "Tokyo / Seoul", code: "JST", offset: 9 },
                                    { name: "Sydney", code: "AEST", offset: 10 },
                                    { name: "Auckland", code: "NZST", offset: 12 }
                                ]
                            }
                        ]
                        delegate: Item {
                            id: columnCard
                            width: (parent.width - (3 * 18)) / 4
                            height: 520

                            // Dynamically checks if your current system time belongs to this region
                            readonly property bool isLocalCol: {
                                for (var z = 0; z < modelData.zones.length; z++) {
                                    var timeStr = popupContent.getTimezoneTime(modelData.zones[z].offset);
                                    if (popupContent.isLocalMatch(timeStr)) return true;
                                }
                                return false;
                            }

                            // 45-Degree Hexagonal Chamfer Background
                            Canvas {
                                id: cardHexBg
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.lineWidth = 1.5;
                                    ctx.strokeStyle = columnCard.isLocalCol ? "#04f100" : clockBox.themeBase05;
                                    ctx.fillStyle = clockBox.themeBase00;
                                    var w = width, h = height, c = 16;
                                    ctx.beginPath();
                                    ctx.moveTo(c, 1);
                                    ctx.lineTo(w - c, 1);
                                    ctx.lineTo(w - 1, c);
                                    ctx.lineTo(w - 1, h - c);
                                    ctx.lineTo(w - c, h - 1);
                                    ctx.lineTo(c, h - 1);
                                    ctx.lineTo(1, h - c);
                                    ctx.lineTo(1, c);
                                    ctx.closePath();
                                    ctx.fill();
                                    ctx.stroke();
                                }
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                Text {
                                    width: parent.width
                                    text: modelData.title
                                    font.bold: true
                                    font.pixelSize: 18
                                    font.family: clockBox.themeFontFamily
                                    color: columnCard.isLocalCol ? "#04f100" : clockBox.themeBase05
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Rectangle { 
                                    width: parent.width - 16
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: 1 
                                    color: clockBox.themeBase02 
                                }

                                Repeater {
                                    model: modelData.zones
                                    delegate: Item {
                                        width: parent.width
                                        height: 58

                                        readonly property string formattedTime: popupContent.getTimezoneTime(modelData.offset)
                                        readonly property bool isMe: popupContent.isLocalMatch(formattedTime)

                                        Text {
                                            text: modelData.name + " (" + modelData.code + ")"
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            font.pixelSize: 15
                                            font.bold: isMe
                                            font.family: clockBox.themeFontFamily
                                            color: isMe ? "#04f100" : clockBox.themeBase05
                                            elide: Text.ElideRight
                                            width: parent.width - 110
                                        }

                                        Text {
                                            text: formattedTime
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            font.pixelSize: 17
                                            font.bold: true
                                            font.family: clockBox.themeFontFamily
                                            color: isMe ? "#04f100" : clockBox.themeBase05
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
