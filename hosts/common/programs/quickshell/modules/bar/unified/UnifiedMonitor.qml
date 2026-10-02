// UnifiedMonitor.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

Item {
    id: unifiedBox

    property var barWindow: null
    property string moduleName: "unified"

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

    // Sudo Password Prompt State
    property bool isPromptingPassword: false
    property string pendingAuthAction: "mount"
    property string mountErrorMsg: ""
    property bool passwordError: false

    // Theme Fallbacks
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property color themeBase00: (shell && shell.theme && typeof shell.theme.base00 !== "undefined") ? shell.theme.base00 : "#11111b"
    readonly property color themeBase01: (shell && shell.theme && typeof shell.theme.base01 !== "undefined") ? shell.theme.base01 : "#1a1a1a"
    readonly property color themeBase02: (shell && shell.theme && typeof shell.theme.base02 !== "undefined") ? shell.theme.base02 : "gray"
    readonly property color themeBase03: (shell && shell.theme && typeof shell.theme.base03 !== "undefined") ? shell.theme.base03 : "#003399"
    readonly property color themeBase05: (shell && shell.theme && typeof shell.theme.base05 !== "undefined") ? shell.theme.base05 : "yellow"
    readonly property color themeBase08: (shell && shell.theme && typeof shell.theme.base08 !== "undefined") ? shell.theme.base08 : "#ff0000"
    readonly property color themeBase09: (shell && shell.theme && typeof shell.theme.base09 !== "undefined") ? shell.theme.base09 : "#fe8019"
    readonly property color themeBase0C: (shell && shell.theme && typeof shell.theme.base0C !== "undefined") ? shell.theme.base0C : "#04f100"

    property int tooltipCollapsedWidth: 140
    property int tooltipExpandedWidth: 860
    property int tooltipTopOffset: -3
    property int tooltipRightOffset: 0
    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: unifiedBox.themeSlantWidth

    implicitWidth: capsuleText.implicitWidth + bg.leftPadding + bg.rightPadding + 20
    width: implicitWidth
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
            if (!hoverTracker.hovered && !tooltipMouseArea.containsMouse && !unifiedBox.isPromptingPassword) {
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
        cmdRunner.command = ["bash", "-c", cmdString];
        cmdRunner.running = true;
    }

    // Authenticated Borg Mount Process
    Process {
        id: borgMountProc
        running: false
        property string errorOutput: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim()) borgMountProc.errorOutput = data.trim(); }
        }
        onStarted: { errorOutput = ""; }
        onExited: (code) => {
            if (code === 0) {
                unifiedBox.isPromptingPassword = false;
                unifiedBox.passwordError = false;
                unifiedBox.mountErrorMsg = "";
                sudoPassField.text = "";
                if (unifiedBox.pendingAuthAction === "mount") {
                    Quickshell.execDetached(["xdg-open", "/tmp/borg-mount"]);
                }
                recalculateState();
            } else {
                unifiedBox.passwordError = true;
                unifiedBox.mountErrorMsg = errorOutput ? errorOutput.slice(0, 45) : "Auth or Mount Failed";
                sudoPassField.text = "";
                sudoPassField.forceActiveFocus();
            }
        }
    }

    function executeBorgAction(password) {
        if (!password) return;
        unifiedBox.passwordError = false;
        unifiedBox.mountErrorMsg = "";
        borgMountProc.running = false;
        if (unifiedBox.pendingAuthAction === "unmount") {
            borgMountProc.command = [
                "sudo", "-S", "-k", "bash", "-c",
                "fusermount -u -z /tmp/borg-mount 2>/dev/null || borg umount /tmp/borg-mount 2>/dev/null || umount -l /tmp/borg-mount"
            ];
        } else {
            borgMountProc.command = [
                "sudo", "-S", "-k", "bash", "-c",
                "fusermount -u -z /tmp/borg-mount 2>/dev/null || true; mkdir -p /tmp/borg-mount && export BORG_PASSPHRASE=$(cat /run/secrets/borg_passphrase 2>/dev/null || true); borg mount -o allow_other /mnt/main_backup /tmp/borg-mount"
            ];
        }
        borgMountProc.running = true;
        borgMountProc.write(password + "\n");
    }

    // --- ENGINES ---
    RecordingEngine { id: recEngine; onIsRecordingChanged: recalculateState(); onIsStreamingChanged: recalculateState() }
    GameSentinel { id: gameSentinel; onIsStormHoldChanged: recalculateState() }
    BorgSyncEngine { id: borgEngine; onProgressLabelChanged: recalculateState(); onServiceActiveChanged: recalculateState(); onIsMountedChanged: recalculateState() }
    SysHealthEngine { id: sysHealth; onFailedCountChanged: recalculateState(); onRebootRequiredChanged: recalculateState() }
    PodmanTwitchEngine { id: twitchEngine; onCommandRequested: cmd => unifiedBox.runCmd(cmd); onMainWatchingChanged: recalculateState(); onBerryWatchingChanged: recalculateState() }

    function recalculateState() {
        let lines = [];
        let isError = false;
        let isWarning = false;
        let isActive = false;

        if (recEngine.isRecording && recEngine.isStreaming) {
            isActive = true;
            unifiedBox.activeLabel = "🔴 Rec + Live";
            lines.push("🔴 CAPTURE ACTIVE: Region Recording + Live Stream");
        } else if (recEngine.isStreaming) {
            isActive = true;
            unifiedBox.activeLabel = "🟣 Live Twitch";
            lines.push("🟣 STREAMING ACTIVE: Live to Twitch");
        } else if (recEngine.isRecording) {
            isActive = true;
            unifiedBox.activeLabel = "🔴 Recording";
            lines.push("🔴 REGION RECORDING ACTIVE");
        } else if (sysHealth.failedCount > 0) {
            isError = true;
            let firstFailed = sysHealth.failedUnits[0] || "Unit";
            unifiedBox.activeLabel = "ERR: " + (sysHealth.failedCount === 1 ? firstFailed.replace(".service", "") : sysHealth.failedCount + " Failed");
            lines.push("❌ CRITICAL: " + sysHealth.failedCount + " Failed Service(s):");
            for (let i = 0; i < sysHealth.failedUnits.length; i++) {
                lines.push("  • " + sysHealth.failedUnits[i]);
            }
        } else if (sysHealth.diskWarning) {
            isWarning = true;
            let maxPercent = Math.max(sysHealth.diskRootPercent, sysHealth.diskBackupPercent);
            unifiedBox.activeLabel = "Disk: " + maxPercent + "%";
            lines.push("⚠️ WARNING: High Disk Usage (" + maxPercent + "%)!");
            lines.push("  Root (/): " + sysHealth.diskRootPercent + "% | Backup: " + sysHealth.diskBackupPercent + "%");
        } else if (sysHealth.rebootRequired) {
            isWarning = true;
            unifiedBox.activeLabel = "Reboot Req";
            lines.push("⚠️ SYSTEM REBOOT REQUIRED");
            lines.push("  Current Booted: " + sysHealth.runningKernel);
            lines.push("  Next on Reboot: " + sysHealth.latestKernel);
        } else {
            unifiedBox.activeLabel = "Sys OK";
            lines.push("✔ ALL SYSTEMS NOMINAL");
        }

        lines.push("--------------------------------------");
        lines.push("Screen Capture: " + (recEngine.isRecording ? (recEngine.isStreaming ? "Recording + Streaming" : "Recording") : (recEngine.isStreaming ? "Streaming" : "Idle")));
        lines.push("Booted Kernel:  " + sysHealth.runningKernel);
        lines.push("Storage Health: Root (" + sysHealth.diskRootPercent + "%) | 3TB HDD (" + sysHealth.diskBackupPercent + "%)");
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

        if (isError) unifiedBox.activeColor = themeBase08.toString();
        else if (isWarning) unifiedBox.activeColor = themeBase09.toString();
        else if (isActive) unifiedBox.activeColor = themeBase0C.toString();
        else unifiedBox.activeColor = unifiedBox.themeBase05.toString();

        unifiedBox.tooltipLines = lines;
    }

    Text {
        id: capsuleText
        anchors.fill: parent
        anchors.leftMargin: unifiedBox.slantWidth + 4
        anchors.rightMargin: unifiedBox.slantWidth + 4
        anchors.topMargin: 2
        anchors.bottomMargin: 2
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
        tooltipActive: unifiedBox.isTooltipVisible || unifiedBox.isPromptingPassword
        pin: unifiedBox.isPinned || unifiedBox.isPromptingPassword
        alignSide: "Left"
        keyboardFocus: unifiedBox.isPromptingPassword ? WlrLayershell.Exclusive : WlrLayershell.None

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

        // Header Title
        Text {
            id: headerTitleText
            text: "SYSTEM MONITOR DASHBOARD:"
            font.family: themeFontFamily
            font.pixelSize: themeFontSize - 1
            font.bold: true
            color: unifiedBox.activeColor
            y: 20
            x: tooltip.slantX(y) + 28
        }

        // DYNAMIC LINES SLICE
        readonly property int maxLines: Math.max(4, Math.floor((tooltip.liveTooltipHeight - 110) / 19))
        readonly property var visibleLines: unifiedBox.tooltipLines.slice(0, maxLines)

        // DIAGONAL SLANTED STAIRCASE
        Repeater {
            model: tooltip.visibleLines.length
            delegate: Text {
                y: 50 + (index * 19)
                x: tooltip.slantX(y) + 28
                width: tooltip.effectiveCoreWidth - 48
                text: tooltip.visibleLines[index]
                font.family: "monospace"
                font.pixelSize: Math.max(10, themeFontSize - 2)
                color: {
                    let line = tooltip.visibleLines[index];
                    if (line.indexOf("❌") !== -1 || line.indexOf("•") !== -1) return themeBase08;
                    if (line.indexOf("⚠️") !== -1 || line.indexOf("SYSTEM REBOOT") !== -1 || line.indexOf("Next on Reboot") !== -1) return themeBase09;
                    if (line.indexOf("✔") !== -1) return themeBase0C;
                    return themeBase05;
                }
                elide: Text.ElideRight
            }
        }

        // 1. STANDARD BUTTONS (Auto-resizing proportionally to fit inside slant)
        RowLayout {
            id: actionButtonsRow
            visible: !unifiedBox.isPromptingPassword
            spacing: 6
            y: tooltip.liveTooltipHeight - 40
            x: tooltip.slantX(y) + 24
            width: tooltip.effectiveCoreWidth - 48

            Rectangle {
                visible: recEngine.isActive
                Layout.fillWidth: true
                Layout.minimumWidth: 40
                Layout.preferredHeight: 28
                height: 28
                color: stopRecHover.hovered ? "#45475a" : "#181825"
                border.color: "#ff5555"; border.width: 1.5; radius: 6
                Text { anchors.centerIn: parent; width: Math.min(parent.width - 4, implicitWidth); elide: Text.ElideRight; text: "⏹ Stop"; font.pixelSize: 10; font.bold: true; color: "#ff5555" }
                HoverHandler { id: stopRecHover }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: recEngine.stopAll() }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 50
                Layout.preferredHeight: 28
                height: 28
                color: syncBtnHover.hovered ? "#313244" : "#181825"
                border.color: themeBase05; border.width: 1.5; radius: 6
                Text { anchors.centerIn: parent; width: Math.min(parent.width - 4, implicitWidth); elide: Text.ElideRight; text: borgEngine.serviceActive ? "⏸ Pause" : "▶ Sync"; font.pixelSize: 10; font.bold: true; color: themeBase05 }
                HoverHandler { id: syncBtnHover }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (borgEngine.serviceActive) {
                            borgEngine.serviceActive = false;
                            unifiedBox.runCmd("sudo -n game-sync-pause");
                        } else {
                            borgEngine.serviceActive = true;
                            unifiedBox.runCmd("sudo -n game-sync-resume");
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 50
                Layout.preferredHeight: 28
                height: 28
                color: resetBtnHover.hovered ? "#313244" : "#181825"
                border.color: sysHealth.failedCount > 0 ? themeBase08 : themeBase05; border.width: 1.5; radius: 6
                Text { anchors.centerIn: parent; width: Math.min(parent.width - 4, implicitWidth); elide: Text.ElideRight; text: sysHealth.failedCount > 0 ? "🔄 Reset (" + sysHealth.failedCount + ")" : "✔ 0 Failed"; font.pixelSize: 10; font.bold: true; color: sysHealth.failedCount > 0 ? themeBase08 : themeBase05 }
                HoverHandler { id: resetBtnHover }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: unifiedBox.runCmd("sudo -n systemctl reset-failed; systemctl --user reset-failed") }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 50
                Layout.preferredHeight: 28
                height: 28
                color: mountBtnHover.hovered ? "#313244" : "#181825"
                border.color: borgEngine.isMounted ? themeBase09 : themeBase0C; border.width: 1.5; radius: 6
                Text { anchors.centerIn: parent; width: Math.min(parent.width - 4, implicitWidth); elide: Text.ElideRight; text: borgEngine.isMounted ? "⏏ Unmount" : "📂 Browse"; font.pixelSize: 10; font.bold: true; color: borgEngine.isMounted ? themeBase09 : themeBase0C }
                HoverHandler { id: mountBtnHover }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        unifiedBox.pendingAuthAction = borgEngine.isMounted ? "unmount" : "mount";
                        unifiedBox.isPromptingPassword = true;
                        unifiedBox.passwordError = false;
                        unifiedBox.mountErrorMsg = "";
                        sudoPassField.text = "";
                        Qt.callLater(() => sudoPassField.forceActiveFocus());
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 45
                Layout.preferredHeight: 28
                height: 28
                color: dynBtnHover.hovered ? "#313244" : "#181825"
                border.color: sysHealth.rebootRequired ? themeBase09 : themeBase05; border.width: 1.5; radius: 6
                Text { anchors.centerIn: parent; width: Math.min(parent.width - 4, implicitWidth); elide: Text.ElideRight; text: sysHealth.rebootRequired ? "🔄 Reboot" : (unifiedBox.gcRunning ? "🧹 ..." : "🧹 GC"); font.pixelSize: 10; font.bold: true; color: sysHealth.rebootRequired ? themeBase09 : themeBase05 }
                HoverHandler { id: dynBtnHover }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (sysHealth.rebootRequired) unifiedBox.runCmd("systemctl reboot");
                        else if (!unifiedBox.gcRunning) {
                            unifiedBox.gcRunning = true;
                            unifiedBox.runCmd("if command -v nix-collect-garbage >/dev/null 2>&1; then sudo -n nix-collect-garbage --delete-older-than 14d; else sudo -n journalctl --vacuum-time=14d 2>/dev/null || true; fi");
                        }
                    }
                }
            }
        }

        // 2. THEMED INLINE SUDO PASSWORD PROMPT
        RowLayout {
            id: sudoPasswordRow
            onVisibleChanged: if (visible) Qt.callLater(() => sudoPassField.forceActiveFocus())
            visible: unifiedBox.isPromptingPassword
            spacing: 8
            y: tooltip.liveTooltipHeight - 40
            x: tooltip.slantX(y) + 24
            width: tooltip.effectiveCoreWidth - 48

            Text {
                text: unifiedBox.passwordError ? "⚠️ Auth Failed:" : "🔑 Sudo Password:"
                font.family: themeFontFamily
                font.pixelSize: 11
                font.bold: true
                color: unifiedBox.passwordError ? themeBase08 : themeBase05
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                clip: true
                height: 26
                radius: 4
                color: themeBase00
                border.color: unifiedBox.passwordError ? themeBase08 : themeBase05
                border.width: 1

                TextInput {
                    id: sudoPassField
                    clip: true
                    anchors.fill: parent
                    anchors.margins: 4
                    echoMode: TextInput.Password
                    color: themeBase05
                    font.family: themeFontFamily
                    font.pixelSize: 13
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    onAccepted: unifiedBox.executeBorgAction(text)

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            unifiedBox.isPromptingPassword = false;
                            unifiedBox.passwordError = false;
                            event.accepted = true;
                        }
                    }
                }
            }

            Rectangle {
                width: 65; height: 26; radius: 4
                color: mountConfirmHover.hovered ? themeBase0C : "transparent"
                border.color: themeBase0C; border.width: 1
                Text { anchors.centerIn: parent; text: "✔ OK"; font.bold: true; font.pixelSize: 11; color: mountConfirmHover.hovered ? themeBase00 : themeBase0C }
                HoverHandler { id: mountConfirmHover }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: unifiedBox.executeBorgAction(sudoPassField.text) }
            }

            Rectangle {
                width: 50; height: 26; radius: 4
                color: mountCancelHover.hovered ? themeBase08 : "transparent"
                border.color: themeBase08; border.width: 1
                Text { anchors.centerIn: parent; text: "✕"; font.bold: true; font.pixelSize: 11; color: mountCancelHover.hovered ? themeBase00 : themeBase08 }
                HoverHandler { id: mountCancelHover }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        unifiedBox.isPromptingPassword = false;
                        unifiedBox.passwordError = false;
                    }
                }
            }
        }
    }
}
