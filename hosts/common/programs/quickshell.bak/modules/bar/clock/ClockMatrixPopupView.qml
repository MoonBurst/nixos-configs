import QtQuick
import QtQuick.Controls 2
import Quickshell

Rectangle {
    width: 760
    height: 420
    border.width: 3
    radius: 8

    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

    SystemClock { id: popupTime; precision: SystemClock.Seconds }

    function getOffsetTime(offsetHours) {
        if (!popupTime || !popupTime.date) return "--:--";
        let d = new Date(popupTime.date.getTime());
        let utc = d.getTime() + (d.getTimezoneOffset() * 60000);
        let nd = new Date(utc + (3600000 * offsetHours));
        let hours = nd.getHours();
        let minutes = nd.getMinutes();
        let hh = hours < 10 ? "0" + hours : hours;
        let mm = minutes < 10 ? "0" + minutes : minutes;
        return hh + ":" + mm;
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            text: "🌐 GLOBAL TIMEZONE METRIC MATRIX"
            font.family: "monospace"
            font.pixelSize: 20
            font.bold: true
            color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"
        }

        Rectangle {
            width: parent.width;
            height: 2;
            color: (typeof Theme !== 'undefined' && Theme.base03 !== undefined) ? Theme.base03 : "#333333"
        }

        Flickable {
            width: parent.width
            height: 340
            contentWidth: timezoneGridMatrix.width
            contentHeight: timezoneGridMatrix.height
            clip: true

            Grid {
                id: timezoneGridMatrix
                columns: 4
                columnSpacing: 25
                rowSpacing: 14
                width: parent.width

                // COLUMN 1: UTC-11 TO UTC-6
                Column {
                    spacing: 6
                    // FIXED: Overrode custom colors to force the header labels straight to theme yellow
                    Text { text: "📂 WEST FLANK"; font.bold: true; font.pixelSize: 20; font.family: "monospace"; color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow" }
                    Text { text: "UTC-11: " + getOffsetTime(-11); color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC-10: " + getOffsetTime(-10); color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC-9:  " + getOffsetTime(-9);  color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC-8:  " + getOffsetTime(-8);  color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC-7:  " + getOffsetTime(-7);  color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC-6:  " + getOffsetTime(-6);  color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                }

                // COLUMN 2: UTC-5 TO UTC+0
                Column {
                    spacing: 6
                    // FIXED: Header overrode straight to theme yellow
                    Text { text: "📂 ATLANTIC HUB"; font.bold: true; font.pixelSize: 20; font.family: "monospace"; color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow" }
                    Text { text: "UTC-5:  " + getOffsetTime(-5);  color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC-4:  " + getOffsetTime(-4);  color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC-3:  " + getOffsetTime(-3);  color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC-2:  " + getOffsetTime(-2);  color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC-1:  " + getOffsetTime(-1);  color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC+0:  " + getOffsetTime(0);   color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                }

                // COLUMN 3: UTC+1 TO UTC+6
                Column {
                    spacing: 6
                    // FIXED: Header overrode straight to theme yellow
                    Text { text: "📂 EURASIA"; font.bold: true; font.pixelSize: 20; font.family: "monospace"; color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow" }
                    Text { text: "UTC+1:  " + getOffsetTime(1);   color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC+2:  " + getOffsetTime(2);   color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC+3:  " + getOffsetTime(3);   color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC+4:  " + getOffsetTime(4);   color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC+5:  " + getOffsetTime(5);   color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC+6:  " + getOffsetTime(6);   color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                }

                // COLUMN 4: UTC+7 TO UTC+12
                Column {
                    spacing: 6
                    // FIXED: Header overrode straight to theme yellow
                    Text { text: "📂 PACIFIC"; font.bold: true; font.pixelSize: 20; font.family: "monospace"; color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow" }
                    Text { text: "UTC+7:  " + getOffsetTime(7);   color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC+8:  " + getOffsetTime(8);   color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC+9:  " + getOffsetTime(9);   color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC+10: " + getOffsetTime(10);  color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC+11: " + getOffsetTime(11);  color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                    Text { text: "UTC+12: " + getOffsetTime(12);  color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"; font.pixelSize: 20; font.family: "monospace" }
                }
            }
        }
    }
}
