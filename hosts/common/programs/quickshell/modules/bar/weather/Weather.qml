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

    property int tooltipHeight: 420
    property var barWindow: null

    // Slant config
    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: shell.theme.slantWidth

    readonly property real tooltipSlantWidth: (weatherCapsule.height > 0)
    ? (tooltipHeight * (slantWidth / weatherCapsule.height))
    : 15

    // Standardized Tooltip Sizing
    property int tooltipWidth: 380 + (tooltipSlantWidth * 2)
    property string weatherStr: "..."
    property string weatherTooltipText: "Fetching live weather metrics..."
    property string dataAccumulatorBuffer: ""

    // Split the raw forecast text into a clean array of lines
    readonly property var processLinesArray: weatherTooltipText.split("\n").filter(line => line.trim() !== "")

    // Toggle to pin the tooltip open for screenshots (Click the weather capsule to toggle)
    property bool pinTooltip: false

    // Centralized SlantedBox Background
    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: weatherCapsule.slantLeft
        slantRight: weatherCapsule.slantRight
        slantWidth: weatherCapsule.slantWidth
    }

    width: 140
    height: parent.height

    // Main weather display fetcher
    Process {
        id: weatherFetcher
        running: true
        command: ["sh", "-c", "echo \"$(curl -s 'wttr.in/Houston?m&format=%t')/$(curl -s 'wttr.in/Houston?u&format=%t')\" | tr -d ' +'"]
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

    // Detailed JSON forecast fetcher
    Process {
        id: forecastFetcher
        running: true
        command: ["sh", "-c", "curl -s 'wttr.in/Houston?format=j1' | tr -d '\n'"]
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
                var tooltipString = "Today:\n";
                var today = forecast.weather[0];
                for (var i = 0; i < today.hourly.length; i++) {
                    var hourData = today.hourly[i];
                    var time = parseInt(hourData.time, 10) / 100;
                    var ampm = time < 12 ? "AM" : "PM";
                    var displayHour = time % 12;
                    if (displayHour === 0) displayHour = 12;
                    tooltipString += (displayHour < 10 ? " " : "") + displayHour + ":00 " + ampm + ": ";
                    tooltipString += hourData.tempF + "°F / " + hourData.tempC + "°C, ";
                    tooltipString += hourData.weatherDesc[0].value + "\n";
                }

                tooltipString += "\nTomorrow:\n";
                var tomorrow = forecast.weather[1];
                for (var i = 0; i < tomorrow.hourly.length; i++) {
                    var hourData = tomorrow.hourly[i];
                    var time = parseInt(hourData.time, 10) / 100;
                    var ampm = time < 12 ? "AM" : "PM";
                    var displayHour = time % 12;
                    if (displayHour === 0) displayHour = 12;
                    tooltipString += (displayHour < 10 ? " " : "") + displayHour + ":00 " + ampm + ": ";
                    tooltipString += hourData.tempF + "°F / " + hourData.tempC + "°C, ";
                    tooltipString += hourData.weatherDesc[0].value + "\n";
                }
                weatherCapsule.weatherTooltipText = tooltipString.trim();
            } catch (e) { weatherCapsule.weatherTooltipText = "Error parsing detailed forecast entries."; }
        }
    }

    // Unthrottled endpoint fallback
    Process {
        id: weatherFallbackProc
        running: false
        command: ["sh", "-c", "echo \"$(curl -s 'https://wttr.in/?m&format=%t')/$(curl -s 'https://wttr.in/?u&format=%t')\" | tr -d ' +'"]
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

        anchors.leftMargin: weatherCapsule.leftPadding
        anchors.rightMargin: weatherCapsule.rightPadding
        anchors.topMargin: shell.theme.globalPadding
        anchors.bottomMargin: shell.theme.globalPadding

        color: shell.theme.base05
        text: weatherCapsule.weatherStr
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    HoverHandler { id: weatherHoverTracker }

    // Click to toggle/pin the tooltip
    TapHandler {
        onTapped: {
            weatherCapsule.dataAccumulatorBuffer = "";
            weatherFetcher.running = false;
            weatherFetcher.running = true;
            forecastFetcher.running = false;
            forecastFetcher.running = true;
//            weatherCapsule.pinTooltip = !weatherCapsule.pinTooltip;
        }
    }

    Loader {
        active: (weatherHoverTracker.hovered && weatherCapsule.barWindow !== null) || weatherCapsule.pinTooltip

        sourceComponent: Component {
            PanelWindow {
                screen: weatherCapsule.barWindow ? weatherCapsule.barWindow.screen : null
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-weather-tooltip"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                anchors.top: true
                anchors.left: true
                anchors.right: false
                anchors.bottom: false

                implicitWidth: weatherCapsule.tooltipWidth
                implicitHeight: weatherCapsule.tooltipHeight
                color: "transparent"

                WlrLayershell.margins.top: shell.theme.globalPadding + 55

                // Centers dropdown aligned dynamically under the parent container
                WlrLayershell.margins.left: {
                    if (!weatherCapsule.barWindow) return 0;
                    var xOffset = weatherCapsule.x;
                    var p = weatherCapsule.parent;
                    while (p && p !== weatherCapsule.barWindow.contentItem) {
                        xOffset += p.x;
                        p = p.parent;
                    }
                    var centerPoint = xOffset + (weatherCapsule.width / 2);
                    return Math.round(centerPoint - (weatherCapsule.tooltipWidth / 2));
                }

                // Tooltip background using SlantedBox
                SlantedBox {
                    id: tooltipBg
                    anchors.fill: parent
                    slantLeft: weatherCapsule.slantLeft
                    slantRight: weatherCapsule.slantRight
                    slantWidth: weatherCapsule.tooltipSlantWidth


                    readonly property real slantRatio: (height > 0) ? (slantWidth / height) : 0.35
                }

                // Content layout
                Item {
                    anchors.fill: parent

                    // 1. Header
                    Text {
                        text: "🌤️ COMPLETE DETAILED FORECAST MATRIX"
                        font.family: shell.theme.fontFamily
                        font.pixelSize: shell.theme.globalFontSize - 2
                        font.bold: true
                        color: shell.theme.base05

                        y: 30
                        x: (y * tooltipBg.slantRatio) + 24
                    }

                    //Divider Line
                    Rectangle {
                        height: 2
                        color: shell.theme.base02
                        width: 310

                        y: 55
                        x: (y * tooltipBg.slantRatio) + 24
                    }

                    //Monospace Forecast List
                    Repeater {
                        model: weatherCapsule.processLinesArray.length

                        Text {
                            text: weatherCapsule.processLinesArray[index]
                            font.family: "monospace"
                            font.pixelSize: shell.theme.globalFontSize
                            color: shell.theme.base05

                            y: 75 + (index * 18)
                            x: (y * tooltipBg.slantRatio) + 24
                        }
                    }
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
