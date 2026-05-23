import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "." as AlarmInput

Rectangle {
    id: alarmBox

    // FIXED: Added the property target definition so shell.qml mapping context works flawlessly
    property var barWindow: null
    property string alarmDisplayText: "No Alarm"
    property string stateFile: "/tmp/waybar_alarm_state"
    property bool popupVisible: false
    property int globalX: 0

    // Geometry parameters and frames scale dynamically to match your global design rule profiles
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
        // FIXED: Hardcoded paths match standard Linux structures safely rather than falling back to broken root vars
        environment: [
            "PATH=/run/current-system/sw/bin:/usr/bin:/bin",
            "HOME=/home/moonburst",
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
                // FIXED: Dynamically tracks map positions against the injected barWindow reference safely
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

    // ============================================================================
    // ALARM CONFIGURATION PROMPT OVERLAY PANEL WINDOW
    // ============================================================================
    PanelWindow {
        id: inputPopup
        visible: alarmBox.popupVisible

        // FIXED: References your dynamic barWindow hook to isolate multi-head monitor spaces
        screen: alarmBox.barWindow ? alarmBox.barWindow.screen : null

        WlrLayershell.keyboardFocus: visible ? WlrLayershell.Exclusive : WlrLayershell.None
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-alarm-prompt"

        anchors.top: true
        anchors.left: true
        anchors.right: false
        anchors.bottom: false

        // FIXED: Dropdown shifts pull accurately from global padding profiles
        WlrLayershell.margins.top: 55 + shell.theme.globalPadding
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
