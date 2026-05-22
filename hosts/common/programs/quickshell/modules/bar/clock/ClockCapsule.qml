import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

import Theme

Rectangle {
    id: clockCapsule

    // Sovereign sizing rules restore visual visibility matching your bar grid layout
    width: 145
    height: 35
    radius: 10
    border.width: 3

    // Direct lookups pointing straight to your immutable compiled Nix-Store colors
    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

    // Provide barWindow for tooltip anchoring (must be set by parent Loader!)
    property var barWindow: null

    // --- World Clock Properties ---
    property var timezones: [
        "UTC",
        "America/New_York",
        "America/Chicago",
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

    SystemClock { id: systemTime; precision: SystemClock.Seconds }

    // --- Local Time Calculation via High-Performance Native Engines ---
    Binding {
        target: clockCapsule
        property: "localTime"
        value: systemTime.date ? Qt.formatDateTime(systemTime.date, "hh:mm:ss AP") : "---"
    }
    Binding {
        target: clockCapsule
        property: "localZoneName"
        value: systemTime.date ? Qt.formatDateTime(systemTime.date, "t") : ""
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

    // --- Hover Handler & Tooltip ---
    HoverHandler { id: clockHover }

    PopupWindow {
        visible: clockCapsule.barWindow && clockHover.hovered
        anchor.window: clockCapsule.barWindow

        // Robust coordinate mapping fixes the popup positioning under decoupled loaders
        anchor.rect: (clockCapsule.barWindow && clockCapsule.barWindow.contentItem) ?
        Qt.rect(clockCapsule.mapToItem(clockCapsule.barWindow.contentItem, 0, 0).x, clockCapsule.barWindow.implicitHeight, clockCapsule.width, 0) :
        Qt.rect(0, 50, clockCapsule.width, 0)

        color: "transparent"
        implicitWidth: tooltipText.implicitWidth + 24
        implicitHeight: tooltipText.implicitHeight + 38

        Rectangle {
            anchors.fill: parent
            border.width: 2
            radius: 6
            color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
            border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                Text {
                    text: "Local TZ: " + clockCapsule.localZoneName
                    font.family: "monospace"
                    font.pixelSize: 14
                    color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"
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
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignTop
                    wrapMode: Text.Wrap
                    color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"
                }
            }
        }
    }

    // --- Main Time Display (bar) ---
    Text {
        id: timeText
        anchors.fill: parent
        anchors.margins: 5
        text: clockCapsule.localTime
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"
    }
}
