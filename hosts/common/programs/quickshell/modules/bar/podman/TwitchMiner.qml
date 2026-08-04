// TwitchMiner.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import "../../style"

Item {
    id: podmanBox

    property var barWindow: null
    property string minerProgress: "Checking..."
    property string activeStreamer: ""
    property string activeStatus: "idle"
    property var tooltipLines: ["Status: Checking...", "Querying Podman services..."]

    // Theme Fallbacks (Identical to BorgCapsule)
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property color themeBase01: (shell && shell.theme && typeof shell.theme.base01 !== "undefined") ? shell.theme.base01 : "#1a1a1a"
    readonly property color themeBase02: (shell && shell.theme && typeof shell.theme.base02 !== "undefined") ? shell.theme.base02 : "gray"
    readonly property color themeBase05: (shell && shell.theme && typeof shell.theme.base05 !== "undefined") ? shell.theme.base05 : "yellow"

    // =========================================================================
    // EDITABLE TOOLTIP & LAYOUT CONFIGURATION
    // =========================================================================
    property int tooltipHeight: 260
    property int tooltipCollapsedWidth: 105
    property int tooltipExpandedWidth: 380
    property int tooltipTopOffset: -3
    property int tooltipRightOffset: 20

    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: podmanBox.themeSlantWidth

    width: 140
    height: parent ? parent.height : 40

    // Slanted Box Background
    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: podmanBox.slantLeft
        slantRight: podmanBox.slantRight
        slantWidth: podmanBox.slantWidth
    }

    // Auto-poll timer every 15 seconds
    Timer {
        interval: 15000; running: true; repeat: true
        onTriggered: {
            if (podmanPoller.running) podmanPoller.running = false;
            podmanPoller.running = true;
        }
    }

    // Process to query Podman & Twitch miner status
    Process {
        id: podmanPoller
        command: [
            "bash", "-c",
            "CONTAINER_MAIN='twitch-miner'; CONTAINER_BERRY='twitchminer-berrydrop'; " +
            "MAIN_UP=$(sudo -n podman ps --format '{{.Names}}' 2>/dev/null | grep -q \"$CONTAINER_MAIN\" && echo 1 || echo 0); " +
            "BERRY_UP=$(sudo -n podman ps --format '{{.Names}}' 2>/dev/null | grep -q \"$CONTAINER_BERRY\" && echo 1 || echo 0); " +
            "if [ \"$MAIN_UP\" -eq 0 ] && [ \"$BERRY_UP\" -eq 0 ]; then " +
            "  echo '{\"status\": \"stopped\", \"main\": false, \"berry\": false, \"streamer\": \"\", \"msg\": \"Stopped\"}'; exit 0; " +
            "fi; " +
            "LOGS=$(sudo -n podman logs --since 3m \"$CONTAINER_MAIN\" 2>&1); " +
            "if echo \"$LOGS\" | grep -iqE \"401|403|rate limit|integrity|unauthorized|failed\"; then " +
            "  echo '{\"status\": \"rate_limited\", \"main\": true, \"berry\": false, \"streamer\": \"\", \"msg\": \"Limited!\"}'; " +
            "  sudo -n systemctl restart podman-twitch-miner.service 2>/dev/null; exit 0; " +
            "fi; " +
            "WATCHING=$(echo \"$LOGS\" | grep -i \"Watching:\" | tail -n 1 | awk '{print $NF}'); " +
            "echo '{\"status\": \"ok\", \"main\": '\"$MAIN_UP\"', \"berry\": '\"$BERRY_UP\"', \"streamer\": \"'\"$WATCHING\"'\", \"msg\": \"'\"$WATCHING\"'\"}'"
        ]

        stdout: SplitParser {
            onRead: data => {
                const rawLine = data.trim()
                if (!rawLine.length) return;

                try {
                    const statusObj = JSON.parse(rawLine)
                    let lines = []

                    podmanBox.activeStatus = statusObj.status || "idle"
                    podmanBox.activeStreamer = statusObj.streamer || ""

                    if (statusObj.status === "stopped") {
                        podmanBox.minerProgress = "Stopped"
                        lines.push("Status: Containers Stopped")
                        lines.push("Main Miner: Offline")
                        lines.push("Berrydrop: Offline")
                        lines.push("Action: Click to retry start")
                    } else if (statusObj.status === "rate_limited") {
                        podmanBox.minerProgress = "Limited!"
                        lines.push("Status: Twitch Rate Limited")
                        lines.push("Action: Auto-restarting container...")
                    } else if (statusObj.status === "ok") {
                        if (statusObj.streamer && statusObj.streamer.length > 0) {
                            podmanBox.minerProgress = statusObj.streamer
                            lines.push("Status: Active Mining")
                            lines.push("Watching: " + statusObj.streamer)
                        } else {
                            podmanBox.minerProgress = "Active"
                            lines.push("Status: Mining Active")
                        }
                        lines.push("Main Miner: Running (Port 5800)")
                        lines.push("Berrydrop: " + (statusObj.berry ? "Running" : "Standby"))
                        lines.push("Controls: Right-Click to swap accounts")
                    }

                    podmanBox.tooltipLines = lines
                } catch (e) {
                    podmanBox.minerProgress = "Error"
                    podmanBox.tooltipLines = ["Status: Parsing Error", "Error: " + e.message]
                }
            }
        }
    }

    // Swap Process (Right-click action)
    Process {
        id: swapProcess
        running: false
        command: [
            "bash", "-c",
            "sudo -n systemctl stop podman-twitch-miner.service && sudo -n systemctl start podman-twitchminer-berrydrop.service"
        ]
        onExited: {
            podmanPoller.running = true;
        }
    }

    // Main Capsule Label Text
    Text {
        id: podmanText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: themePadding
        anchors.bottomMargin: themePadding

        text: {
            const fontColor = themeBase05.toString();
            if (podmanBox.minerProgress === "Stopped" || podmanBox.minerProgress === "Error") {
                return "<font color='" + fontColor + "'>Miner:</font> <font color='" + fontColor + "'>" + podmanBox.minerProgress + "</font>";
            } else {
                return "<font color='" + fontColor + "'>Watching:</font> <font color='" + fontColor + "'>" + podmanBox.minerProgress + "</font>";
            }
        }

        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        textFormat: Text.RichText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // Hover Handler
    HoverHandler {
        id: podmanHoverTracker
        onHoveredChanged: {
            if (hovered && !podmanPoller.running) {
                podmanPoller.running = false;
                podmanPoller.running = true;
            }
        }
    }

    // Mouse Area for Click Controls
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                podmanPoller.running = false;
                podmanPoller.running = true;
            } else if (mouse.button === Qt.RightButton) {
                swapProcess.running = true;
            }
        }
    }

    // Slanted Tooltip Window
    SlantedTooltip {
        id: podmanTooltip
        moduleItem: podmanBox
        barWindow: podmanBox.barWindow
        tooltipActive: podmanHoverTracker.hovered
        pin: false

        alignSide: "Left"

        tooltipHeight: podmanBox.tooltipHeight
        collapsedCoreWidth: podmanBox.tooltipCollapsedWidth
        expandedCoreWidth: podmanBox.tooltipExpandedWidth
        topOffset: podmanBox.tooltipTopOffset
        rightOffset: podmanBox.tooltipRightOffset

        slantLeft: podmanBox.slantLeft
        slantRight: podmanBox.slantRight

        Text {
            text: "TWITCH MINER STATUS:"
            font.family: themeFontFamily
            font.pixelSize: themeFontSize - 1
            font.bold: true
            color: themeBase05
            y: 35
            x: podmanTooltip.slantX(y) + 24
        }

        Rectangle {
            height: 2
            color: themeBase02
            width: 310
            y: 65
            x: podmanTooltip.slantX(y) + 24
        }

        Repeater {
            model: podmanBox.tooltipLines.length
            Text {
                text: podmanBox.tooltipLines[index]
                font.family: "monospace"
                font.pixelSize: themeFontSize - 1
                color: themeBase05
                y: 85 + (index * 28)
                x: podmanTooltip.slantX(y) + 24
            }
        }
    }
}
