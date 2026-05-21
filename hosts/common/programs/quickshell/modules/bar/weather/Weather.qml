import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Controls

Rectangle {
    id: weatherCapsule
    width: 70

    property var barWindow: null

    // Expose the hover state for the parent component
    property alias isHovered: weatherHover.hovered

    // This function is called by the root shell to apply the consistent theme
    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(weatherCapsule, weatherTextElement);
        }
    }

    // --- Properties for Weather Data ---
    property string weatherText: "Loading..."
    property string weatherTooltipText: "Loading forecast..."

    // --- Data Fetching Processes ---
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

    // --- Refresh Timer ---
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

    // --- Hover Handler & Tooltip ---
    HoverHandler { id: weatherHover }

    PopupWindow {
        visible: weatherCapsule.barWindow && weatherHover.hovered
        anchor.window: weatherCapsule.barWindow
        anchor.rect: Qt.rect(weatherCapsule.mapToItem(barWindow.contentItem, 0, 0).x, barWindow.implicitHeight, weatherCapsule.width, 0)
        color: "transparent"

        // Width and height applied to the OS window bounds
        implicitWidth: tooltipText.implicitWidth + 24
        implicitHeight: tooltipText.implicitHeight + 24

        Rectangle {
            anchors.fill: parent
            border.color: root.theme ? root.theme.base05 : "yellow"
            border.width: 2
            radius: 6
            color: root.theme ? root.theme.base00 : "black"

            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: weatherCapsule.weatherTooltipText
                font.family: "monospace"
                font.pixelSize: 20
                color: root.theme ? root.theme.base05 : "yellow"
                lineHeight: 1.2
            }
        }
    }

    // --- Main Text Display ---
    Text {
        id: weatherTextElement
        anchors.centerIn: parent
        text: weatherCapsule.weatherText
        font.pixelSize: 20
        font.bold: true
        elide: Text.ElideRight
        width: parent.width - 20
    }
}
