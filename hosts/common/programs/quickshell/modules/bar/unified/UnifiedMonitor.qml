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
    property var tooltipLines: ["✔ ALL SYSTEMS NOMINAL"]

    // UI Pinning & Tooltip
    property bool isPinned: false
    property bool tooltipHovered: false
    readonly property bool isTooltipVisible: isPinned || hoverTracker.hovered || tooltipHovered
    property bool gcRunning: false

    // Theme Fallbacks
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property color themeBase01: (shell && shell.theme && typeof shell.theme.base01 !== "undefined") ? shell.theme.base01 : "#1a1a1a"
    readonly property color themeBase02: (shell && shell.theme && typeof shell.theme.base02 !== "undefined") ? shell.theme.base02 : "gray"
    readonly property color themeBase05: (shell && shell.theme && typeof shell.theme.base05 !== "undefined") ? shell.theme.base05 : "yellow"

    // Layout configuration
    property int tooltipHeight: 500
    property int tooltipCollapsedWidth: 105
    property int tooltipExpandedWidth: 640
    property int tooltipTopOffset: -3
    property int tooltipRightOffset: 20
    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: unifiedBox.themeSlantWidth

    width: 140
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: unifiedBox.slantLeft
        slantRight: unifiedBox.slantRight
        slantWidth: unifiedBox.slantWidth
    }

    Timer {
        id: closeGraceTimer
        interval: 350; repeat: false
        onTriggered: {
            if (!hoverTracker.hovered && !tooltipMouseArea.containsMouse) {
                unifiedBox.tooltipHovered = false;
            }
        }
    }

    Process {
        id: cmdRunner
        onExited: {
            unifiedBox.gcRunning = false;
            recalculateState();
        }
    }

    function runCmd(cmdString) {
        cmdRunner.running = false;
        cmdRunner.command = ["/run/current-system/sw/bin/bash", "-c", cmdString];
        cmdRunner.running = true;
    }

    // --- INSTANTIATE ENGINES ---
    GameSentinel {
        id: gameSentinel
        onIsGamingChanged: recalculateState()
        onIsStormHoldChanged: recalculateState()
    }

    BorgSyncEngine {
        id: borgEngine
        onProgressLabelChanged: recalculateState()
        onServiceActiveChanged: recalculateState()
        onIsMountedChanged: recalculateState()
    }

    SysHealthEngine {
        id: sysHealth
        onFailedCountChanged: recalculateState()
        onRebootRequiredChanged: recalculateState()
    }

    PodmanTwitchEngine {
        id: twitchEngine
        onCommandRequested: cmd => unifiedBox.runCmd(cmd)
        onMainWatchingChanged: recalculateState()
        onBerryWatchingChanged: recalculateState()
    }

    AgentEngine {
        id: agentEngine
        onIsRunningChanged: recalculateState()
        onIsPausedChanged: recalculateState()
    }

    // --- PRIORITY & TOOLTIP STATE ENGINE ---
    function recalculateState() {
        let lines = [];
        let isError = false;
        let isWarning = false;
        let isActive = false;

        if (sysHealth.failedCount > 0) {
            isError = true;
            let firstFailed = sysHealth.failedUnits[0] || "Unit";
            unifiedBox.activeLabel = "ERR: " + (sysHealth.failedCount === 1 ? firstFailed.replace(".service", "") : sysHealth.failedCount + " Failed");
            lines.push("❌ CRITICAL: " + sysHealth.failedCount + " Failed Service(s):");
            for (let i = 0; i < sysHealth.failedUnits.length; i++) {
                lines.push("  • " + sysHealth.failedUnits[i]);
            }
        }
        else if (sysHealth.hddBadSectors > 0) {
            isError = true;
            unifiedBox.activeLabel = "ERR: HDD Bad";
            lines.push("❌ HARD DRIVE WARNING: " + sysHealth.hddBadSectors + " Bad Sector(s)!");
        }
        else if (sysHealth.diskWarning) {
            isWarning = true;
            let maxPercent = Math.max(sysHealth.diskRootPercent, sysHealth.diskBackupPercent);
            unifiedBox.activeLabel = "Disk: " + maxPercent + "%";
            lines.push("⚠️ WARNING: High Disk Usage (" + maxPercent + "%)!");
            lines.push("  Root (/): " + sysHealth.diskRootPercent + "% | Backup: " + sysHealth.diskBackupPercent + "%");
        }
        else if (twitchEngine.mainError || twitchEngine.berryError) {
            isError = true;
            unifiedBox.activeLabel = "ERR: Limited";
            lines.push("❌ ATTENTION: Twitch Rate Limited!");
            lines.push("Auto-Fix: Restarting container...");
        }
        else if (borgEngine.status === "error" || borgEngine.status === "failed") {
            isError = true;
            unifiedBox.activeLabel = "ERR: Borg";
            lines.push("❌ ATTENTION: Borg Backup Failed!");
        }
        // Storm Outage Threat Hold
        else if (gameSentinel.isStormHold) {
            isWarning = true;
            unifiedBox.activeLabel = "⛈️ Storm Hold";
            lines.push("⛈️ SEVERE WEATHER OUTAGE GUARD ACTIVE");
            lines.push("  ⚡ 3TB Drive Parked & Cloud Sync Paused to prevent blackout corruption");
        }
        // Gaming Mode Active
        else if (gameSentinel.isGaming) {
            isActive = true;
            unifiedBox.activeLabel = "🎮 Gaming";
            lines.push("🎮 GAMING MODE ACTIVE");
            lines.push("  ⚡ Ping Protector: Cloud Sync blocked (0% upload)");
        }
        else if (borgEngine.serviceActive) {
            isActive = true;
            unifiedBox.activeLabel = borgEngine.progressLabel;
            if (borgEngine.progressLabel === "Resuming...") {
                lines.push("✔ CLOUD SYNC: Resuming transfer...");
            } else {
                lines.push("✔ CLOUD SYNC ACTIVE (" + borgEngine.percent + "%)");
            }
            lines.push("  Remaining: " + borgEngine.remaining);
            lines.push("  Speed:     " + borgEngine.speed);
            if (borgEngine.eta.length > 0) lines.push("  ETA:       " + borgEngine.eta);
        }
        else if (borgEngine.status === "running" || borgEngine.status === "indexing") {
            isActive = true;
            unifiedBox.activeLabel = borgEngine.progressLabel;
            lines.push("✔ BORG LOCAL BACKUP (" + borgEngine.percent + "%)");
        }
        else if (!borgEngine.serviceActive && borgEngine.remaining !== "0 MB" && borgEngine.remaining !== "") {
            unifiedBox.activeLabel = "Sync Paused";
            lines.push("⏸ CLOUD SYNC PAUSED");
            lines.push("  Remaining: " + borgEngine.remaining);
        }
        // AI Agent Status
        else if (agentEngine.isRunning) {
            isActive = true;
            unifiedBox.activeLabel = "🤖 AI Working";
            lines.push("🤖 AI AGENT ACTIVE (7900 XTX)");
        }
        else if (agentEngine.isPaused) {
            unifiedBox.activeLabel = "⏸ AI Paused";
            lines.push("⏸ AI AGENT PAUSED (State Saved | 0 MB VRAM)");
        }
        else if (sysHealth.rebootRequired) {
            isWarning = true;
            unifiedBox.activeLabel = "Reboot Req";
            lines.push("⚠️ SYSTEM REBOOT REQUIRED");
            lines.push("  Current Booted: " + sysHealth.runningKernel);
            lines.push("  Next on Reboot: " + sysHealth.latestKernel);
        }
        else if (sysHealth.gitUncommitted > 0) {
            unifiedBox.activeLabel = "Git: " + sysHealth.gitUncommitted + " edits";
            lines.push("ℹ️ NIX CONFIG: " + sysHealth.gitUncommitted + " Uncommitted Change(s)");
        }
        else if (twitchEngine.mainWatching.length > 0) {
            isActive = true;
            unifiedBox.activeLabel = twitchEngine.mainWatching;
            lines.push("✔ MINE: WATCHING " + twitchEngine.mainWatching);
        }
        else if (twitchEngine.berryWatching.length > 0) {
            isActive = true;
            unifiedBox.activeLabel = "Sister: " + twitchEngine.berryWatching;
            lines.push("✔ SISTER: WATCHING " + twitchEngine.berryWatching);
        }
        else {
            unifiedBox.activeLabel = "Sys OK";
            lines.push("✔ ALL SYSTEMS NOMINAL");
        }

        lines.push("--------------------------------------");
        lines.push("AI Agent:       " + (agentEngine.isRunning ? "Working (VRAM Active)" : (agentEngine.isPaused ? "Paused (0 MB VRAM)" : "Idle")));
        lines.push("Power Guard:    " + (gameSentinel.isStormHold ? "Storm Hold (Drive Parked)" : "Normal (Grid Stable)"));
        lines.push("Gaming Sentinel:" + (gameSentinel.isGaming ? "Active (In-Game)" : "Idle (0 Games)"));
        lines.push("Booted Kernel:  " + sysHealth.runningKernel);
        lines.push("Next on Reboot: " + (sysHealth.rebootRequired ? (sysHealth.latestKernel + " (Pending)") : (sysHealth.runningKernel + " (Matches)")));
        lines.push("Storage Health: Root (" + sysHealth.diskRootPercent + "%) | 3TB HDD (" + sysHealth.diskBackupPercent + "% | " + sysHealth.hddTemp + ")");
        lines.push("Flake Status:   " + (sysHealth.flakeAgeDays > 0 ? (sysHealth.flakeAgeDays + "d old") : "Up-to-date") + " | " + sysHealth.nixGenerations + " profiles");
        lines.push("Borg Offsite:   " + (borgEngine.serviceActive ? "Syncing" : (borgEngine.remaining !== "0 MB" && borgEngine.remaining !== "" ? "Paused" : "Idle")));
        if (borgEngine.isMounted) lines.push("📂 Backups Mounted at: /tmp/borg-mount");
        lines.push("");

        lines.push("[MINE]: " + (twitchEngine.mainWatching ? "Watching " + twitchEngine.mainWatching : (twitchEngine.mainRunning ? "Idle (Drops Claimed)" : "Stopped")));
        if (twitchEngine.mainClaim.length > 0) lines.push("  Claimed: " + twitchEngine.mainClaim);
        lines.push("");
        lines.push("[SISTER]: " + (twitchEngine.berryWatching ? "Watching " + twitchEngine.berryWatching : (twitchEngine.berryRunning ? "Idle (Drops Claimed)" : "Stopped")));
        if (twitchEngine.berryClaim.length > 0) lines.push("  Claimed: " + twitchEngine.berryClaim);

        unifiedBox.needsAttention = (isError || isWarning);
        unifiedBox.activeColor = isError ? "#f38ba8" : (isWarning ? "#fab387" : (gameSentinel.isGaming ? "#cba6f7" : (agentEngine.isRunning ? "#89b4fa" : (agentEngine.isPaused ? "#f9e2af" : (isActive ? "#a6e3a1" : (!borgEngine.serviceActive && borgEngine.remaining !== "0 MB" && borgEngine.remaining !== "" ? "#f9e2af" : unifiedBox.themeBase05))))));
        unifiedBox.tooltipLines = lines;
    }

    Text {
        id: capsuleText
        anchors.fill: parent
        anchors.leftMargin: unifiedBox.slantWidth + 4
        anchors.rightMargin: unifiedBox.slantWidth + 4
        anchors.topMargin: themePadding
        anchors.bottomMargin: themePadding
        text: "<font color='" + unifiedBox.activeColor + "'>" + unifiedBox.activeLabel + "</font>"
        font.family: themeFontFamily
        font.pixelSize: themeFontSize - 1
        font.bold: true
        textFormat: Text.RichText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    HoverHandler {
        id: hoverTracker
        onHoveredChanged: {
            if (!hovered) closeGraceTimer.start();
            else closeGraceTimer.stop();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: {
            unifiedBox.isPinned = !unifiedBox.isPinned;
            recalculateState();
        }
    }

    SlantedTooltip {
        id: tooltip
        moduleItem: unifiedBox
        barWindow: unifiedBox.barWindow
        tooltipActive: unifiedBox.isTooltipVisible
        pin: unifiedBox.isPinned
        alignSide: "Left"
        tooltipHeight: unifiedBox.tooltipHeight
        collapsedCoreWidth: unifiedBox.tooltipCollapsedWidth
        expandedCoreWidth: unifiedBox.tooltipExpandedWidth
        topOffset: unifiedBox.tooltipTopOffset
        rightOffset: unifiedBox.tooltipRightOffset
        slantLeft: unifiedBox.slantLeft
        slantRight: unifiedBox.slantRight

        MouseArea {
            id: tooltipMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: { closeGraceTimer.stop(); unifiedBox.tooltipHovered = true; }
            onExited: closeGraceTimer.start();
        }

        Text {
            text: "SYSTEM MONITOR DASHBOARD:"
            font.family: themeFontFamily
            font.pixelSize: themeFontSize - 1
            font.bold: true
            color: unifiedBox.activeColor
            y: 26
            x: tooltip.slantX(y) + 24
        }

        Rectangle {
            height: 2; color: themeBase02; width: 320; y: 48
            x: tooltip.slantX(y) + 24
        }

        Repeater {
            model: unifiedBox.tooltipLines.length
            Text {
                text: unifiedBox.tooltipLines[index]
                font.family: "monospace"
                font.pixelSize: themeFontSize - 2
                color: {
                    if (unifiedBox.tooltipLines[index].indexOf("❌") !== -1 || unifiedBox.tooltipLines[index].indexOf("•") !== -1) return "#f38ba8";
                    if (unifiedBox.tooltipLines[index].indexOf("⚠️") !== -1 || unifiedBox.tooltipLines[index].indexOf("⛈️") !== -1 || unifiedBox.tooltipLines[index].indexOf("(Pending)") !== -1) return "#fab387";
                    if (unifiedBox.tooltipLines[index].indexOf("🎮") !== -1) return "#cba6f7";
                    if (unifiedBox.tooltipLines[index].indexOf("🤖") !== -1) return "#89b4fa";
                    if (unifiedBox.tooltipLines[index].indexOf("✔") !== -1) return "#a6e3a1";
                    return themeBase05;
                }
                y: 58 + (index * 18)
                x: tooltip.slantX(y) + 24
            }
        }

        RowLayout {
            spacing: 6
            y: unifiedBox.tooltipHeight - 48
            x: tooltip.slantX(y) + 24

            // 1. Sync Control Button
            Rectangle {
                width: 100; height: 26
                color: syncBtnHover.hovered ? "#313244" : "#181825"
                border.color: (gameSentinel.isGaming || gameSentinel.isStormHold) ? "#cba6f7" : (borgEngine.serviceActive ? "#f9e2af" : "#a6e3a1")
                border.width: 1; radius: 4

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (gameSentinel.isStormHold) return "⛈️ Storm Hold";
                        if (gameSentinel.isGaming) return "🎮 In-Game";
                        return borgEngine.serviceActive ? "⏸ Pause Sync" : "▶ Resume Sync";
                    }
                    font.family: "monospace"; font.pixelSize: 11; font.bold: true
                    color: (gameSentinel.isGaming || gameSentinel.isStormHold) ? "#cba6f7" : (borgEngine.serviceActive ? "#f9e2af" : "#a6e3a1")
                }

                HoverHandler { id: syncBtnHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: (gameSentinel.isGaming || gameSentinel.isStormHold) ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (gameSentinel.isGaming || gameSentinel.isStormHold) return;
                        if (borgEngine.serviceActive) {
                            borgEngine.serviceActive = false;
                            unifiedBox.runCmd("sudo -n /run/current-system/sw/bin/game-sync-pause");
                        } else {
                            borgEngine.serviceActive = true;
                            unifiedBox.runCmd("sudo -n /run/current-system/sw/bin/game-sync-resume");
                        }
                    }
                }
            }

            // 2. Clear Failed Units Button
            Rectangle {
                width: 100; height: 26
                color: resetBtnHover.hovered ? "#313244" : "#181825"
                border.color: (sysHealth.failedCount > 0) ? "#f38ba8" : "#45475a"
                border.width: 1; radius: 4
                Text {
                    anchors.centerIn: parent
                    text: (sysHealth.failedCount > 0) ? "🔄 Reset (" + sysHealth.failedCount + ")" : "✔ 0 Failed"
                    font.family: "monospace"; font.pixelSize: 11; font.bold: true
                    color: (sysHealth.failedCount > 0) ? "#f38ba8" : "#a6adc8"
                }
                HoverHandler { id: resetBtnHover }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: unifiedBox.runCmd("sudo -n /run/current-system/sw/bin/systemctl reset-failed; systemctl --user reset-failed")
                }
            }

            // 3. Backup File Browser Toggle
            Rectangle {
                width: 100; height: 26
                color: mountBtnHover.hovered ? "#313244" : "#181825"
                border.color: borgEngine.isMounted ? "#fab387" : "#89b4fa"
                border.width: 1; radius: 4
                Text {
                    anchors.centerIn: parent
                    text: borgEngine.isMounted ? "⏏ Unmount" : "📂 Browse Files"
                    font.family: "monospace"; font.pixelSize: 11; font.bold: true
                    color: borgEngine.isMounted ? "#fab387" : "#89b4fa"
                }
                HoverHandler { id: mountBtnHover }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (borgEngine.isMounted) {
                            unifiedBox.runCmd("sudo -n /run/current-system/sw/bin/borg umount /tmp/borg-mount");
                        } else {
                            unifiedBox.runCmd("export BORG_PASSPHRASE=$(sudo cat /run/secrets/borg_passphrase); mkdir -p /tmp/borg-mount && sudo -n -E /run/current-system/sw/bin/borg mount /mnt/main_backup /tmp/borg-mount && xdg-open /tmp/borg-mount &");
                        }
                    }
                }
            }

            // 4. Dynamic Button: Reboot System OR Garbage Collect
            Rectangle {
                width: 90; height: 26
                color: dynBtnHover.hovered ? "#313244" : "#181825"
                border.color: sysHealth.rebootRequired ? "#fab387" : themeBase05
                border.width: 1; radius: 4
                Text {
                    anchors.centerIn: parent
                    text: sysHealth.rebootRequired ? "🔄 Reboot" : (unifiedBox.gcRunning ? "🧹 Running..." : "🧹 Run GC")
                    font.family: "monospace"; font.pixelSize: 11; font.bold: true
                    color: sysHealth.rebootRequired ? "#fab387" : themeBase05
                }
                HoverHandler { id: dynBtnHover }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (sysHealth.rebootRequired) {
                            unifiedBox.runCmd("systemctl reboot");
                        } else if (!unifiedBox.gcRunning) {
                            unifiedBox.gcRunning = true;
                            unifiedBox.runCmd("sudo -n /run/current-system/sw/bin/nix-collect-garbage --delete-older-than 14d");
                        }
                    }
                }
            }

            // 5. AI AGENT PAUSE / RESUME BUTTON
            Rectangle {
                width: 105; height: 26
                color: agentBtnHover.hovered ? "#313244" : "#181825"
                border.color: agentEngine.isRunning ? "#fab387" : (agentEngine.isPaused ? "#a6e3a1" : "#45475a")
                border.width: 1; radius: 4

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (agentEngine.isRunning) return "⏸ Pause AI";
                        if (agentEngine.isPaused) return "▶ Resume AI";
                        return "🤖 AI: Idle";
                    }
                    font.family: "monospace"; font.pixelSize: 11; font.bold: true
                    color: agentEngine.isRunning ? "#fab387" : (agentEngine.isPaused ? "#a6e3a1" : "#a6adc8")
                }

                HoverHandler { id: agentBtnHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: (agentEngine.isRunning || agentEngine.isPaused) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (agentEngine.isRunning) {
                            // Sends SIGINT to checkpoint state & instantly free 100% VRAM
                            unifiedBox.runCmd("pkill -SIGINT -f agent-worker");
                        } else if (agentEngine.isPaused) {
                            // Resumes agent in the background with the checkpointed state
                            unifiedBox.runCmd("nohup /run/current-system/sw/bin/agent --resume >/dev/null 2>&1 &");
                        }
                    }
                }
            }
        }
    }
}
