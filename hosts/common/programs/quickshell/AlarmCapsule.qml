import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: alarmBox
    color: Theme.colorBaseBg
    radius: Theme.capsuleRadius
    border.width: Theme.capsuleBorderWidth
    border.color: Theme.colorOutline
    width: 130
    height: Theme.capsuleHeight

    property string alarmDisplayText: "⏰ Off"

    Process {
        id: alarmFetcher
        running: true
        command: [
            "sh", "-c",
            "SF='/tmp/waybar_alarm_state'; " +
            "if [ ! -f \"$SF\" ]; then echo \"⏰ Off\" && exit 0; fi; " +
            "read start_time total_seconds message < \"$SF\"; " +
            "clean_msg=$(echo \"$message\" | sed 's/\"//g'); " +
            "current_time=$(date +%s); " +
            "elapsed=$((current_time - start_time)); " +
            "remaining=$((total_seconds - elapsed)); " +
            "if [ $remaining -le 0 ]; then " +
            "  /run/current-system/sw/bin/notify-send -t 10000 \"Alarm Alert\" \"$clean_msg\"; " +
            "  /run/current-system/sw/bin/play ~/Documents/communicator.mp3 & " +
            "  echo \"⏰ Off\"; " +
            "  rm -f \"$SF\"; " +
            "else " +
            "  h=$((remaining / 3600)); m=$(((remaining % 3600) / 60)); s=$((remaining % 60)); " +
            "  time_str=$(printf \"%%02dh %%02dm %%02ds\" $h $m $s); " +
            "  /run/current-system/sw/bin/notify-send -r 9999 -t 1500 \"Alarm Counting Down\" \"Remaining: $time_str\\nMessage: $clean_msg\"; " +
            "  echo \"⏰ $time_str\"; " +
            "fi"
        ]
        environment: [ "PATH=" + root.pathEnv, "HOME=" + root.homeEnv ]
        stdout: SplitParser { 
            onRead: data => { 
                if (data && data.trim() !== "") {
                    alarmBox.alarmDisplayText = data.trim(); 
                } else {
                    alarmBox.alarmDisplayText = "⏰ Off";
                }
            } 
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (eventPoint) => { 
            if (eventPoint.button === Qt.LeftButton) {
                Quickshell.run(["/bin/sh", "-c", "export DISPLAY=" + root.displayEnv + " WAYLAND_DISPLAY=" + root.waylandEnv + " HOME=" + root.homeEnv + " PATH=" + root.pathEnv + "; bash $HOME/bin/alarm.sh set &"]);
            } else {
                Quickshell.run(["/bin/sh", "-c", "export DISPLAY=" + root.displayEnv + " WAYLAND_DISPLAY=" + root.waylandEnv + " HOME=" + root.homeEnv + " PATH=" + root.pathEnv + "; bash $HOME/bin/alarm.sh cancel &"]);
                alarmBox.alarmDisplayText = "⏰ Off";
            } 
        }
    }

    Text { 
        anchors.centerIn: parent 
        text: alarmBox.alarmDisplayText 
        color: Theme.colorNormalText 
        font.family: "monospace" 
        font.pixelSize: 15 
        font.bold: true 
    }

    Timer { 
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            alarmFetcher.running = false;
            alarmFetcher.running = true;
        }
    }
}
