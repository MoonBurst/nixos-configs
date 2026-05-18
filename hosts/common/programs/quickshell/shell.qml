import Quickshell
import Quickshell.Io 
import QtQuick
import QtQuick.Controls

Scope {
    id: root

    readonly property string displayEnv: Quickshell.env("DISPLAY") || ""
    readonly property string waylandEnv: Quickshell.env("WAYLAND_DISPLAY") || ""
    readonly property string homeEnv: Quickshell.env("HOME") || ""
    readonly property string pathEnv: Quickshell.env("PATH") || "/run/current-system/sw/bin:/usr/bin:/bin"

    property string currentSongText: "No Song Playing"
    property string calendarTooltipText: ""
    property string weatherDisplayText: "晴 --°F"
    property string weatherTooltipText: "Fetching forecast..."

    Process { id: musicToggleCmd; command: ["/bin/sh", "-c", "audtool current-song >/dev/null 2>&1 && ( [ \"$(audtool playback-status)\" = \"playing\" ] && audtool playback-pause || audtool playback-play ) || ( audacious & sleep 2 && audtool mainwin-show on && audtool playback-play )"] }

    Process {
        id: calFetcher
        running: true
        command: ["sh", "-c", "cal --color=never"]
        stdout: SplitParser { onRead: data => { if (data) root.calendarTooltipText = data; } }
    }

    Process {
        id: musicFetcher
        running: true
        command: [
            "sh", "-c",
            "if audtool current-song >/dev/null 2>&1; then " +
            "  [ \"$(audtool playback-status)\" = \"playing\" ] && p=\"▶ \" || p=\"⏸ \"; echo \"$p$(audtool current-song)\"; " +
            "else echo \"Music Offline\"; fi"
        ]
        stdout: SplitParser { onRead: data => { if (data) root.currentSongText = data.trim(); } }
    }

    Process {
        id: weatherProc
        running: true
        command: [
            "sh", "-c",
            "C=$(cat /run/secrets/weather_city 2>/dev/null | xargs || :); K=$(cat /run/secrets/weather_api_key 2>/dev/null | xargs || :); " +
            "[ -z \"$C\" ] || [ -z \"$K\" ] && echo \"ERR|Missing API secrets\" && exit 0; " +
            "cur=$(curl -s \"https://openweathermap.org\"); " +
            "fc=$(curl -s \"https://openweathermap.org\"); " +
            "k_temp=$(echo \"$cur\" | jq -r '.main.temp // 0'); " +
            "t_out=\"Hourly Forecast:\\n\"; for row in $(echo \"$fc\" | jq -c '.list[]'); do " +
            "  dr=$(echo \"$row\" | jq -r '.dt'); ds=$(date -d @$dr +'%H:%M' 2>/dev/null || echo '--:--'); " +
            "  fk=$(echo \"$row\" | jq -r '.main.temp'); ff=$(awk -v k=\"$fk\" 'BEGIN{printf \"%.0f\", ((k-273.15)*9/5)+32}'); " +
            "  dc=$(echo \"$row\" | jq -r '.weather.description // \".\"'); dcap=$(echo \"$dc\" | awk '{print toupper(substr($0,1,1)) substr($0,2)}'); " +
            "  t_out=\"${t_out}${ds}: ${ff}°F, ${dcap}\\n\"; done; " +
            "echo \"$k_temp|$t_out\""
        ]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var p = data.trim().split("|");
                if (p.length < 2) return;
                
                // Native JavaScript conversions cleanly eliminate printf parsing bugs
                var kelvin = parseFloat(p[0]);
                var fahrenheit = 0;
                if (kelvin > 0) {
                    fahrenheit = Math.round(((kelvin - 273.15) * 9 / 5) + 32);
                }
                
                var col = fahrenheit >= 86 ? '#FF0000' : (fahrenheit >= 77 ? 'yellow' : '#33FF33');
                
                root.weatherDisplayText = "<font color='" + col + "'>" + fahrenheit + "°F</font>";
                root.weatherTooltipText = p[1];
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        property int tick: 0
        onTriggered: {
            musicFetcher.running = true;
            if (tick % 1800 === 0) { calFetcher.running = true; weatherProc.running = true; }
            tick++;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: modelData.name === "DP-1"
            anchors { top: true; left: true; right: true }
            implicitHeight: visible ? 36 : 0 

            Rectangle {
                anchors.fill: parent; color: "#1a1a1a"; border.width: 5; border.color: "#003399"; radius: 12 

                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 16; spacing: 15 

                    Rectangle {
                        color: Theme.colorBaseBg; radius: Theme.capsuleRadius; border.width: Theme.capsuleBorderWidth; border.color: Theme.colorOutline
                        width: 115; height: Theme.capsuleHeight; anchors.verticalCenter: parent.verticalCenter
                        HoverHandler { id: calendarHover }
                        ToolTip {
                            visible: calendarHover.hovered; delay: 100 
                            contentItem: Text { text: root.calendarTooltipText; color: Theme.colorNormalText; font.family: "monospace"; font.pixelSize: 13 }
                            background: Rectangle { color: Theme.colorBaseBg; border.color: "#003399"; border.width: Theme.capsuleBorderWidth; radius: 6 }
                        }
                        Text { anchors.centerIn: parent; color: Theme.colorNormalText; font.family: "monospace"; font.pixelSize: 15; font.bold: true; text: Qt.formatDateTime(systemTimeGlobal.date, "ddd MMM dd") }
                    }

                    Rectangle {
                        color: Theme.colorBaseBg; radius: Theme.capsuleRadius; border.width: Theme.capsuleBorderWidth; border.color: Theme.colorOutline
                        width: 70; height: Theme.capsuleHeight; anchors.verticalCenter: parent.verticalCenter
                        HoverHandler { id: weatherHover }
                        ToolTip {
                            visible: weatherHover.hovered; delay: 100
                            contentItem: Text { text: root.weatherTooltipText; color: Theme.colorNormalText; font.family: "monospace"; font.pixelSize: 13 }
                            background: Rectangle { color: Theme.colorBaseBg; border.color: "#003399"; border.width: Theme.capsuleBorderWidth; radius: 6 }
                        }
                        Text { anchors.centerIn: parent; textFormat: Text.RichText; text: root.weatherDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }
                    }

                    AlarmCapsule {}

                    Rectangle {
                        color: Theme.colorBaseBg; radius: Theme.capsuleRadius; border.width: Theme.capsuleBorderWidth; border.color: Theme.colorOutline
                        width: 180; height: Theme.capsuleHeight; anchors.verticalCenter: parent.verticalCenter; clip: true 
                        TapHandler { onTapped: { musicToggleCmd.running = false; musicToggleCmd.running = true; } }
                        Text { id: musicDisplay; anchors.centerIn: parent; text: root.currentSongText; color: Theme.colorNormalText; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; spacing: 15 

                    AudioCapsule {}

                    Rectangle {
                        color: Theme.colorBaseBg; radius: Theme.capsuleRadius; border.width: Theme.capsuleBorderWidth; border.color: Theme.colorOutline
                        width: 115; height: Theme.capsuleHeight; anchors.verticalCenter: parent.verticalCenter
                        Text { anchors.centerIn: parent; color: Theme.colorNormalText; font.family: "monospace"; font.pixelSize: 15; font.bold: true; text: Qt.formatDateTime(systemTimeGlobal.date, "hh:mm:ss AP") }
                    }
                }

                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 16; spacing: 15 

                    NetCapsule {}

                    GpuCapsule {}

                    CpuCapsule {}

                    RamCapsule {}
                }
            }
        }
    }

    NotificationManager {}

    SystemClock { id: systemTimeGlobal; precision: SystemClock.Seconds }
}
