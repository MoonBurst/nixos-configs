import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "." as AlarmInput

Rectangle {
    id: alarmBox

    // Expanded width prevents character clipping on countdown strings
    width: 165
    height: 35
    radius: 10
    border.width: 3

    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

    property string alarmDisplayText: "No Alarm"
    property string stateFile: "/tmp/waybar_alarm_state"
    property bool popupVisible: false

    property int globalX: 0

    Process {
        id: alarmFetcher
        running: true
        command: [
            "sh", "-c",
            "SF='/tmp/waybar_alarm_state'; [ ! -f \"$SF\" ] && echo \"No Alarm\" && exit 0; " +
            "read start total msg < \"$SF\"; cur=$(date +%s); el=$((cur - start)); rem=$((total - el)); " +
            "if [ $rem -le 0 ]; then " +
            "  /run/current-system/sw/bin/notify-send -t 10000 \"Alarm Alert\" \"$(echo \"$msg\" | sed 's/\"//g')\"; " +
            "  ${pkgs.pw-cat}/bin/pw-play ~/Documents/communicator.mp3 || /run/current-system/sw/bin/play ~/Documents/communicator.mp3 || true & " +
            "  echo \"No Alarm\"; rm -f \"$SF\"; " +
            "else " +
            "  h=$((rem / 3600)); m=$(((rem % 3600) / 60)); s=$((rem % 60)); " +
            "  printf \"%02dh %02dm %02ds\\n\" $h $m $s; " +
            "fi"
        ]
        environment: [
            "PATH=" + root.pathEnv,
            "HOME=" + root.homeEnv,
            "XDG_RUNTIME_DIR=/run/user/1000",
            "PULSE_SERVER=unix:/run/user/1000/pulse/native"
        ]
        stdout: SplitParser {
            onRead: data => { alarmBox.alarmDisplayText = data ? data.trim() : "No Alarm" }
        }
    }

    Process { id: alarmCancelEngine; running: false; command: ["rm", "-f", "/tmp/waybar_alarm_state"] }
    Process { id: alarmWriteEngine; running: false }

    function confirmAndSaveAlarm(rawTimerText) {
        var rawTimer = rawTimerText.trim();
        var msg = "Alarm Finished!";
        var totalSeconds = 0;
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

        if (totalSeconds > 0) {
            var currentEpoch = Math.floor(Date.now() / 1000);
            var stateString = currentEpoch + " " + totalSeconds + " \"" + msg + "\"";
            alarmWriteEngine.command = ["sh", "-c", "echo '" + stateString + "' > /tmp/waybar_alarm_state"];
            alarmWriteEngine.running = false;
            alarmWriteEngine.running = true;
        }
        cancelAndClosePopup();
    }

    function cancelAndClosePopup() {
        timeInput.text = "";
        alarmBox.popupVisible = false;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                if (standardBarWindow && standardBarWindow.contentItem) {
                    var globalCoords = alarmBox.mapToItem(standardBarWindow.contentItem, 0, 0);
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
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "#F7F700"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    PanelWindow {
        id: inputPopup
        visible: alarmBox.popupVisible
        screen: standardBarWindow.screen
        WlrLayershell.keyboardFocus: visible ? WlrLayershell.Exclusive : WlrLayershell.None
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.namespace: "quickshell-alarm-prompt"

        anchors.top: true
        anchors.left: true
        WlrLayershell.margins.top: 50
        WlrLayershell.margins.left: alarmBox.globalX

        implicitWidth: 300
        implicitHeight: 110
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                timeInput.forceActiveFocus();
            }
        }

        Rectangle {
            id: popupRect
            anchors.fill: parent
            radius: 10
            border.width: 2

            Binding {
                target: popupRect
                property: "color"
                value: (typeof Theme !== 'undefined' && Theme.base01 !== undefined) ? Theme.base01 : "#0F0F0F"
            }
            Binding {
                target: popupRect
                property: "border.color"
                value: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "#F7F700"
            }

            Column {
                id: alarmCol
                anchors.centerIn: parent
                spacing: 12

                Text {
                    id: alarmTitle
                    text: "Set Native System Alarm"
                    font.family: "monospace"
                    font.pixelSize: 18
                    font.bold: true
                    color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "#F7F700"
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                AlarmInput.AlarmInputField {
                    id: timeInput
                    width: 220
                    anchors.horizontalCenter: parent.horizontalCenter
                    onAccepted: alarmBox.confirmAndSaveAlarm(timeInput.text)
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
