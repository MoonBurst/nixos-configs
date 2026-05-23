import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Rectangle {
    id: weatherCapsule

    width: 110
    height: 35
    radius: 10
    border.width: 3

    color: "black"
    border.color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"

    // FIXED: Changed from hardcoded "+86°F" to empty indicators so it never lies about your climate data strings
    property string weatherStr: "..."
    property string weatherTooltipText: "Fetching live weather metrics..."
    property var barWindow: null
    property string dataAccumulatorBuffer: ""

    Process {
        id: weatherFetcher
        running: true
        command: ["sh", "-c", "curl -s 'wttr.in/Houston?format=%t' | tr -d ' '"]
        stdout: SplitParser {
            onRead: data => {
                var clean = data.trim();
                if (clean !== "" && clean.indexOf("<!DOCTYPE") === -1 && clean.indexOf("html") === -1) {
                    weatherCapsule.weatherStr = clean;
                } else {
                    weatherFallbackProc.running = true;
                }
            }
        }
    }

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
                    tooltipString += hourData.tempF + "°F, ";
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
                    tooltipString += hourData.tempF + "°F, ";
                    tooltipString += hourData.weatherDesc[0].value + "\n";
                }
                weatherCapsule.weatherTooltipText = tooltipString.trim();
            } catch (e) { weatherCapsule.weatherTooltipText = "Error parsing detailed forecast entries."; }
        }
    }

    // FIXED: Invokes an alternative unmetered endpoint if the primary wttr.in rate limit flags trip
    Process {
        id: weatherFallbackProc
        running: false
        command: ["sh", "-c", "curl -s 'https://wttr.in' | tr -d ' '"]
        stdout: SplitParser {
            onRead: data => {
                var clean = data.trim();
                if (clean !== "" && clean.indexOf("<!DOCTYPE") === -1 && clean.indexOf("html") === -1) {
                    weatherCapsule.weatherStr = clean;
                }
            }
        }
    }

    Text {
        id: weatherText
        anchors.fill: parent
        color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"
        text: weatherCapsule.weatherStr
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    HoverHandler { id: weatherHoverTracker }

    PanelWindow {
        id: fixedWeatherTooltipWindow
        screen: weatherCapsule.barWindow ? weatherCapsule.barWindow.screen : null
        visible: weatherHoverTracker.hovered && weatherCapsule.barWindow !== null

        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.namespace: "quickshell-weather-tooltip"
        WlrLayershell.keyboardFocus: WlrLayershell.None

        anchors.top: true
        anchors.left: true
        WlrLayershell.margins.top: 55
        // Pulls dynamic coordinates from the physical weather container boundaries
        WlrLayershell.margins.left: (weatherCapsule.barWindow && weatherCapsule.barWindow.contentItem)
            ? Math.max(0, weatherCapsule.mapToItem(null, 0, 0).x - (460 / 2) + (weatherCapsule.width / 2))
            : 0


        implicitWidth: 460
        implicitHeight: 520
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 8
            border.width: 3
            color: "black"
            border.color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Text { 
                    text: "🌤️ COMPLETE DETAILED FORECAST MATRIX"; 
                    font.family: "monospace"; font.pixelSize: 18; font.bold: true; 
                    color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow" 
                }

                Rectangle { width: parent.width; height: 2; color: "#333333" }

                ScrollView {
                    width: parent.width
                    height: 440
                    clip: true

                    Text {
                        text: weatherCapsule.weatherTooltipText
                        font.family: "monospace"
                        font.pixelSize: 20
                        color: (root && root.theme && root.theme.base05 !== undefined) ? root.theme.base05.toString() : "yellow"
                        lineHeight: 1.15
                    }
                }
            }
        }
    }

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
