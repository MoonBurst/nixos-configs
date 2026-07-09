import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Import your custom style module relative to this widget's location
import "../../style"

Item {
    id: weatherCapsule

    property var barWindow: null
    property string weatherStr: "..."
    property string weatherTooltipText: "Fetching live weather metrics..."
    property string dataAccumulatorBuffer: ""

    width: 140
    height: parent.height

    // Use your reusable LeftStyle component as the background
    LeftStyle {
        id: bg
        anchors.fill: parent
    }

    // Main weather display fetcher
    Process {
        id: weatherFetcher
        running: true
        // Fetches Celsius and Fahrenheit dynamically and formats them cleanly as "C/F"
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

    Text {
        id: weatherText
        anchors.fill: parent

        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
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

    // ============================================================================
    // THE WEATHER FORECAST POP-UP OVERLAY PANEL WINDOW (DYNAMICALY POSITIONED)
    // ============================================================================
    PanelWindow {
        id: fixedWeatherTooltipWindow
        screen: weatherCapsule.barWindow ? weatherCapsule.barWindow.screen : null
        visible: weatherHoverTracker.hovered && weatherCapsule.barWindow !== null

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-weather-tooltip"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.left: true
        anchors.right: false
        anchors.bottom: false

        implicitWidth: 460
        implicitHeight: 520
        color: "transparent"

        WlrLayershell.margins.top: shell.theme.globalPadding + 55

        WlrLayershell.margins.left: {
            if (!weatherCapsule.barWindow) return 0;

            // DYNAMIC & REACTIVE TRACKING:
            // Recursively reads the .x properties of every container up the tree.
            // This forces QML to automatically re-align the window whenever the parent layout shifts.
            var xOffset = weatherCapsule.x;
            var p = weatherCapsule.parent;
            while (p && p !== weatherCapsule.barWindow.contentItem) {
                xOffset += p.x;
                p = p.parent;
            }

            // Center the tooltip dropdown panel precisely under the weather box width
            var centerPoint = xOffset + (weatherCapsule.width / 2);
            return Math.round(centerPoint - (implicitWidth / 2));
        }

        // Dropdown pop-up container
        Rectangle {
            anchors.fill: parent
            radius: shell.theme.defaultCardRadius
            border.width: shell.theme.globalBorderWidth
            color: shell.theme.base00
            border.color: shell.theme.base05

            Column {
                anchors.fill: parent
                anchors.margins: shell.theme.globalPadding
                spacing: 12

                Text {
                    text: "🌤️ COMPLETE DETAILED FORECAST MATRIX"
                    font.family: shell.theme.fontFamily
                    font.pixelSize: shell.theme.globalFontSize - 2
                    font.bold: true
                    color: shell.theme.base05
                }

                Rectangle { width: parent.width; height: 2; color: shell.theme.base02 }

                ScrollView {
                    width: parent.width
                    height: 440
                    clip: true

                    Text {
                        text: weatherCapsule.weatherTooltipText
                        font.family: shell.theme.fontFamily
                        font.pixelSize: shell.theme.globalFontSize
                        color: shell.theme.base05
                        lineHeight: 1.15
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
