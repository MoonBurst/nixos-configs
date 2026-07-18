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
    property int tooltipHeight: 620          // Vertical height of the expanded box
    property int tooltipCollapsedWidth: 130  // Sleek, thin width during the downward unroll
    property int tooltipExpandedWidth: 450   // Final horizontal width once fully open
    property int tooltipTopOffset: 0         // Micro-adjust vertical spacing (px)
    property int tooltipRightOffset: 22       // Micro-adjust horizontal alignment (px)
    // =========================================================================

    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: shell.theme.slantWidth

    property string weatherStr: "..."
    property string weatherTooltipText: "Fetching live weather metrics..."
    property string dataAccumulatorBuffer: ""

    // Split the raw forecast text into a clean array of lines
    readonly property var processLinesArray: weatherTooltipText.split("\n").filter(line => line.trim() !== "")

    // Unified Layout Constraints
    width: 140
    Layout.preferredWidth: 140
    height: parent ? parent.height : 40 // Safe guard against null-parent startup evaluations

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: weatherCapsule.slantLeft
        slantRight: weatherCapsule.slantRight
        slantWidth: weatherCapsule.slantWidth
    }

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
        active: weatherHoverTracker.hovered || weatherCapsule.pinTooltip || (tooltipLoader.item && tooltipLoader.item.animHeight > 0)

        sourceComponent: Component {
            SlantedTooltip {
                id: weatherTooltip
                moduleItem: weatherCapsule
                barWindow: weatherCapsule.barWindow
                tooltipActive: weatherHoverTracker.hovered
                pin: weatherCapsule.pinTooltip

                // Instruct the template to align left and expand rightwards
                alignSide: "Left"

                // Maps variables defined at the top of the file
                tooltipHeight: weatherCapsule.tooltipHeight
                collapsedCoreWidth: weatherCapsule.tooltipCollapsedWidth
                expandedCoreWidth: weatherCapsule.tooltipExpandedWidth
                topOffset: weatherCapsule.tooltipTopOffset
                rightOffset: weatherCapsule.tooltipRightOffset

                // pass capsule slants to keep the window parallel
                slantLeft: weatherCapsule.slantLeft
                slantRight: weatherCapsule.slantRight

                // Header
                Text {
                    text: "🌤️ COMPLETE DETAILED FORECAST MATRIX"
                    font.family: shell.theme.fontFamily
                    font.pixelSize: shell.theme.globalFontSize - 2
                    font.bold: true
                    color: shell.theme.base05
                    y: 35
                    x: weatherTooltip.slantX(y) + 24
                }

                //  Divider Line (Staggers left-to-right)
                Rectangle {
                    height: 2
                    color: shell.theme.base02
                    width: 360
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
                        color: shell.theme.base05
                        y: 95 + (index * 28) // Standardized spacing
                        x: weatherTooltip.slantX(y) + 24
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
