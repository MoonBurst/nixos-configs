import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: weatherCapsule
    color: Theme.colorBaseBg
    radius: Theme.capsuleRadius
    border.width: Theme.capsuleBorderWidth
    border.color: Theme.colorOutline
    width: 70
    height: Theme.capsuleHeight
    anchors.verticalCenter: parent.verticalCenter

    property string weatherDisplayText: "晴 --°F"
    property string weatherTooltipText: "Fetching forecast..."

    Process {
        id: weatherProc
        running: true
        command: [
            "sh", "-c",
            "C=$(cat /run/secrets/weather_city 2>/dev/null | xargs || :); K=$(cat /run/secrets/weather_api_key 2>/dev/null | xargs || :); " +
            "[ -z \"$C\" ] || [ -z \"$K\" ] && echo \"ERR|Missing API secrets\" && exit 0; " +
            "cur=$(curl -s \"https://openweathermap.org{C}&appid=${K}\"); " +
            "fc=$(curl -s \"https://openweathermap.org{C}&appid=${K}\"); " +
            "k_temp=$(echo \"$cur\" | jq -r '.main.temp // 0'); " +
            "t_out=\"Hourly Forecast:\\n\"; for row in $(echo \"$fc\" | jq -c '.list[]'); do " +
            "  dr=$(echo \"$row\" | jq -r '.dt'); ds=$(date -d @$dr +'%H:%M' 2>/dev/null || echo '--:--'); " +
            "  fk=$(echo \"$row\" | jq -r '.main.temp'); ff=$(awk -v k=\"$fk\" 'BEGIN{printf \"%.0f\", ((k-273.15)*9/5)+32}'); " +
            "  dc=$(echo \"$row\" | jq -r '.weather[0].description // \".\"'); dcap=$(echo \"$dc\" | awk '{print toupper(substr($0,1,1)) substr($0,2)}'); " +
            "  t_out=\"${t_out}${ds}: ${ff}°F, ${dcap}\\n\"; done; " +
            "echo \"$k_temp|$t_out\""
        ]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                var p = data.trim().split("|");
                if (p.length < 2) return;
                var kelvin = parseFloat(p[0]);
                var fahrenheit = 0;
                if (kelvin > 0) fahrenheit = Math.round(((kelvin - 273.15) * 9 / 5) + 32);
                var col = fahrenheit >= 86 ? '#FF0000' : (fahrenheit >= 77 ? 'yellow' : '#33FF33');
                weatherCapsule.weatherDisplayText = "<font color='" + col + "'>" + fahrenheit + "°F</font>";
                weatherCapsule.weatherTooltipText = p[1];
            }
        }
    }

    Timer {
        interval: 1800000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    HoverHandler { id: weatherHover }
    ToolTip {
        visible: weatherHover.hovered; delay: 100
        contentItem: Text { text: weatherCapsule.weatherTooltipText; color: Theme.colorNormalText; font.family: "monospace"; font.pixelSize: 13 }
        background: Rectangle { color: Theme.colorBaseBg; border.color: "#003399"; border.width: Theme.capsuleBorderWidth; radius: 6 }
    }
    Text { anchors.centerIn: parent; textFormat: Text.RichText; text: weatherCapsule.weatherDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }
}
