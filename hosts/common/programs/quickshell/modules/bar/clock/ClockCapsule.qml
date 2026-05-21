import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Controls

Rectangle {
    id: clockCapsule
    width: 145
    height: 38

    // Capsule colors: fallback to yellow/black if no theme
    property color capsuleBg: typeof root !== "undefined" && root.theme ? root.theme.base00 : "#000000"
    property color capsuleFg: typeof root !== "undefined" && root.theme ? root.theme.base05 : "yellow"
    property color capsuleBorder: typeof root !== "undefined" && root.theme ? root.theme.base05 : "yellow"

    // Provide barWindow for tooltip anchoring (must be set by parent Loader!)
    property var barWindow: null

    // --- World Clock Properties ---
    property var timezones: [
        "UTC",
        "America/New_York",
        "America/Chicago",   // Central
        "America/Denver",
        "America/Los_Angeles",
        "Europe/London",
        "Europe/Berlin",
        "Asia/Tokyo",
        "Australia/Sydney"
    ]
    property string timezoneTooltipText: "Loading…"
    property string localTime: "---"
    property string localZoneName: ""

    // --- Local Time Calculation ---
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            // 12-hour w/ uppercase AM/PM, no zone
            var hr = d.getHours() % 12; hr = hr === 0 ? 12 : hr;
            var min = ("0" + d.getMinutes()).slice(-2);
            var sec = ("0" + d.getSeconds()).slice(-2);
            var ap = d.getHours() >= 12 ? "PM" : "AM";
            clockCapsule.localTime = `${hr}:${min}:${sec} ${ap}`;
            clockCapsule.localZoneName = d.toLocaleTimeString(Qt.locale(), "zzzz");
        }
    }

    // --- Fetch World Times for Tooltip ---
    Process {
        id: timezoneFetcher
        property string formatString: "+%Y-%m-%d %I:%M:%S %p %Z"
        onStarted: clockCapsule.timezoneTooltipText = "Loading…"
        stdout: SplitParser {
            onRead: function(data) {
                clockCapsule.timezoneTooltipText = data.trim();
            }
        }
    }
    Timer {
        interval: 10000 // 10 seconds
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var cmds = [];
            for (var i = 0; i < clockCapsule.timezones.length; i++) {
                var zone = clockCapsule.timezones[i];
                cmds.push(
                    "printf '%-22s %s\\n' '" + zone + "' \"$(TZ=" + zone + " date '" +
                    timezoneFetcher.formatString + "')\""
                );
            }
            timezoneFetcher.command = ["sh", "-c", cmds.join("; ")];
            timezoneFetcher.running = true;
        }
    }

    // --- Capsule Style ---
    radius: 7
    border.width: 3
    border.color: capsuleBorder
    color: capsuleBg

    // --- Hover Handler & Tooltip ---
    HoverHandler { id: clockHover }

    PopupWindow {
        visible: clockCapsule.barWindow && clockHover.hovered
        anchor.window: clockCapsule.barWindow
        anchor.rect: Qt.rect(clockCapsule.mapToItem(barWindow.contentItem, 0, 0).x, barWindow.implicitHeight, clockCapsule.width, 0)
        color: "transparent"
        implicitWidth: tooltipText.implicitWidth + 24
        implicitHeight: tooltipText.implicitHeight + 38

        Rectangle {
            anchors.fill: parent
            border.color: clockCapsule.capsuleFg
            border.width: 2
            radius: 6
            color: clockCapsule.capsuleBg

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6
                Text {
                    text: "Local TZ: " + clockCapsule.localZoneName
                    font.family: "monospace"
                    font.pixelSize: 14
                    color: clockCapsule.capsuleFg
                }
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#444"
                }
                Text {
                    id: tooltipText
                    text: clockCapsule.timezoneTooltipText
                    font.family: "monospace"
                    font.pixelSize: 15
                    color: clockCapsule.capsuleFg
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignTop
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // --- Main Time Display (bar) ---
    Text {
        id: timeText
        anchors.fill: parent
        anchors.margins: 6
        text: clockCapsule.localTime
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        color: clockCapsule.capsuleFg
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
