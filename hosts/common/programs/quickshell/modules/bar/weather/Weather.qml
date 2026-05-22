import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

import Theme

Rectangle {
    id: weatherCapsule

    // Sovereign layout dimensions restore visibility independent of shell.qml micro-management
    width: 100
    height: 35
    radius: 10
    border.width: 3

    // Directly read colors from your immutable compiled Nix Store profile module
    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

    property var barWindow: null

    // Expose the hover state for the parent component
    property alias isHovered: weatherHover.hovered

    // properties for Weather Data
    property string weatherText: "Loading..."
    property string weatherTooltipText: "Loading forecast..."

    // Data Fetching Processes
    Process {
        id: weatherFetcher
        running: true
        command: ["curl", "-s", "wttr.in?format=%t"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    weatherCapsule.weatherText = data.trim();
                }
            }
        }
    }

    Process {
        id: forecastFetcher
        running: true
        command: ["sh", "-c", "curl -s 'wttr.in/?format=j1' | tr -d '\n'"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    try {
                        var forecast = JSON.parse(data);
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
                    } catch (e) {
                        weatherCapsule.weatherTooltipText = "Error parsing forecast.";
                    }
                }
            }
        }
    }

    // Refresh Timer
    Timer {
        interval: 900000 // 15 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            weatherFetcher.running = true;
            forecastFetcher.running = true;
        }
    }

    // Hover Handler & Tooltip
    HoverHandler { id: weatherHover }

    PopupWindow {
        visible: weatherCapsule.barWindow && weatherHover.hovered
        anchor.window: weatherCapsule.barWindow

        // Robust position mapping prevents layout calculation crashes from dynamic shell loaders
        anchor.rect: (weatherCapsule.barWindow && weatherCapsule.barWindow.contentItem) ?
        Qt.rect(weatherCapsule.mapToItem(weatherCapsule.barWindow.contentItem, 0, 0).x, weatherCapsule.barWindow.implicitHeight, weatherCapsule.width, 0) :
        Qt.rect(0, 50, weatherCapsule.width, 0)

        color: "transparent"

        implicitWidth: tooltipText.implicitWidth + 24
        implicitHeight: tooltipText.implicitHeight + 24

        Rectangle {
            anchors.fill: parent
            border.width: 2
            radius: 6

            // Decoupled color hooks mapped to your Nix Store module
            color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
            border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: weatherCapsule.weatherTooltipText
                font.family: "monospace"
                font.pixelSize: 20
                lineHeight: 1.2
                color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"
            }
        }
    }

    // Main Text Display
    Text {
        id: weatherTextElement
        anchors.fill: parent
        anchors.margins: 5
        text: weatherCapsule.weatherText
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "white"
    }
}
