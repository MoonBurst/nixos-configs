import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "." as AlarmInput

Rectangle {
    id: alarmBox

    property var barWindow: null
    property string alarmDisplayText: "No Alarm"
    property string stateFile: "/tmp/waybar_alarm_state"
    property bool popupVisible: false
    property int globalX: 0

    width: 140
    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth

    color: shell.theme.base00
    border.color: shell.theme.base05

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

        // ============================================================================
        // FIXED SMART TIME PARSER (HANDLES 12:00 ROLLOVER CAPTURE CORRECTLY)
        // ============================================================================
        if (timeOfDayRaw.trim() !== "") {
            var timeStr = timeOfDayRaw.trim().toUpperCase().replace(/[:\s]/g, "");
            var cleanMatch = /^(\d{3,4})(AM|PM)?$/.exec(timeStr);

            if (cleanMatch) {
                var digits = cleanMatch[1]; // FIXED: Extract from array index 1
                var ampm = cleanMatch[2];   // FIXED: Extract from array index 2
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
                    // Normalize standard 12-hour clock notations immediately
                    if (targetHours === 12 && !ampm) {
                        // If user inputs a plain "12", evaluate whether they mean midnight or noon
                        targetHours = 12;
                    } else if (ampm) {
                        if (ampm === "PM" && targetHours < 12) targetHours += 12;
                        if (ampm === "AM" && targetHours === 12) targetHours = 0;
                    }

                    var targetTime = new Date(now.getFullYear(), now.getMonth(), now.getDate(), targetHours, targetMinutes, 0, 0);

                    // Auto PM Switch: If target has already passed, check if switching to PM fits today
                    if (!ampm && targetHours <= 12 && targetTime.getTime() <= now.getTime()) {
                        var pmHours = (targetHours === 12) ? 0 : targetHours + 12; // 12 rolls to midnight, others shift by 12
                        var pmTime = new Date(now.getFullYear(), now.getMonth(), now.getDate(), pmHours, targetMinutes, 0, 0);

                        // If rolling hours makes it later today, use it, otherwise prepare for tomorrow morning
                        if (pmTime.getTime() > now.getTime()) {
                            targetTime = pmTime;
                        }
                    }

                    // Shift to tomorrow if the calculated time is still in the past
                    if (targetTime.getTime() <= now.getTime()) {
                        targetTime.setDate(targetTime.getDate() + 1);
                    }

                    totalSeconds = Math.floor(targetTime.getTime() / 1000) - currentEpoch;
                }
            }
        }

        // ============================================================================
        // COUNTDOWN FALLBACK
        // ============================================================================
        if (totalSeconds === 0 && countdownRaw.trim() !== "") {
            var rawTimer = countdownRaw.trim();
            var match;
            var regex = /(\d+)([hms])/g;

            while ((match = regex.exec(rawTimer)) !== null) {
                var num = parseInt(match[1], 10);
                var unit = match[2];
                if (unit === 'h') totalSeconds += num * 3600;
                if (unit === 'm') totalSeconds += num * 60;
                if (unit === 's') totalSeconds += num;
            }

            if (totalSeconds === 0 && /^\d+$/.test(rawTimer)) {
                totalSeconds = parseInt(rawTimer, 10) * 60;
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
        timeInput.countdownText = "";
        timeInput.targetTimeText = "";
        alarmBox.popupVisible = false;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                if (alarmBox.barWindow && alarmBox.barWindow.contentItem) {
                    var globalCoords = alarmBox.mapToItem(alarmBox.barWindow.contentItem, 0, 0);
                    alarmBox.globalX = globalCoords.x;
                }
                alarmBox.popupVisible = !alarmBox.popupVisible;
            } else if (mouse.button === Qt.RightButton) {
                alarmCancelEngine.running = false;
                alarmCancelEngine.running = true;
                alarmBox.alarmDisplayText = "No Alarm";
                cancelAndClosePopup();
            }
        }
    }

    Text {
        id: alarmText
        anchors.fill: parent
        text: alarmBox.alarmDisplayText
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        color: shell.theme.base05
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    PanelWindow {
        id: inputPopup
        visible: alarmBox.popupVisible
        screen: alarmBox.barWindow ? alarmBox.barWindow.screen : null

        WlrLayershell.keyboardFocus: visible ? WlrLayershell.Exclusive : WlrLayershell.None
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-alarm-prompt"

        anchors.top: true
        anchors.left: true
        anchors.right: false
        anchors.bottom: false

        WlrLayershell.margins.top: 55 + shell.theme.globalPadding
        WlrLayershell.margins.left: alarmBox.globalX

        implicitWidth: 300
        implicitHeight: 250
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                timeInput.forceInitialFocus();
            }
        }

        Rectangle {
            id: popupRect
            anchors.fill: parent
            radius: shell.theme.defaultCardRadius
            border.width: shell.theme.globalBorderWidth
            color: shell.theme.base01
            border.color: shell.theme.base05

            Column {
                id: alarmCol
                anchors.centerIn: parent
                spacing: 12

                Text {
                    id: alarmTitle
                    text: "Set Native System Alarm"
                    font.family: shell.theme.fontFamily
                    font.pixelSize: shell.theme.globalFontSize - 2
                    font.bold: true
                    color: shell.theme.base05
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                AlarmInput.AlarmInputField {
                    id: timeInput
                    width: 220
                    anchors.horizontalCenter: parent.horizontalCenter
                    onAccepted: alarmBox.confirmAndSaveAlarm(timeInput.countdownText, timeInput.targetTimeText)
                    onRejected: alarmBox.cancelAndClosePopup()
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            alarmFetcher.running = false
            alarmFetcher.running = true
        }
    }
}
