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

        expandedCoreWidth: 1440
        tooltipHeight: 650

        Item {
            id: popupContent
            anchors.fill: parent

            // Reliable date source that triggers QML reactivity
            property var now: new Date()

            Timer {
                interval: 1000
                running: timezoneClockWindow.visible
                repeat: true
                triggeredOnStart: true
                onTriggered: popupContent.now = new Date()
            }

            property var timeFormatterCache: ({})
            property var codeFormatterCache: ({})

            // --- Robust DST Math Engines (Fallback if Intl is absent or unsupported in QML) ---
            function isUsDst(d) {
                var year = d.getUTCFullYear();
                var mar = new Date(Date.UTC(year, 2, 8));
                var startSun = 8 + ((7 - mar.getUTCDay()) % 7);
                var dstStart = new Date(Date.UTC(year, 2, startSun, 7, 0, 0)); // 2 AM EST = 7 AM UTC

                var nov = new Date(Date.UTC(year, 10, 1));
                var endSun = 1 + ((7 - nov.getUTCDay()) % 7);
                var dstEnd = new Date(Date.UTC(year, 10, endSun, 6, 0, 0)); // 2 AM EDT = 6 AM UTC

                var t = d.getTime();
                return t >= dstStart.getTime() && t < dstEnd.getTime();
            }

            function isEuDst(d) {
                var year = d.getUTCFullYear();
                var mar31 = new Date(Date.UTC(year, 2, 31));
                var startSun = 31 - mar31.getUTCDay();
                var dstStart = new Date(Date.UTC(year, 2, startSun, 1, 0, 0)); // 1:00 UTC

                var oct31 = new Date(Date.UTC(year, 9, 31));
                var endSun = 31 - oct31.getUTCDay();
                var dstEnd = new Date(Date.UTC(year, 9, endSun, 1, 0, 0)); // 1:00 UTC

                var t = d.getTime();
                return t >= dstStart.getTime() && t < dstEnd.getTime();
            }

            function isAuDst(d) {
                var year = d.getUTCFullYear();
                var apr = new Date(Date.UTC(year, 3, 1));
                var aprSun = 1 + ((7 - apr.getUTCDay()) % 7);
                var dstEnd = new Date(Date.UTC(year, 3, aprSun, 16, 0, 0));

                var oct = new Date(Date.UTC(year, 9, 1));
                var octSun = 1 + ((7 - oct.getUTCDay()) % 7);
                var dstStart = new Date(Date.UTC(year, 9, octSun, 16, 0, 0));

                var t = d.getTime();
                return t >= dstStart.getTime() || t < dstEnd.getTime();
            }

            function isNzDst(d) {
                var year = d.getUTCFullYear();
                var apr = new Date(Date.UTC(year, 3, 1));
                var aprSun = 1 + ((7 - apr.getUTCDay()) % 7);
                var dstEnd = new Date(Date.UTC(year, 3, aprSun, 14, 0, 0));

                var sep30 = new Date(Date.UTC(year, 8, 30));
                var sepSun = 30 - sep30.getUTCDay();
                var dstStart = new Date(Date.UTC(year, 8, sepSun, 14, 0, 0));

                var t = d.getTime();
                return t >= dstStart.getTime() || t < dstEnd.getTime();
            }

            function getDstActive(zoneObj, d) {
                if (zoneObj.rule === "us") return isUsDst(d);
                if (zoneObj.rule === "eu") return isEuDst(d);
                if (zoneObj.rule === "au") return isAuDst(d);
                if (zoneObj.rule === "nz") return isNzDst(d);
                return false;
            }

            // --- Formatter & Fallback Resolver ---
            function getZoneTime(zoneObj) {
                var d = popupContent.now || new Date();

                // 1. Try native Intl.DateTimeFormat
                if (typeof Intl !== "undefined" && Intl.DateTimeFormat) {
                    try {
                        if (!timeFormatterCache[zoneObj.tz]) {
                            timeFormatterCache[zoneObj.tz] = new Intl.DateTimeFormat("en-US", {
                                timeZone: zoneObj.tz,
                                hour: "2-digit",
                                minute: "2-digit",
                                hour12: true
                            });
                        }
                        var res = timeFormatterCache[zoneObj.tz].format(d).replace(/\u202f|\u00a0/g, " ");
                        if (res && res.length >= 7) return res;
                    } catch (e) {}
                }

                // 2. Guaranteed Mathematical DST Fallback
                var isDst = getDstActive(zoneObj, d);
                var effectiveOffset = zoneObj.offset + (isDst ? 1 : 0);
                var targetMs = d.getTime() + (effectiveOffset * 3600000);
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

            function getZoneCode(zoneObj) {
                var d = popupContent.now || new Date();

                // Try Intl timeZoneName first
                if (typeof Intl !== "undefined" && Intl.DateTimeFormat) {
                    try {
                        if (!codeFormatterCache[zoneObj.tz]) {
                            codeFormatterCache[zoneObj.tz] = new Intl.DateTimeFormat("en-US", {
                                timeZone: zoneObj.tz,
                                timeZoneName: "short"
                            });
                        }
                        var parts = codeFormatterCache[zoneObj.tz].formatToParts(d);
                        for (var i = 0; i < parts.length; i++) {
                            if (parts[i].type === "timeZoneName") return parts[i].value;
                        }
                    } catch (e) {}
                }

                // Fallback to DST code mapping
                var isDst = getDstActive(zoneObj, d);
                return isDst ? zoneObj.dstCode : zoneObj.code;
            }

            function isLocalMatch(targetTimeStr) {
                if (!targetTimeStr) return false;
                var d = popupContent.now || new Date();
                var localH = d.getHours();
                var localM = d.getMinutes();
                var ampm = localH >= 12 ? "PM" : "AM";
                var disH = localH % 12;
                if (disH === 0) disH = 12;
                var hStr = disH < 10 ? ("0" + disH) : ("" + disH);
                var mStr = localM < 10 ? ("0" + localM) : ("" + localM);
                return targetTimeStr.trim() === (hStr + ":" + mStr + " " + ampm);
            }

            Column {
                anchors.fill: parent
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
                                    { name: "Hawaii",   code: "HST",  dstCode: "HST",  tz: "Pacific/Honolulu",   offset: -10, rule: "none" },
                                    { name: "Alaska",   code: "AKST", dstCode: "AKDT", tz: "America/Anchorage",  offset: -9,  rule: "us" },
                                    { name: "Pacific",  code: "PST",  dstCode: "PDT",  tz: "America/Los_Angeles",offset: -8,  rule: "us" },
                                    { name: "Mountain", code: "MST",  dstCode: "MDT",  tz: "America/Denver",     offset: -7,  rule: "us" },
                                    { name: "Central",  code: "CST",  dstCode: "CDT",  tz: "America/Chicago",    offset: -6,  rule: "us" },
                                    { name: "Eastern",  code: "EST",  dstCode: "EDT",  tz: "America/New_York",   offset: -5,  rule: "us" }
                                ]
                            },
                            {
                                title: "ATLANTIC",
                                zones: [
                                    { name: "Atlantic",     code: "AST",  dstCode: "ADT",  tz: "America/Halifax",    offset: -4,   rule: "us" },
                                    { name: "Newfoundland", code: "NST",  dstCode: "NDT",  tz: "America/St_Johns",   offset: -3.5, rule: "us" },
                                    { name: "Greenland",    code: "WGT",  dstCode: "WGT",  tz: "America/Nuuk",       offset: -2,   rule: "none" },
                                    { name: "Mid-Atlantic", code: "CVT",  dstCode: "CVT",  tz: "Atlantic/Cape_Verde",offset: -1,   rule: "none" },
                                    { name: "Azores",       code: "AZOT", dstCode: "AZOST",tz: "Atlantic/Azores",    offset: -1,   rule: "eu" },
                                    { name: "UTC / GMT",    code: "UTC",  dstCode: "UTC",  tz: "UTC",                offset: 0,    rule: "none" }
                                ]
                            },
                            {
                                title: "EMEA",
                                zones: [
                                    { name: "London",         code: "GMT", dstCode: "BST",  tz: "Europe/London",  offset: 0, rule: "eu" },
                                    { name: "Paris / Berlin", code: "CET", dstCode: "CEST", tz: "Europe/Paris",   offset: 1, rule: "eu" },
                                    { name: "Athens / Cairo", code: "EET", dstCode: "EEST", tz: "Europe/Athens",  offset: 2, rule: "eu" },
                                    { name: "Moscow",         code: "MSK", dstCode: "MSK",  tz: "Europe/Moscow",  offset: 3, rule: "none" },
                                    { name: "Dubai",          code: "GST", dstCode: "GST",  tz: "Asia/Dubai",     offset: 4, rule: "none" },
                                    { name: "Karachi",        code: "PKT", dstCode: "PKT",  tz: "Asia/Karachi",   offset: 5, rule: "none" }
                                ]
                            },
                            {
                                title: "ASIA PACIFIC",
                                zones: [
                                    { name: "Dhaka",          code: "BST",  dstCode: "BST",  tz: "Asia/Dhaka",       offset: 6,  rule: "none" },
                                    { name: "Bangkok",        code: "ICT",  dstCode: "ICT",  tz: "Asia/Bangkok",     offset: 7,  rule: "none" },
                                    { name: "Singapore / HK", code: "SGT",  dstCode: "SGT",  tz: "Asia/Singapore",   offset: 8,  rule: "none" },
                                    { name: "Tokyo / Seoul",  code: "JST",  dstCode: "JST",  tz: "Asia/Tokyo",       offset: 9,  rule: "none" },
                                    { name: "Sydney",         code: "AEST", dstCode: "AEDT", tz: "Australia/Sydney", offset: 10, rule: "au" },
                                    { name: "Auckland",       code: "NZST", dstCode: "NZDT", tz: "Pacific/Auckland", offset: 12, rule: "nz" }
                                ]
                            }
                        ]
                        delegate: Item {
                            id: columnCard
                            width: (parent.width - (3 * 18)) / 4
                            height: 520

                            readonly property bool isLocalCol: {
                                for (var z = 0; z < modelData.zones.length; z++) {
                                    var timeStr = popupContent.getZoneTime(modelData.zones[z]);
                                    if (popupContent.isLocalMatch(timeStr)) return true;
                                }
                                return false;
                            }

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

                                        readonly property string formattedTime: popupContent.getZoneTime(modelData)
                                        readonly property string dynamicCode: popupContent.getZoneCode(modelData)
                                        readonly property bool isMe: popupContent.isLocalMatch(formattedTime)

                                        Text {
                                            text: modelData.name + " (" + dynamicCode + ")"
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
