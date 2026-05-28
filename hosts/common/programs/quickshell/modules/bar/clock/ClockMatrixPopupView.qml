import QtQuick
import QtQuick.Controls 2
import Quickshell

Rectangle {
    id: root

    implicitWidth: 1480
    implicitHeight: 520
    color: "transparent"

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

    // Outer Main Widget Card Profile Container
    Rectangle {
        id: mainCard
        anchors.fill: parent
        radius: shell.theme.defaultCardRadius ?? 8
        border.width: shell.theme.globalBorderWidth ?? 3
        color: shell.theme.base00 ?? "black"
        border.color: shell.theme.base05 ?? "yellow"

        readonly property color themeColor: mainCard.border.color

        Column {
            anchors.fill: parent
            anchors.margins: shell.theme.globalPadding
            spacing: 24

            // Centered Header Title enclosed inside its own standalone system bubble
            Rectangle {
                width: parent.width
                height: 54
                radius: shell.theme.defaultCardRadius ?? 8
                border.width: shell.theme.globalBorderWidth ?? 3
                color: "transparent"
                border.color: mainCard.themeColor

                Text {
                    anchors.centerIn: parent
                    text: "🌐 GLOBAL TIMEZONE METRIC MATRIX"
                    font.family: shell.theme.fontFamily ?? "monospace"
                    font.pixelSize: 22
                    font.bold: true
                    color: mainCard.themeColor
                }
            }

            Row {
                id: timezoneGridMatrix
                width: parent.width
                spacing: 16

                Repeater {
                    model: [
                        {
                            title: "📂 AMERICAS",
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
                            title: "📂 ATLANTIC & WEST",
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
                            title: "📂 EMEA & CENTRAL",
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
                            title: "📂 ASIA PACIFIC",
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

                    delegate: Rectangle {
                        width: (timezoneGridMatrix.width - (3 * timezoneGridMatrix.spacing)) / 4
                        height: innerColumnLayout.height + 24

                        radius: shell.theme.defaultCardRadius ?? 8
                        border.width: shell.theme.globalBorderWidth ?? 3
                        color: "transparent"
                        border.color: mainCard.themeColor

                        Column {
                            id: innerColumnLayout
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: shell.theme.globalPadding
                            spacing: 14

                            Text {
                                width: parent.width
                                text: modelData.title
                                font.bold: true
                                font.pixelSize: 18
                                font.family: shell.theme.fontFamily ?? "monospace"
                                color: mainCard.themeColor
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            Repeater {
                                model: modelData.zones

                                delegate: Item {
                                    width: parent.width
                                    height: 34

                                    // Dynamic flag checking if this exact row offset matches your system's offset
                                    readonly property bool isLocalZone: modelData.offset === root.systemOffset

                                    Text {
                                        text: modelData.name + " (" + modelData.code + ")"
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: timeDisplay.left
                                        anchors.rightMargin: shell.theme.globalPadding
                                        elide: Text.ElideRight

                                        font.pixelSize: 25
                                        font.bold: parent.isLocalZone // DYNAMIC BOLDING
                                        font.family: shell.theme.fontFamily ?? "monospace"
                                        color: mainCard.themeColor
                                    }

                                    Text {
                                        id: timeDisplay
                                        text: root.getTimezoneTime(modelData.offset)
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter

                                        font.pixelSize: 25
                                        font.bold: parent.isLocalZone // DYNAMIC BOLDING
                                        font.family: shell.theme.fontFamily ?? "monospace"
                                        color: mainCard.themeColor
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
