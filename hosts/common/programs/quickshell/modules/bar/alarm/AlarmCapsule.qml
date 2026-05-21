import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "." as AlarmInput

Rectangle {
    id: alarmBox
    width: 130

    property string alarmDisplayText: "⏰ Off"
    property string stateFile: "/tmp/waybar_alarm_state"
    
    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(alarmBox, alarmText);
        }
    }

    Process {
        id: alarmFetcher
        running: true
        command: [
            "sh", "-c",
            "SF='/tmp/waybar_alarm_state'; [ ! -f \"$SF\" ] && echo \"⏰ Off\" && exit 0; " +
            "read start total msg < \"$SF\"; cur=$(date +%s); el=$((cur - start)); rem=$((total - el)); " +
            "if [ $rem -le 0 ]; then " +
            "  /run/current-system/sw/bin/notify-send -t 10000 \"Alarm Alert\" \"$(echo \"$msg\" | sed 's/\"//g')\"; " +
            "  /run/current-system/sw/bin/play ~/Documents/communicator.mp3 & " +
            "  echo \"⏰ Off\"; rm -f \"$SF\"; " +
            "else " +
            "  h=$((rem / 3600)); m=$(((rem % 3600) / 60)); s=$((rem % 60)); " +
            "  printf \"⏰ %02dh %02dm %02ds\\n\" $h $m $s; " +
            "fi"
        ]
        environment: [ "PATH=" + root.pathEnv, "HOME=" + root.homeEnv ]
        stdout: SplitParser { 
            onRead: data => { alarmBox.alarmDisplayText = data ? data.trim() : "⏰ Off" } 
        }
    }

    Process { id: alarmCancelEngine; running: false; command: ["rm", "-f", "/tmp/waybar_alarm_state"] }
    Process { id: alarmWriteEngine; running: false }

    // FIXED: Passing explicit strings directly into the function guarantees execution parameters
    function confirmAndSaveAlarm(rawTimerText, rawMsgText) {
        var rawTimer = rawTimerText.trim();
        var msg = rawMsgText.trim() || "Alarm Finished!";
        
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

        timeInput.text = "";
        msgInput.text = "";
        inputPopup.visible = false;
    }

    function cancelAndClosePopup() {
        timeInput.text = "";
        msgInput.text = "";
        inputPopup.visible = false;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                inputPopup.visible = !inputPopup.visible;
                if (inputPopup.visible) {
                    timeInput.forceActiveFocus();
                }
            } else if (mouse.button === Qt.RightButton) {
                alarmCancelEngine.running = false;
                alarmCancelEngine.running = true;
                alarmBox.alarmDisplayText = "⏰ Off";
                cancelAndClosePopup();
            }
        }
    }

    Text { 
        id: alarmText
        anchors.centerIn: parent 
        text: alarmBox.alarmDisplayText 
        font.family: "monospace" 
        font.pixelSize: 15 
        font.bold: true 
    }

    PanelWindow {
        id: inputPopup
        visible: false
        
        screen: standardBarWindow.screen
        
        WlrLayershell.keyboardFocus: WlrLayershell.Exclusive
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.namespace: "quickshell-alarm-prompt"
        
        anchors.top: parent.top
        anchors.left: parent.left
        
        WlrLayershell.margins.top: 48
        WlrLayershell.margins.left: 20
        
        implicitWidth: 320
        implicitHeight: 150

        Rectangle {
            anchors.fill: parent
            color: "#1a1a1a"
            border.color: "#003399"
            border.width: 3
            radius: 8

            Column {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 12

                Text {
                    text: "Set Native System Alarm"
                    color: "#ffffff"
                    font.family: "monospace"
                    font.pixelSize: 15
                    font.bold: true
                }

                AlarmInput.AlarmInputField {
                    id: timeInput
                    placeholderText: "Duration (e.g. 5m, 1h30m, 45s)"
                    KeyNavigation.tab: msgInput

                    onAccepted: alarmBox.confirmAndSaveAlarm(timeInput.text, msgInput.text)
                    onRejected: alarmBox.cancelAndClosePopup()
                }

                AlarmInput.AlarmInputField {
                    id: msgInput
                    placeholderText: "Reminder Message"
                    KeyNavigation.backtab: timeInput

                    onAccepted: alarmBox.confirmAndSaveAlarm(timeInput.text, msgInput.text)
                    onRejected: alarmBox.cancelAndClosePopup()
                }
            }
        }
    }

    Timer { 
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            alarmFetcher.running = false;
            alarmFetcher.running = true;
        }
    }
}
