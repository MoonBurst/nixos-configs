// modules/overlays/launcher/SystemReadout.qml
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Relative imports targeting your bar metric directories
import "../../bar/cpu"
import "../../bar/gpu"
import "../../bar/ram"

Rectangle {
    id: systemReadoutPanel
    width: 320
    radius: shell.theme.defaultCardRadius
    color: shell.theme.base01
    border.width: shell.theme.globalBorderWidth
    border.color: shell.theme.base03

    // External dependencies injected by the parent on load
    property var shell
    property var barWindow

    // Internal states parsed from timers and processes
    property string timeStr: "--:--:--"
    property string dateStr: "---, --- --"
    property real totalVramGiB: 24.0 // Default initialized to 24G; updates dynamically on load
    property string diskFreeStr: "--G"
    property real diskFreeValue: 1.0 // Starts fully free; empties as storage fills
    property bool hasBattery: false  // Automatically detected on startup
    property string batteryName: ""
    property string batteryPercent: "0%"
    property string batteryStatus: "Unknown"
    property string batteryPower: "0.0W" // Declared to prevent 'undefined' string outputs

    // Pure QML/JS GPU Detector (Hides GPU/VRAM if VRAM reserves are under 3.0 GB)
    readonly property bool hasGPU: {
        var freeVram = parseFloat(gpuData.gpuVramFreeRaw);
        return !isNaN(freeVram) && freeVram > 3.0;
    }

    // Invisible Data Engines
    CpuCapsule { id: cpuData; visible: false; barWindow: systemReadoutPanel.barWindow }
    GpuCapsule { id: gpuData; visible: false; barWindow: systemReadoutPanel.barWindow }
    RamCapsule { id: ramData; visible: false; barWindow: systemReadoutPanel.barWindow }

    // Startup process to determine your exact total VRAM using AWK to prevent 'bc missing' errors
    Process {
        id: totalVramProc
        running: true
        command: [
            "sh", "-c",
            "if command -v nvidia-smi >/dev/null 2>&1; then total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n 1); if [ ! -z \"$total\" ]; then echo \"$total\" | awk '{printf \"%.1f\", $1/1024}'; exit; fi; fi; card_dir=$(ls -d /sys/class/drm/card*/device 2>/dev/null | head -n 1); if [ ! -z \"$card_dir\" ]; then bytes=$(cat \"$card_dir/mem_info_vram_total\" 2>/dev/null || echo '0'); if [ \"$bytes\" -gt 0 ]; then echo \"$bytes\" | awk '{printf \"%.1f\", $1}'; exit; fi; fi; echo '24.0'"
        ]
    }

    Connections {
        target: totalVramProc.stdout
        function onRead(data) {
            var val = parseFloat(data.trim());
            if (!isNaN(val) && val > 0.0) {
                systemReadoutPanel.totalVramGiB = val;
            }
        }
    }

    // Process to check if a dedicated GPU exists
    Process {
        id: gpuDetectProc
        running: true
        command: ["sh", "-c", "if command -v nvidia-smi >/dev/null 2>&1; then echo 'true'; elif ls /sys/class/drm/card*/device/mem_info_vram_total >/dev/null 2>&1; then if cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | awk '{if (\\$1 > 3221225472) exit 0; else exit 1}'; then echo 'true'; else echo 'false'; fi; else echo 'false'; fi"]
        stdout: SplitParser {
            onRead: data => {
                systemReadoutPanel.hasGPU = (data.trim() === "true");
            }
        }
    }

    // Process to check root storage usage via world-readable /nix/store subvolume path
    Process {
        id: diskProc
        running: false
        command: [
            "sh", "-c",
            "export PATH=$PATH:/run/current-system/sw/bin:/usr/bin:/bin; if [ -d /nix/store ]; then df -hP /nix/store; else df -hP /; fi 2>/dev/null | tail -n 1 | awk '{print $4 \":\" $5}'"
        ]
        stdout: SplitParser {
            onRead: data => {
                var trimmed = data.trim();
                if (!trimmed) return;
                var parts = trimmed.split(":");
                if (parts.length === 2) {
                    systemReadoutPanel.diskFreeStr = parts[0];
                    var pctUsed = parseFloat(parts[1]);
                    if (!isNaN(pctUsed)) {
                        systemReadoutPanel.diskFreeValue = Math.min(1.0, Math.max(0.0, (100.0 - pctUsed) / 100.0));
                    }
                }
            }
        }
    }

    // Startup process to detect battery directory (using SplitParser to ensure reliable stream capture)
    Process {
        id: batteryDetectProc
        running: true
        command: ["sh", "-c", "ls /sys/class/power_supply/ 2>/dev/null | grep -E '^BAT|^sb' | head -n 1"]
        stdout: SplitParser {
            onRead: data => {
                var name = data.trim();
                if (name !== "") {
                    systemReadoutPanel.batteryName = name;
                    systemReadoutPanel.hasBattery = true;
                    batteryPollProc.running = true;
                }
            }
        }
    }

    // Polling process for active battery status (returns capacity, charging status, and wattage draw via AWK)
    Process {
        id: batteryPollProc
        running: false
        command: [
            "sh", "-c",
            "dir=/sys/class/power_supply/" + systemReadoutPanel.batteryName + "; if [ -d \"$dir\" ]; then cap=$(cat \"$dir/capacity\" 2>/dev/null || echo '0'); stat=$(cat \"$dir/status\" 2>/dev/null || echo 'Unknown'); watt='0.0'; if [ -f \"$dir/power_now\" ]; then p_now=$(cat \"$dir/power_now\" 2>/dev/null || echo '0'); watt=$(awk -v p=\"$p_now\" 'BEGIN {printf \"%.1f\", p/1000000}'); elif [ -f \"$dir/voltage_now\" ] && [ -f \"$dir/current_now\" ]; then v_now=$(cat \"$dir/voltage_now\" 2>/dev/null || echo '0'); c_now=$(cat \"$dir/current_now\" 2>/dev/null || echo '0'); watt=$(awk -v v=\"$v_now\" -v c=\"$c_now\" 'BEGIN {printf \"%.1f\", (v*c)/1000000000000}'); fi; echo \"$cap:$stat:${watt}W\"; fi"
        ]
        stdout: SplitParser {
            onRead: data => {
                var trimmed = data.trim();
                if (!trimmed) return;
                var parts = trimmed.split(":");
                if (parts.length === 3) {
                    systemReadoutPanel.batteryPercent = parts[0] + "%";
                    systemReadoutPanel.batteryStatus = parts[1];
                    systemReadoutPanel.batteryPower = parts[2];
                }
            }
        }
    }

    // Helper formulas to safely extract numeric progress levels (0.0 to 1.0)
    readonly property real cpuValue: {
        var val = parseFloat(cpuData.cpuUsageStr);
        return isNaN(val) ? 0.0 : Math.min(1.0, Math.max(0.0, val / 100.0));
    }

    readonly property real gpuValue: {
        var val = parseFloat(gpuData.gpuUsageRaw);
        return isNaN(val) ? 0.0 : Math.min(1.0, Math.max(0.0, val / 100.0));
    }

    readonly property real batteryValue: parseFloat(batteryPercent) / 100.0

    // Free RAM/VRAM ratios (Starts at 1.0, empties to 0.0 as usage increases)
    readonly property real ramFreeValue: {
        if (ramData.totalGiB <= 0.0) return 1.0;
        return Math.min(1.0, Math.max(0.0, ramData.availableGiB / ramData.totalGiB));
    }

    readonly property real vramFreeValue: {
        var free = parseFloat(gpuData.gpuVramFreeRaw);
        if (isNaN(free) || systemReadoutPanel.totalVramGiB <= 0.0) return 1.0;
        return Math.min(1.0, Math.max(0.0, free / systemReadoutPanel.totalVramGiB));
    }

    // Standard Color Engine (for RAM/VRAM/Disk/Battery)
    function getMetricColor(ratio) {
        var pct = ratio * 100;
        if (pct <= 50) return shell.theme.base0C; // Green (#04f100)
        if (pct <= 85) return shell.theme.base09; // Orange (#FE8019)
        return shell.theme.base08;                 // Red (#FF0000)
    }

    // Temperature-Aware Color Engine (for CPU/GPU)
    function getTempAndUsageColor(usageRatio, tempStr) {
        var temp = parseFloat(tempStr);
        var usagePct = usageRatio * 100;

        // Critical status: Temp >= 80°C or Usage > 85%
        if (temp >= 80.0 || usagePct > 85.0) return shell.theme.base08; // Red

        // Warning status: Temp >= 70°C or Usage > 50%
        if (temp >= 70.0 || usagePct > 50.0) return shell.theme.base09; // Orange

        // Normal status
        return shell.theme.base0C; // Green
    }

    // Battery Color Engine (Inverted: Red when empty, Green when full)
    function getBatteryColor(ratio) {
        var pct = ratio * 100;
        if (pct <= 15) return shell.theme.base08; // Red (< 15% charge)
        if (pct <= 50) return shell.theme.base09; // Orange (< 50% charge)
        return shell.theme.base0C;                 // Green
    }

    // Realtime Clock
    Timer {
        id: panelClockTimer
        interval: 1000
        running: systemReadoutPanel.barWindow ? systemReadoutPanel.barWindow.visible : false
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var date = new Date()
            systemReadoutPanel.timeStr = date.toLocaleTimeString(Qt.locale(), "hh:mm:ss AP")
            systemReadoutPanel.dateStr = date.toLocaleDateString(Qt.locale(), "ddd, MMM d, yyyy")
        }
    }

    // Periodic Storage & Battery Poller (Updates safely every 10 seconds)
    Timer {
        id: slowMetricsTimer
        interval: 10000
        running: systemReadoutPanel.barWindow ? systemReadoutPanel.barWindow.visible : false
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            diskProc.running = false;
            diskProc.running = true;
            if (systemReadoutPanel.hasBattery) {
                batteryPollProc.running = false;
                batteryPollProc.running = true;
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: shell.theme.globalPadding
        spacing: shell.theme.globalPadding

        // Header
        Text {
            text: "SYSTEM READOUT"
            color: shell.theme.base04
            font.pixelSize: 16
            font.bold: true
            font.family: shell.theme.fontFamily
            font.letterSpacing: 1.5
        }

        // Clock section
        Column {
            spacing: 4
            Text {
                text: systemReadoutPanel.timeStr
                color: shell.theme.base05
                font.pixelSize: 32
                font.bold: true
                font.family: "JetBrains Mono"
            }
            Text {
                text: systemReadoutPanel.dateStr
                color: shell.theme.base04
                font.pixelSize: 16
                font.family: shell.theme.fontFamily
            }
        }

        // Divider line
        Rectangle {
            width: parent.width
            height: 2
            color: shell.theme.base02
        }

        // Capsule layout block
        Column {
            width: parent.width
            spacing: 20

            // 1. CPU Block (Standard Fills, Temp Aware)
            SystemCapsule {
                shell: systemReadoutPanel.shell
                label: "CPU"
                valueText: cpuData.cpuUsageStr + " (" + cpuData.cpuTempStr + ")"
                valColor: systemReadoutPanel.getTempAndUsageColor(systemReadoutPanel.cpuValue, cpuData.cpuTempStr)
                fillValue: systemReadoutPanel.cpuValue
            }

            // 2. GPU Block (Standard Fills, Temp Aware - Visible only if discrete GPU is present)
            SystemCapsule {
                shell: systemReadoutPanel.shell
                visible: systemReadoutPanel.hasGPU
                label: "GPU"
                valueText: gpuData.gpuUsageRaw + "% (" + gpuData.gpuTempRaw + "°C)"
                valColor: systemReadoutPanel.getTempAndUsageColor(systemReadoutPanel.gpuValue, gpuData.gpuTempRaw)
                fillValue: systemReadoutPanel.gpuValue
            }

            // 3. VRAM Block (Empties as consumed - Visible only if discrete GPU is present)
            SystemCapsule {
                shell: systemReadoutPanel.shell
                visible: systemReadoutPanel.hasGPU
                label: "VRAM"
                valueText: {
                    var freeVram = parseFloat(gpuData.gpuVramFreeRaw);
                    return (isNaN(freeVram) ? "0.0" : freeVram.toFixed(1)) + "G Reserves";
                }
                valColor: systemReadoutPanel.getMetricColor(1.0 - systemReadoutPanel.vramFreeValue)
                fillValue: systemReadoutPanel.vramFreeValue
            }

            // 4. RAM Block (Empties as memory is consumed)
            SystemCapsule {
                shell: systemReadoutPanel.shell
                label: "RAM"
                valueText: ramData.availableGiB.toFixed(1) + "G Reserves"
                valColor: systemReadoutPanel.getMetricColor(1.0 - systemReadoutPanel.ramFreeValue)
                fillValue: systemReadoutPanel.ramFreeValue
            }

            // 5. Disk Block (Empties as space fills)
            SystemCapsule {
                shell: systemReadoutPanel.shell
                label: "DISK"
                valueText: systemReadoutPanel.diskFreeStr + " Reserves"
                valColor: systemReadoutPanel.getMetricColor(1.0 - systemReadoutPanel.diskFreeValue)
                fillValue: systemReadoutPanel.diskFreeValue
            }

            // 6. Battery Block (Empties as battery drains - Visible only if battery hardware is present)
            SystemCapsule {
                shell: systemReadoutPanel.shell
                visible: systemReadoutPanel.hasBattery
                label: "BATTERY"
                valueText: {
                    var status = systemReadoutPanel.batteryStatus;
                    var shortStatus = status;
                    if (status === "Charging") shortStatus = "Charging";
                    else if (status === "Discharging") shortStatus = "Draw";
                    else if (status === "Full") shortStatus = "Full";
                    else if (status === "Not charging") shortStatus = "Idle";

                    return systemReadoutPanel.batteryPercent + " (" + systemReadoutPanel.batteryPower + " " + shortStatus + ")";
                }
                valColor: systemReadoutPanel.getBatteryColor(systemReadoutPanel.batteryValue)
                fillValue: systemReadoutPanel.batteryValue
            }
        }
    }
}
