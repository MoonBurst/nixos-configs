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
    property var barWindow: null
    property bool pinTooltip: false

    // =========================================================================
    //  EDITABLE TOOLTIP CONFIGURATION
    // =========================================================================
    property int tooltipHeight: 450          // Vertical height of the expanded box
    property int tooltipCollapsedWidth: 130  // Sleek, thin width during the downward unroll
    property int tooltipExpandedWidth: 520   // Expanded width to prevent right-side overflow
    property int tooltipTopOffset: -2         // Micro-adjust vertical spacing (px)
    property int tooltipRightOffset: 21       // Micro-adjust horizontal alignment (px)
    // =========================================================================

    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: shell.theme.slantWidth

    property string weatherStr: "..."
    property string weatherTooltipText: "Fetching live weather metrics..."
    property string dataAccumulatorBuffer: ""

    // Severe Weather Warning States: "none", "active" (Red), "upcoming" (Orange)
    property string warningLevel: "none"
    readonly property color activeWarningColor: "#FF5555"   // Red
    readonly property color upcomingWarningColor: "#FFB86C" // Orange

    // Dynamic line limit based on container height
    readonly property int maxTooltipLines: Math.max(1, Math.floor((tooltipHeight - 120) / 25))

    // Split raw forecast text into clean array & strictly limit line count to prevent bottom overflow
    readonly property var processLinesArray: {
        var lines = weatherTooltipText.split("\n").filter(line => line.trim() !== "");
        return lines.slice(0, maxTooltipLines);
    }

    // Expanded width to accommodate emojis and dual temp readouts comfortably
    width: 180
    Layout.preferredWidth: 180
    height: parent ? parent.height : 40 // Safe guard against null-parent startup evaluations

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: weatherCapsule.slantLeft
        slantRight: weatherCapsule.slantRight
        slantWidth: weatherCapsule.slantWidth
    }

    // Main weather display fetcher (Standardized to Fahrenheit / Celsius: ?u / ?m)
    Process {
        id: weatherFetcher
        running: true
        command: ["sh", "-c", "echo \"$(curl -s 'wttr.in/?u&format=%t')/$(curl -s 'wttr.in/?m&format=%t')\" | tr -d ' +'"]
        stdout: SplitParser {
            onRead: data => {
                var clean = data.trim();
                if (clean !== "" && clean.indexOf("<!DOCTYPE") === -1 && clean.indexOf("html") === -1 && clean !== "/") {
                    weatherCapsule.weatherStr = clean;
                } else {
                    weatherFallbackProc.running = true;
                }
            }
        }
    }

    // Detailed JSON forecast fetcher (Dynamic IP Geolocation)
    Process {
        id: forecastFetcher
        running: true
        command: ["sh", "-c", "curl -s 'wttr.in/?format=j1' | tr -d '\n'"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { weatherCapsule.dataAccumulatorBuffer += data; }
        }
        onExited: {
            var rawData = weatherCapsule.dataAccumulatorBuffer.trim();
            if (rawData === "" || rawData.charAt(0) !== '{') {
                weatherCapsule.weatherTooltipText = "Detailed forecast temporarily rate-limited.\nMain readout falls back to unthrottled endpoints.";
                return;
            }
            try {
                var forecast = JSON.parse(rawData);
                var tooltipString = "";

                var activeWarn = false;
                var upcomingWarn = false;

                // Helper to detect severe weather conditions
                var isSevere = function(desc, code) {
                    if (!desc) desc = "";
                    var lower = desc.toLowerCase();
                    var severeKeywords = [
                        "thunderstorm", "thundery", "blizzard", "tornado", "hurricane",
                        "gale", "heavy freezing", "torrential", "squall", "warning",
                        "advisory", "ice storm", "hail"
                    ];
                    for (var k = 0; k < severeKeywords.length; k++) {
                        if (lower.indexOf(severeKeywords[k]) !== -1) return true;
                    }
                    var severeCodes = [230, 386, 389, 392, 395]; // Severe Weather WMO Codes
                    if (code && severeCodes.indexOf(parseInt(code, 10)) !== -1) return true;
                    return false;
                };

                // Helper to format hour integer to " 3:00 PM"
                var formatHourStr = function(timeNum) {
                    var ampm = timeNum < 12 ? "AM" : "PM";
                    var displayHour = timeNum % 12;
                    if (displayHour === 0) displayHour = 12;
                    return (displayHour < 10 ? " " : "") + displayHour + ":00 " + ampm;
                };

                // 1. Current Live Weather at top
                if (forecast.current_condition && forecast.current_condition.length > 0) {
                    var curr = forecast.current_condition[0];
                    var currDesc = (curr.weatherDesc && curr.weatherDesc[0]) ? curr.weatherDesc[0].value : "";
                    if (isSevere(currDesc, curr.weatherCode)) {
                        activeWarn = true;
                    }
                    tooltipString += "Current\n";
                    tooltipString += "  Now: " + curr.temp_F + "°F / " + curr.temp_C + "°C, " + currDesc + "\n\n";
                }

                var currentHour = new Date().getHours();

                // 2. Today's Strictly Future Hours
                var today = forecast.weather[0];
                var todayLines = [];
                for (var i = 0; i < today.hourly.length; i++) {
                    var hourData = today.hourly[i];
                    var timeNum = parseInt(hourData.time, 10) / 100;

                    // Only show hours starting at or after the current system hour
                    if (timeNum >= currentHour) {
                        var desc = (hourData.weatherDesc && hourData.weatherDesc[0]) ? hourData.weatherDesc[0].value : "";
                        var code = hourData.weatherCode;

                        if (isSevere(desc, code)) {
                            if (timeNum <= currentHour + 3) {
                                upcomingWarn = true;
                            }
                        }

                        todayLines.push("  " + formatHourStr(timeNum) + ": " + hourData.tempF + "°F / " + hourData.tempC + "°C, " + desc);
                    }
                }

                if (todayLines.length > 0) {
                    tooltipString += "Today\n" + todayLines.join("\n") + "\n\n";
                }

                // 3. Tomorrow's Forecast
                var tomorrow = forecast.weather[1];
                var tomorrowLines = [];
                for (var i = 0; i < tomorrow.hourly.length; i++) {
                    var hourData = tomorrow.hourly[i];
                    var timeNum = parseInt(hourData.time, 10) / 100;
                    var desc = (hourData.weatherDesc && hourData.weatherDesc[0]) ? hourData.weatherDesc[0].value : "";
                    tomorrowLines.push("  " + formatHourStr(timeNum) + ": " + hourData.tempF + "°F / " + hourData.tempC + "°C, " + desc);
                }

                if (tomorrowLines.length > 0) {
                    tooltipString += "Tomorrow\n" + tomorrowLines.join("\n");
                }

                // Set overall warning level state
                weatherCapsule.warningLevel = activeWarn ? "active" : (upcomingWarn ? "upcoming" : "none");
                weatherCapsule.weatherTooltipText = tooltipString.trim();
            } catch (e) {
                weatherCapsule.weatherTooltipText = "Error parsing detailed forecast entries.";
            }
        }
    }

    // Unthrottled endpoint fallback (Standardized to Fahrenheit / Celsius)
    Process {
        id: weatherFallbackProc
        running: false
        command: ["sh", "-c", "echo \"$(curl -s 'https://wttr.in/?u&format=%t')/$(curl -s 'https://wttr.in/?m&format=%t')\" | tr -d ' +'"]
        stdout: SplitParser {
            onRead: data => {
                var clean = data.trim();
                if (clean !== "" && clean.indexOf("<!DOCTYPE") === -1 && clean.indexOf("html") === -1 && clean !== "/") {
                    weatherCapsule.weatherStr = clean;
                }
            }
        }
    }

    // Main weather display text
    Text {
        id: weatherText
        anchors.fill: parent

        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: shell.theme.globalPadding
        anchors.bottomMargin: shell.theme.globalPadding

        color: {
            if (weatherCapsule.warningLevel === "active") return weatherCapsule.activeWarningColor;
            if (weatherCapsule.warningLevel === "upcoming") return weatherCapsule.upcomingWarningColor;
            return shell.theme.base05;
        }

        text: {
            var iconPrefix = "";
            if (weatherCapsule.warningLevel === "active") iconPrefix = "🚨 ";
            else if (weatherCapsule.warningLevel === "upcoming") iconPrefix = "⚠️ ";
            return iconPrefix + weatherCapsule.weatherStr;
        }

        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    HoverHandler { id: weatherHoverTracker }

    TapHandler {
        onTapped: {
            weatherCapsule.dataAccumulatorBuffer = "";
            weatherFetcher.running = false;
            weatherFetcher.running = true;
            forecastFetcher.running = false;
            forecastFetcher.running = true;
        }
    }

    // Panel Window Pop-up Renderer
    Loader {
        id: tooltipLoader
        property bool keepingActive: false
        property bool animTrigger: false
        active: weatherHoverTracker.hovered || weatherCapsule.pinTooltip || keepingActive

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

                // Dynamic Warning Header
                Text {
                    text: {
                        if (weatherCapsule.warningLevel === "active") return "🚨 ACTIVE WEATHER WARNING IN EFFECT";
                        if (weatherCapsule.warningLevel === "upcoming") return "⚠️ WEATHER WARNING IN NEXT 3 HOURS";
                        return "🌤️ COMPLETE DETAILED FORECAST MATRIX";
                    }
                    font.family: shell.theme.fontFamily
                    font.pixelSize: shell.theme.globalFontSize
                    font.bold: true
                    color: {
                        if (weatherCapsule.warningLevel === "active") return weatherCapsule.activeWarningColor;
                        if (weatherCapsule.warningLevel === "upcoming") return weatherCapsule.upcomingWarningColor;
                        return shell.theme.base05;
                    }
                    y: 35
                    x: weatherTooltip.slantX(y) + 24
                }

                // Divider Line
                Rectangle {
                    height: 2
                    color: {
                        if (weatherCapsule.warningLevel === "active") return weatherCapsule.activeWarningColor;
                        if (weatherCapsule.warningLevel === "upcoming") return weatherCapsule.upcomingWarningColor;
                        return shell.theme.base02;
                    }
                    width: weatherCapsule.tooltipExpandedWidth - 48
                    y: 65
                    x: weatherTooltip.slantX(y) + 24
                }

                // Monospace Forecast List
                Repeater {
                    model: weatherCapsule.processLinesArray.length
                    Text {
                        text: weatherCapsule.processLinesArray[index]
                        font.family: "monospace"
                        font.pixelSize: shell.theme.globalFontSize - 1
                        font.bold: weatherCapsule.processLinesArray[index].indexOf(":") === -1

                        color: {
                            var line = weatherCapsule.processLinesArray[index];
                            if (line.indexOf(":") === -1) return shell.theme.base0A; // Category Header

                            var lower = line.toLowerCase();
                            var severeKeywords = [
                                "thunderstorm", "thundery", "blizzard", "tornado", "hurricane",
                                "gale", "heavy freezing", "torrential", "squall", "warning",
                                "advisory", "ice storm", "hail"
                            ];

                            for (var k = 0; k < severeKeywords.length; k++) {
                                if (lower.indexOf(severeKeywords[k]) !== -1) {
                                    if (line.indexOf("Now:") !== -1 || weatherCapsule.warningLevel === "active") {
                                        return weatherCapsule.activeWarningColor;
                                    } else {
                                        return weatherCapsule.upcomingWarningColor;
                                    }
                                }
                            }
                            return shell.theme.base05;
                        }

                        y: 85 + (index * 25)
                        x: weatherTooltip.slantX(y) + 24
                        width: weatherCapsule.tooltipExpandedWidth - 48
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

    // Refresh weather metrics every 30 minutes
    Timer {
        interval: 1800000; running: true; repeat: true
        onTriggered: {
            weatherCapsule.dataAccumulatorBuffer = "";
            weatherFetcher.running = false;
            weatherFetcher.running = true;
            forecastFetcher.running = false;
            forecastFetcher.running = true;
        }
    }
}
