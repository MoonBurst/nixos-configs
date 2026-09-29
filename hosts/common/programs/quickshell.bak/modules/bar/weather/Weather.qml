// WeatherCapsule.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

Item {
    id: weatherCapsule

    Timer {
        id: bootRetryTimer
        interval: 15000
        repeat: false
        running: false
        onTriggered: {
            if (weatherCapsule.weatherStr === "..." || weatherCapsule.weatherTooltipText.indexOf("temporarily") !== -1) {
                weatherCapsule.dataAccumulatorBuffer = "";
                forecastFetcher.running = false;
                forecastFetcher.running = true;
            }
        }
    }

    property var barWindow: null
    property string moduleName: "weather"
    property bool pinTooltip: false

    readonly property int liveHeight: (shell && shell.settingsManager)
        ? (shell.settingsManager.getCapsuleHeight("weather") || shell.settingsManager.globalTooltipHeight || 480)
        : 480

    property int tooltipHeight: liveHeight
    property int tooltipCollapsedWidth: 130
    property int tooltipExpandedWidth: 620
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: (shell && shell.theme && shell.theme.slantWidth) ? shell.theme.slantWidth : 12

    property string weatherStr: "..."
    property string weatherTooltipText: "Fetching live weather metrics..."
    property string dataAccumulatorBuffer: ""

    property string warningLevel: "none"
    property string warningCause: ""
    readonly property color activeWarningColor: "#FF5555"
    readonly property color upcomingWarningColor: "#FFB86C"

    readonly property int maxTooltipLines: Math.max(1, Math.floor((liveHeight - 90) / 25))
    readonly property var processLinesArray: {
        var lines = weatherTooltipText.split("\n").filter(line => line.trim() !== "");
        return lines.slice(0, maxTooltipLines);
    }

    implicitWidth: weatherText.implicitWidth + bg.leftPadding + bg.rightPadding + 20
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: weatherCapsule.slantLeft
        slantRight: weatherCapsule.slantRight
        slantWidth: weatherCapsule.slantWidth
    }

    Process {
        id: forecastFetcher
        running: true
        command: [
            "sh", "-c",
            "curl -s -A 'Quickshell-Weather/1.0' --connect-timeout 5 --max-time 10 'https://wttr.in/?format=j1' | tr -d '\\n'"
        ]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { weatherCapsule.dataAccumulatorBuffer += data; }
        }
        onExited: {
            if (weatherCapsule.weatherStr === "...") bootRetryTimer.start();
            var rawData = weatherCapsule.dataAccumulatorBuffer.trim();
            weatherCapsule.dataAccumulatorBuffer = "";

            if (rawData === "" || rawData.charAt(0) !== '{') {
                weatherCapsule.weatherTooltipText = "Detailed forecast temporarily rate-limited.\nRetrying automatically on next interval.";
                return;
            }

            try {
                var forecast = JSON.parse(rawData);
                var tooltipString = "";
                var activeWarn = false;
                var upcomingWarn = false;
                var detectedCause = "";

                var isOutageRisk = function(desc, code) {
                    if (!desc) desc = "";
                    var lower = desc.toLowerCase();
                    var dangerousKeywords = [
                        "severe thunderstorm", "tornado", "hurricane", "typhoon",
                        "high wind", "gale", "blizzard", "ice storm", "freezing rain",
                        "squall", "derecho", "tropical storm", "damaging wind", "heavy thunderstorm"
                    ];
                    for (var k = 0; k < dangerousKeywords.length; k++) {
                        if (lower.indexOf(dangerousKeywords[k]) !== -1) return true;
                    }
                    var dangerousCodes = [389, 395, 314];
                    if (code && dangerousCodes.indexOf(parseInt(code, 10)) !== -1) return true;
                    return false;
                };

                var formatHourStr = function(timeNum) {
                    var ampm = timeNum < 12 ? "AM" : "PM";
                    var displayHour = timeNum % 12;
                    if (displayHour === 0) displayHour = 12;
                    return (displayHour < 10 ? " " : "") + displayHour + ":00 " + ampm;
                };

                if (forecast.current_condition && forecast.current_condition.length > 0) {
                    var curr = forecast.current_condition[0];
                    var currDesc = (curr.weatherDesc && curr.weatherDesc[0]) ? curr.weatherDesc[0].value : "";
                    weatherCapsule.weatherStr = curr.temp_F + "°F/" + curr.temp_C + "°C";

                    if (isOutageRisk(currDesc, curr.weatherCode)) {
                        activeWarn = true;
                        detectedCause = currDesc;
                    }
                    tooltipString += "Current\n";
                    tooltipString += "  Now: " + curr.temp_F + "°F / " + curr.temp_C + "°C, " + currDesc + "\n\n";
                }

                var currentHour = new Date().getHours();
                var today = forecast.weather[0];
                var todayLines = [];
                for (var i = 0; i < today.hourly.length; i++) {
                    var hourData = today.hourly[i];
                    var timeNum = parseInt(hourData.time, 10) / 100;
                    if (timeNum >= currentHour) {
                        var desc = (hourData.weatherDesc && hourData.weatherDesc[0]) ? hourData.weatherDesc[0].value : "";
                        var code = hourData.weatherCode;
                        if (isOutageRisk(desc, code) && timeNum <= currentHour + 3) {
                            upcomingWarn = true;
                            if (!detectedCause) detectedCause = desc;
                        }
                        todayLines.push("  " + formatHourStr(timeNum) + ": " + hourData.tempF + "°F / " + hourData.tempC + "°C, " + desc);
                    }
                }
                if (todayLines.length > 0) tooltipString += "Today\n" + todayLines.join("\n") + "\n\n";

                var tomorrow = forecast.weather[1];
                var tomorrowLines = [];
                for (var j = 0; j < tomorrow.hourly.length; j++) {
                    var tmHourData = tomorrow.hourly[j];
                    var tmTimeNum = parseInt(tmHourData.time, 10) / 100;
                    var tmDesc = (tmHourData.weatherDesc && tmHourData.weatherDesc[0]) ? tmHourData.weatherDesc[0].value : "";
                    tomorrowLines.push("  " + formatHourStr(tmTimeNum) + ": " + tmHourData.tempF + "°F / " + tmHourData.tempC + "°C, " + tmDesc);
                }
                if (tomorrowLines.length > 0) tooltipString += "Tomorrow\n" + tomorrowLines.join("\n");

                weatherCapsule.warningLevel = activeWarn ? "active" : (upcomingWarn ? "upcoming" : "none");
                weatherCapsule.warningCause = detectedCause;
                weatherCapsule.weatherTooltipText = tooltipString.trim();

                if (weatherCapsule.warningLevel === "active") {
                    Quickshell.execDetached(["sh", "-c", "echo 1 > /dev/shm/weather-storm-active.txt"]);
                } else {
                    Quickshell.execDetached(["sh", "-c", "rm -f /dev/shm/weather-storm-active.txt"]);
                }
            } catch (e) {
                weatherCapsule.weatherTooltipText = "Error parsing detailed forecast entries.";
            }
        }
    }

    Text {
        id: weatherText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 4
        anchors.rightMargin: bg.rightPadding + 4
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        color: {
            if (weatherCapsule.warningLevel === "active") return weatherCapsule.activeWarningColor;
            if (weatherCapsule.warningLevel === "upcoming") return weatherCapsule.upcomingWarningColor;
            return (shell && shell.theme) ? shell.theme.base05 : "yellow";
        }
        text: {
            var iconPrefix = "";
            if (weatherCapsule.warningLevel === "active") iconPrefix = "🚨 ";
            else if (weatherCapsule.warningLevel === "upcoming") iconPrefix = "⚠️ ";
            return iconPrefix + weatherCapsule.weatherStr;
        }
        font.family: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"
        font.pixelSize: (shell && shell.theme) ? shell.theme.globalFontSize : 14
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        clip: true
    }

    HoverHandler { id: weatherHoverTracker }

    TapHandler {
        onTapped: {
            weatherCapsule.dataAccumulatorBuffer = "";
            forecastFetcher.running = false;
            forecastFetcher.running = true;
        }
    }

    Loader {
        id: tooltipLoader
        property bool keepingActive: false
        property bool animTrigger: false
        active: weatherHoverTracker.hovered || weatherCapsule.pinTooltip || keepingActive || (shell && shell.settingsManager && shell.settingsManager.previewCapsule === "weather")

        onActiveChanged: {
            if (active) {
                animTrigger = false;
                Qt.callLater(() => { animTrigger = true; });
            } else {
                animTrigger = false;
            }
        }

        sourceComponent: Component {
            SlantedTooltip {
                id: weatherTooltip
                moduleItem: weatherCapsule
                barWindow: weatherCapsule.barWindow
                tooltipActive: tooltipLoader.animTrigger && (weatherHoverTracker.hovered || weatherCapsule.pinTooltip)
                pin: weatherCapsule.pinTooltip
                alignSide: "Left"

                tooltipHeight: weatherCapsule.tooltipHeight
                collapsedCoreWidth: weatherCapsule.tooltipCollapsedWidth
                expandedCoreWidth: weatherCapsule.tooltipExpandedWidth
                topOffset: weatherCapsule.tooltipTopOffset
                rightOffset: weatherCapsule.tooltipRightOffset
                slantLeft: weatherCapsule.slantLeft
                slantRight: weatherCapsule.slantRight

                Text {
                    text: {
                        if (weatherCapsule.warningLevel === "active")
                            return "🚨 OUTAGE RISK: " + weatherCapsule.warningCause.toUpperCase();
                        if (weatherCapsule.warningLevel === "upcoming")
                            return "⚠️ OUTAGE RISK IN NEXT 3 HOURS: " + weatherCapsule.warningCause.toUpperCase();
                        return "🌤️ COMPLETE DETAILED FORECAST MATRIX";
                    }
                    font.family: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"
                    font.pixelSize: ((shell && shell.theme) ? shell.theme.globalFontSize : 14) - 1
                    font.bold: true
                    color: {
                        if (weatherCapsule.warningLevel === "active") return weatherCapsule.activeWarningColor;
                        if (weatherCapsule.warningLevel === "upcoming") return weatherCapsule.upcomingWarningColor;
                        return (shell && shell.theme) ? shell.theme.base05 : "yellow";
                    }
                    y: 25
                    x: weatherTooltip.slantX(y) + 24
                }

                Repeater {
                    model: weatherCapsule.processLinesArray.length
                    Text {
                        readonly property real lineY: 60 + (index * 25)
                        visible: (lineY + 22) <= weatherTooltip.effectiveHeight
                        text: weatherCapsule.processLinesArray[index]
                        font.family: "monospace"
                        font.pixelSize: ((shell && shell.theme) ? shell.theme.globalFontSize : 14) - 1
                        font.bold: weatherCapsule.processLinesArray[index].indexOf(":") === -1
                        color: {
                            var line = weatherCapsule.processLinesArray[index];
                            if (line.indexOf(":") === -1) return (shell && shell.theme) ? shell.theme.base0A : "yellow";
                            return (shell && shell.theme) ? shell.theme.base05 : "yellow";
                        }
                        y: lineY
                        x: weatherTooltip.slantX(lineY) + 24
                        width: weatherTooltip.effectiveCoreWidth - 48
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Connections {
            target: tooltipLoader.item
            ignoreUnknownSignals: true
            function onAnimHeightChanged() {
                if (tooltipLoader.item) {
                    tooltipLoader.keepingActive = (tooltipLoader.item.animHeight > 0);
                } else {
                    tooltipLoader.keepingActive = false;
                }
            }
        }
    }

    Timer {
        interval: 1800000; running: true; repeat: true
        onTriggered: {
            weatherCapsule.dataAccumulatorBuffer = "";
            forecastFetcher.running = false;
            forecastFetcher.running = true;
        }
    }
}
