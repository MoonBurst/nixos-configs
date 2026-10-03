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
    property string moduleName: "weather"
    property bool pinTooltip: false

    readonly property int liveHeight: (shell && shell.settingsManager)
        ? (shell.settingsManager.getCapsuleHeight("weather") || shell.settingsManager.globalTooltipHeight || 480)
        : 480

    property int tooltipHeight: liveHeight
    property int tooltipCollapsedWidth: 130
    property int tooltipExpandedWidth: 540
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: (shell && shell.theme && shell.theme.slantWidth) ? shell.theme.slantWidth : 12

    property string weatherStr: "..."
    property string weatherTooltipText: "Fetching live 24-hour weather metrics..."

    property string warningLevel: "none"
    property string warningCause: ""
    readonly property color activeWarningColor: "#FF5555"
    readonly property color upcomingWarningColor: "#FFB86C"

    readonly property int maxTooltipLines: Math.max(1, Math.floor((liveHeight - 80) / 24))
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

    // Direct fetcher invoking the 24-hour forecast engine
    Process {
        id: forecastFetcher
        running: true
        command: [
            "sh", "-c",
            'SCR="' + Quickshell.shellDir + '/modules/bar/weather/backend/WeatherEngine.py"; ' +
            'if [ -f "$SCR" ]; then python3 "$SCR"; else lua "' + Quickshell.shellDir + '/modules/bar/weather/backend/WeatherEngine.lua"; fi'
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var res = JSON.parse(data.trim());
                    if (res.status === "ok") {
                        weatherCapsule.weatherStr = res.temp_f + "°F/" + res.temp_c + "°C";
                        weatherCapsule.warningLevel = res.warning_level;
                        weatherCapsule.warningCause = res.warning_cause;
                        weatherCapsule.weatherTooltipText = res.tooltip_text || ("Now: " + res.temp_f + "°F / " + res.temp_c + "°C, " + res.desc);
                    } else {
                        weatherCapsule.weatherTooltipText = res.msg || "Forecast temporarily unavailable.";
                    }
                } catch(e) {}
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

    // Left-click pins/unpins tooltip open and triggers an immediate weather refresh
    TapHandler {
        onTapped: {
            weatherCapsule.pinTooltip = !weatherCapsule.pinTooltip;
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
                            return "🚨 DANGER / OUTAGE RISK: " + weatherCapsule.warningCause.toUpperCase();
                        if (weatherCapsule.warningLevel === "upcoming")
                            return "⚠️ WEATHER WARNING: " + weatherCapsule.warningCause.toUpperCase();
                        return "🌤️ LIVE CONDITIONS & 24H FORECAST";
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
                    delegate: Text {
                        readonly property real lineY: 58 + (index * 24)
                        visible: (lineY + 20) <= weatherTooltip.effectiveHeight
                        text: weatherCapsule.processLinesArray[index]
                        font.family: "monospace"
                        font.pixelSize: ((shell && shell.theme) ? shell.theme.globalFontSize : 14) - 1
                        font.bold: index === 0

                        color: {
                            var line = weatherCapsule.processLinesArray[index];
                            if (line.indexOf("⛈️") !== -1 || line.indexOf("🚨") !== -1)
                                return weatherCapsule.activeWarningColor;
                            if (line.indexOf("⚠️") !== -1 || line.indexOf("🌧️") !== -1 || line.indexOf("❄️") !== -1)
                                return weatherCapsule.upcomingWarningColor;
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
    }

    // Refresh every 15 minutes automatically
    Timer {
        interval: 900000
        running: true
        repeat: true
        onTriggered: {
            forecastFetcher.running = false;
            forecastFetcher.running = true;
        }
    }
}
