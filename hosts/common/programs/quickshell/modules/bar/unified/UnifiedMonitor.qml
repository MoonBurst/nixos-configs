// UnifiedMonitor.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import "../../style"

Item {
    id: unifiedBox

    property var barWindow: null

    // State Variables
    property string activeLabel: "Sys OK"
    property string activeColor: themeBase05
    property bool needsAttention: false

    // Borg State
    property string borgProgress: "Idle"
    property int borgPercent: 0
    property string borgStatus: "idle"

    // Twitch State (Monitors BOTH Miners + Claimed Drops)
    property bool mainRunning: false
    property bool berryRunning: false
    property string mainWatching: ""
    property string berryWatching: ""
    property string mainClaim: ""
    property string berryClaim: ""
    property bool mainError: false
    property bool berryError: false

    // Tooltip Lines
    property var tooltipLines: ["✔ ALL SYSTEMS NOMINAL"]

    // Theme Fallbacks
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property color themeBase01: (shell && shell.theme && typeof shell.theme.base01 !== "undefined") ? shell.theme.base01 : "#1a1a1a"
    readonly property color themeBase02: (shell && shell.theme && typeof shell.theme.base02 !== "undefined") ? shell.theme.base02 : "gray"
    readonly property color themeBase05: (shell && shell.theme && typeof shell.theme.base05 !== "undefined") ? shell.theme.base05 : "yellow"

    // Layout configuration
    property int tooltipHeight: 340
    property int tooltipCollapsedWidth: 105
    property int tooltipExpandedWidth: 600
    property int tooltipTopOffset: -3
    property int tooltipRightOffset: 20

    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: unifiedBox.themeSlantWidth

    width: 130
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: unifiedBox.slantLeft
        slantRight: unifiedBox.slantRight
        slantWidth: unifiedBox.slantWidth
    }

    // Auto-poll every 10 seconds
    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: {
            borgPoller.running = true;
            podmanPoller.running = true;
        }
    }

    // 1. Borg Status Poller
    Process {
        id: borgPoller
        command: ["cat", "/dev/shm/borg-offsite-status.json"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const statusObj = JSON.parse(data.trim())
                    unifiedBox.borgStatus = statusObj.status || "idle"
                    unifiedBox.borgPercent = statusObj.percent || 0
                    if (statusObj.status === "running") unifiedBox.borgProgress = statusObj.percent + "%";
                    else if (statusObj.status === "syncing") unifiedBox.borgProgress = "Sync " + statusObj.percent + "%";
                    else unifiedBox.borgProgress = "Idle";
                } catch (e) {
                    unifiedBox.borgStatus = "idle";
                }
                unifiedBox.calculatePriorityState();
            }
        }
    }

    // 2. Podman Status Poller (Detects Active Watching vs Finished/Idle State)
    Process {
        id: podmanPoller
        command: [
            "bash", "-c",
            "CONTAINER_MAIN='twitch-miner'; CONTAINER_BERRY='twitchminer-berrydrop'; " +
            "MAIN_RUNNING=$(sudo -n podman ps --format '{{.Names}}' 2>/dev/null | grep -q \"$CONTAINER_MAIN\" && echo 1 || echo 0); " +
            "BERRY_RUNNING=$(sudo -n podman ps --format '{{.Names}}' 2>/dev/null | grep -q \"$CONTAINER_BERRY\" && echo 1 || echo 0); " +
            "MAIN_LOGS=$(sudo -n podman logs --tail 50 \"$CONTAINER_MAIN\" 2>&1 || true); " +
            "BERRY_LOGS=$(sudo -n podman logs --tail 50 \"$CONTAINER_BERRY\" 2>&1 || true); " +
            "MAIN_FINISHED=$(echo \"$MAIN_LOGS\" | tail -n 15 | grep -iqE \"Exiting|All drops claimed|No active campaigns|No channels available|Idle\" && echo 1 || echo 0); " +
            "BERRY_FINISHED=$(echo \"$BERRY_LOGS\" | tail -n 15 | grep -iqE \"Exiting|All drops claimed|No active campaigns|No channels available|Idle\" && echo 1 || echo 0); " +
            "MAIN_WATCHING=$(echo \"$MAIN_LOGS\" | grep -i \"Watching:\" | tail -n 1 | awk '{print $NF}'); " +
            "BERRY_WATCHING=$(echo \"$BERRY_LOGS\" | grep -i \"Watching:\" | tail -n 1 | awk '{print $NF}'); " +
            "if [ \"$MAIN_FINISHED\" -eq 1 ]; then MAIN_WATCHING=\"\"; fi; " +
            "if [ \"$BERRY_FINISHED\" -eq 1 ]; then BERRY_WATCHING=\"\"; fi; " +
            "MAIN_CLAIM=$(echo \"$MAIN_LOGS\" | grep -i \"Claimed drop:\" | tail -n 1 | sed 's/.*Claimed drop: //' | cut -c 1-35); " +
            "BERRY_CLAIM=$(echo \"$BERRY_LOGS\" | grep -i \"Claimed drop:\" | tail -n 1 | sed 's/.*Claimed drop: //' | cut -c 1-35); " +
            "MAIN_ERR=$(echo \"$MAIN_LOGS\" | grep -iqE \"401|403|rate limit|integrity|unauthorized|failed\" && echo 1 || echo 0); " +
            "BERRY_ERR=$(echo \"$BERRY_LOGS\" | grep -iqE \"401|403|rate limit|integrity|unauthorized|failed\" && echo 1 || echo 0); " +
            "echo '{\"main_running\": '$MAIN_RUNNING', \"berry_running\": '$BERRY_RUNNING', \"main_watching\": \"'$MAIN_WATCHING'\", \"berry_watching\": \"'$BERRY_WATCHING'\", \"main_claim\": \"'$MAIN_CLAIM'\", \"berry_claim\": \"'$BERRY_CLAIM'\", \"main_err\": '$MAIN_ERR', \"berry_err\": '$BERRY_ERR'}'"
        ]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const obj = JSON.parse(data.trim())
                    unifiedBox.mainRunning = obj.main_running === 1;
                    unifiedBox.berryRunning = obj.berry_running === 1;
                    unifiedBox.mainWatching = obj.main_watching || "";
                    unifiedBox.berryWatching = obj.berry_watching || "";
                    unifiedBox.mainClaim = obj.main_claim || "";
                    unifiedBox.berryClaim = obj.berry_claim || "";
                    unifiedBox.mainError = obj.main_err === 1;
                    unifiedBox.berryError = obj.berry_err === 1;
                } catch (e) {}
                unifiedBox.calculatePriorityState();
            }
        }
    }

    // 3. PRIORITY & TOOLTIP ENGINE
    function calculatePriorityState() {
        let lines = [];
        let isError = false;
        let isActive = false;

        // RED ALERTS (Attention Required)
        if (unifiedBox.mainError || unifiedBox.berryError) {
            isError = true;
            unifiedBox.activeLabel = "ERR: Limited";
            lines.push("❌ ATTENTION: Twitch Rate Limited!");
            lines.push("Auto-Fix: Restarting container...");
        }
        else if (unifiedBox.borgStatus === "error" || unifiedBox.borgStatus === "failed") {
            isError = true;
            unifiedBox.activeLabel = "ERR: Borg";
            lines.push("❌ ATTENTION: Borg Backup Failed!");
        }
        // GREEN ACTIVE STATES
        else if (unifiedBox.borgStatus === "running" || unifiedBox.borgStatus === "syncing" || unifiedBox.borgStatus === "indexing") {
            isActive = true;
            unifiedBox.activeLabel = "Borg: " + unifiedBox.borgProgress;
            lines.push("✔ BORG BACKUP ACTIVE (" + unifiedBox.borgPercent + "%)");
        }
        else if (unifiedBox.mainWatching.length > 0) {
            isActive = true;
            unifiedBox.activeLabel = unifiedBox.mainWatching;
            lines.push("✔ MINE: WATCHING " + unifiedBox.mainWatching);
        }
        else if (unifiedBox.berryWatching.length > 0) {
            isActive = true;
            unifiedBox.activeLabel = "Sister: " + unifiedBox.berryWatching;
            lines.push("✔ SISTER: WATCHING " + unifiedBox.berryWatching);
        }
        // IDLE STATE (Returns to "Sys OK" in Normal Theme Color)
        else {
            unifiedBox.activeLabel = "Sys OK";
            lines.push("✔ ALL SYSTEMS NOMINAL");
        }

        // TOOLTIP DETAILED SUMMARY
        lines.push("----------------------------");
        lines.push("Borg Offsite: " + (unifiedBox.borgStatus === "idle" ? "Idle" : unifiedBox.borgStatus));
        lines.push("");

        // MINE SECTION
        lines.push("[MINE]: " + (unifiedBox.mainWatching ? "Watching " + unifiedBox.mainWatching : (unifiedBox.mainRunning ? "Idle (Drops Claimed)" : "Stopped")));
        if (unifiedBox.mainClaim.length > 0) {
            lines.push("  Claimed: " + unifiedBox.mainClaim);
        }

        lines.push("");

        // SISTER SECTION
        lines.push("[SISTER]: " + (unifiedBox.berryWatching ? "Watching " + unifiedBox.berryWatching : (unifiedBox.berryRunning ? "Idle (Drops Claimed)" : "Stopped")));
        if (unifiedBox.berryClaim.length > 0) {
            lines.push("  Claimed: " + unifiedBox.berryClaim);
        }

        unifiedBox.needsAttention = isError;
        unifiedBox.activeColor = isError ? "#f38ba8" : (isActive ? "#a6e3a1" : unifiedBox.themeBase05);
        unifiedBox.tooltipLines = lines;
    }

    // Capsule Label Text
    Text {
        id: capsuleText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: themePadding
        anchors.bottomMargin: themePadding

        text: "<font color='" + unifiedBox.activeColor + "'>" + unifiedBox.activeLabel + "</font>"

        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        textFormat: Text.RichText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    HoverHandler {
        id: hoverTracker
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: {
            borgPoller.running = true;
            podmanPoller.running = true;
        }
    }

    // Detailed Multi-System Slanted Tooltip
    SlantedTooltip {
        id: tooltip
        moduleItem: unifiedBox
        barWindow: unifiedBox.barWindow
        tooltipActive: hoverTracker.hovered
        pin: false

        alignSide: "Left"

        tooltipHeight: unifiedBox.tooltipHeight
        collapsedCoreWidth: unifiedBox.tooltipCollapsedWidth
        expandedCoreWidth: unifiedBox.tooltipExpandedWidth
        topOffset: unifiedBox.tooltipTopOffset
        rightOffset: unifiedBox.tooltipRightOffset

        slantLeft: unifiedBox.slantLeft
        slantRight: unifiedBox.slantRight

        Text {
            text: "SYSTEM MONITOR DASHBOARD:"
            font.family: themeFontFamily
            font.pixelSize: themeFontSize - 1
            font.bold: true
            color: unifiedBox.activeColor
            y: 35
            x: tooltip.slantX(y) + 24
        }

        Rectangle {
            height: 2
            color: themeBase02
            width: 320
            y: 65
            x: tooltip.slantX(y) + 24
        }

        Repeater {
            model: unifiedBox.tooltipLines.length
            Text {
                text: unifiedBox.tooltipLines[index]
                font.family: "monospace"
                font.pixelSize: themeFontSize - 1
                color: (index === 0 && unifiedBox.needsAttention) ? "#f38ba8" : themeBase05
                y: 80 + (index * 22)
                x: tooltip.slantX(y) + 24
            }
        }
    }
}
