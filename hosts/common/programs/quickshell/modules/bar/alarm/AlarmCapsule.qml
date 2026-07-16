import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "." as AlarmInput
import "../../style"

Item {
    id: alarmBox

    // Tooltip Sizing
    property int tooltipHeight: 420
    property var barWindow: null

    // Slant config
    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: shell.theme.slantWidth

    // Tooltip slant
    readonly property real tooltipSlantWidth: (alarmBox.height > 0)
    ? (tooltipHeight * (slantWidth / alarmBox.height))
    : 15

    // Tooltip Sizing
    property int tooltipWidth: 410 + (tooltipSlantWidth * 2)
    property string alarmDisplayText: "No Alarm"
    property string stateFile: "/tmp/waybar_alarm_state"
    property bool popupVisible: false

    // SlantedBox Background
    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: alarmBox.slantLeft
        slantRight: alarmBox.slantRight
        slantWidth: alarmBox.slantWidth
    }

    width: 140
    height: parent.height

    Process {
        id: alarmFetcher
        running: true
        command: [
            "sh", "-c",
            "SF='/tmp/waybar_alarm_state'; [ ! -f \"$SF\" ] && echo \"No Alarm\" && exit 0; " +
            "read start total msg < \"$SF\"; cur=$(date +%s); el=$((cur - start)); rem=$((total - el)); " +
            "if [ $rem -le 0 ]; then " +
            "  /run/current-system/sw/bin/notify-send -t 10000 \"Alarm Alert\" \"$(echo \"$msg\" | sed 's/\"//g')\"; " +
            "  pw-cat -p ~/Documents/communicator.mp3 || play ~/Documents/communicator.mp3 || true & " +
            "  echo \"No Alarm\"; rm -f \"$SF\"; " +
            "else " +
            "  h=$((rem / 3600)); m=$(((rem % 3600) / 60)); s=$((rem % 60)); " +
            "  printf \"%02dh %02dm %02ds\\n\" $h $m $s; " +
            "fi"
        ]
        stdout: SplitParser {
            onRead: data => { alarmBox.alarmDisplayText = data ? data.trim() : "No Alarm" }
        }
    }

    Process { id: alarmCancelEngine; running: false; command: ["rm", "-f", "/tmp/waybar_alarm_state"] }
    Process { id: alarmWriteEngine; running: false }

    function confirmAndSaveAlarm(countdownRaw, timeOfDayRaw) {
        var msg = "Alarm Finished!";
        var totalSeconds = 0;
        var currentEpoch = Math.floor(Date.now() / 1000);
        var now = new Date();

         //  Countdown priority override
        if (countdownRaw && countdownRaw.trim() !== "") {
            var rawTimer = countdownRaw.trim().toLowerCase();
            var match;
            var regex = /(\d+)([hms])/g;

            while ((match = regex.exec(rawTimer)) !== null) {
                var num = parseInt(match[1], 10);
                var unit = match[2];

                if (unit === 'h') totalSeconds += num * 3600;
                if (unit === 'm') totalSeconds += num * 60;
                if (unit === 's') totalSeconds += num;
            }

            // Fallback for plain integers
            if (totalSeconds === 0 && /^\d+$/.test(rawTimer)) {
                totalSeconds = parseInt(rawTimer, 10) * 60;
            }
        }

            // Time Parser
            if (totalSeconds === 0 && timeOfDayRaw && timeOfDayRaw.trim() !== "") {
            var timeStr = timeOfDayRaw.trim().toUpperCase().replace(/[:\s]/g, "");
            var cleanMatch = /^(\d{3,4})(AM|PM)?$/.exec(timeStr);

            if (cleanMatch !== null) {
                var digits = cleanMatch[1];
                var ampm = cleanMatch[2];
                var targetHours = 0;
                var targetMinutes = 0;

                if (digits.length === 4) {
                    targetHours = parseInt(digits.substring(0, 2), 10);
                    targetMinutes = parseInt(digits.substring(2, 4), 10);
                } else if (digits.length === 3) {
                    targetHours = parseInt(digits.substring(0, 1), 10);
                    targetMinutes = parseInt(digits.substring(1, 3), 10);
                }

                if (targetHours <= 24 && targetMinutes < 60) {
                    if (targetHours === 12 && !ampm) {
                        targetHours = 12;
                    } else if (ampm) {
                        if (ampm === "PM" && targetHours < 12) targetHours += 12;
                        if (ampm === "AM" && targetHours === 12) targetHours = 0;
                    }

                    var targetTime = new Date(now.getFullYear(), now.getMonth(), now.getDate(), targetHours, targetMinutes, 0, 0);

                    if (!ampm && targetHours <= 12 && targetTime.getTime() <= now.getTime()) {
                        var pmHours = (targetHours === 12) ? 0 : targetHours + 12;
                        var pmTime = new Date(now.getFullYear(), now.getMonth(), now.getDate(), pmHours, targetMinutes, 0, 0);

                        if (pmTime.getTime() > now.getTime()) {
                            targetTime = pmTime;
                        }
                    }

                    if (targetTime.getTime() <= now.getTime()) {
                        targetTime.setDate(targetTime.getDate() + 1);
                    }

                    totalSeconds = Math.floor(targetTime.getTime() / 1000) - currentEpoch;
                }
            }
        }

        if (totalSeconds > 0) {
            var stateString = currentEpoch + " " + totalSeconds + " \"" + msg + "\"";
            alarmWriteEngine.command = ["sh", "-c", "echo '" + stateString + "' > /tmp/waybar_alarm_state"];
            alarmWriteEngine.running = false;
            alarmWriteEngine.running = true;
        }
        cancelAndClosePopup();
    }

    function cancelAndClosePopup() {
        if (typeof timeInput !== "undefined" && timeInput !== null) {
            timeInput.countdownText = "";
        }
        alarmBox.popupVisible = false;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                alarmBox.popupVisible = !alarmBox.popupVisible;
            } else if (mouse.button === Qt.RightButton) {
                alarmCancelEngine.running = false;
                alarmCancelEngine.running = true;
                alarmBox.alarmDisplayText = "No Alarm";
                cancelAndClosePopup();
            }
        }
    }

    // Main Bar display text
    Text {
        id: alarmText
        anchors.fill: parent

        // clear margins using SlantedBox paddings
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: shell.theme.globalPadding
        anchors.bottomMargin: shell.theme.globalPadding

        text: alarmBox.alarmDisplayText
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        color: shell.theme.base05
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // Panel Renderer
    PanelWindow {
        id: inputPopup
        visible: alarmBox.popupVisible
        screen: alarmBox.barWindow ? alarmBox.barWindow.screen : null

        WlrLayershell.keyboardFocus: visible ? WlrLayershell.Exclusive : WlrLayershell.None
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.namespace: "quickshell-alarm-prompt"

        anchors.top: true
        anchors.left: true
        anchors.right: false
        anchors.bottom: false
        //  top position to match  other tooltips
        WlrLayershell.margins.top: shell.theme.globalPadding + 55

        // Centers the alarm pop-up under the top bar capsule
        WlrLayershell.margins.left: {
            if (!alarmBox.barWindow) return 0;

            // loop to find the horizontal position of the Alarm capsule
            var xOffset = alarmBox.x;
            var p = alarmBox.parent;
            while (p && p !== alarmBox.barWindow.contentItem) {
                xOffset += p.x;
                p = p.parent;
            }

            var centerPoint = xOffset + (alarmBox.width / 2);
            var targetLeftMargin = Math.round(centerPoint - (alarmBox.tooltipWidth / 2));
            return Math.max(targetLeftMargin, shell.theme.globalPadding);
        }

        implicitWidth: alarmBox.tooltipWidth
        implicitHeight: alarmBox.tooltipHeight
        color: "transparent"

        onVisibleChanged: {
            if (visible && typeof timeInput !== "undefined" && timeInput !== null) {
                timeInput.forceInitialFocus();
            }
        }

        // Tooltip background using SlantedBox
        SlantedBox {
            id: tooltipBg
            anchors.fill: parent
            slantLeft: alarmBox.slantLeft
            slantRight: alarmBox.slantRight
            slantWidth: alarmBox.tooltipSlantWidth
            readonly property real slantRatio: (height > 0) ? (slantWidth / height) : 0.35
        }

        Item {
            anchors.fill: parent

            Text {
                id: alarmTitle
                text: "Set Native System Alarm"
                font.family: shell.theme.fontFamily
                font.pixelSize: 22
                font.bold: true
                color: shell.theme.base05

                y: 35
                x: (y * tooltipBg.slantRatio) + 24
                width: tooltipBg.width - alarmBox.tooltipSlantWidth - 48
            }

            Rectangle {
                height: 2
                color: shell.theme.base02
                width: tooltipBg.width - alarmBox.tooltipSlantWidth - 48

                y: 70
                x: (y * tooltipBg.slantRatio) + 24
            }

            AlarmInput.AlarmInputField {
                id: timeInput

                y: 95
                x: (95 * tooltipBg.slantRatio) + 24
                width: tooltipBg.width - alarmBox.tooltipSlantWidth - 48
                slantRatio: tooltipBg.slantRatio

                onAccepted: alarmBox.confirmAndSaveAlarm(timeInput.countdownText, timeInput.targetTimeText)
                onRejected: alarmBox.cancelAndClosePopup()
            }
        }
    }
}
