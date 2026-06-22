// modules/overlays/launcher/BatteryEngine.qml
import QtQuick
import Quickshell.Io

Item {
    id: engine

    // Exposed interface properties for the parent view to bind to
    property bool hasBattery: false
    property string batteryName: ""
    property string percent: "0%"
    property string status: "Unknown"
    property string power: "0.0W"
    
    // Normalized charge value (0.0 to 1.0)
    readonly property real value: {
        var val = parseFloat(percent);
        return isNaN(val) ? 1.0 : Math.min(1.0, Math.max(0.0, val / 100.0));
    }

    // Cleaned up status output for UI fit
    readonly property string shortStatus: {
        if (status === "Charging") return "Charging";
        if (status === "Discharging") return "Draw";
        if (status === "Full") return "Full";
        if (status === "Not charging") return "Idle";
        return status;
    }

    // Startup Battery Detector (Searches for devices starting with BAT or sb)
    Process {
        id: detectProc
        running: true
        command: ["sh", "-c", "ls /sys/class/power_supply/ 2>/dev/null | grep -E '^BAT|^sb' | head -n 1"]
        stdout: SplitParser {
            onRead: data => {
                var name = data.trim();
                if (name !== "") {
                    engine.batteryName = name;
                    engine.hasBattery = true;
                    pollProc.running = true; // Trigger first metrics read
                }
            }
        }
    }

    // Process to pull battery capacity, status, and power draw (microwatts or microvolts*microamps)
    Process {
        id: pollProc
        running: false
        command: [
            "sh", "-c",
            "dir=/sys/class/power_supply/" + engine.batteryName + "; if [ -d \"$dir\" ]; then cap=$(cat \"$dir/capacity\" 2>/dev/null || echo '0'); stat=$(cat \"$dir/status\" 2>/dev/null || echo 'Unknown'); watt='0.0'; if [ -f \"$dir/power_now\" ]; then p_now=$(cat \"$dir/power_now\" 2>/dev/null || echo '0'); watt=$(awk -v p=\"$p_now\" 'BEGIN {printf \"%.1f\", p/1000000}'); elif [ -f \"$dir/voltage_now\" ] && [ -f \"$dir/current_now\" ]; then v_now=$(cat \"$dir/voltage_now\" 2>/dev/null || echo '0'); c_now=$(cat \"$dir/current_now\" 2>/dev/null || echo '0'); watt=$(awk -v v=\"$v_now\" -v c=\"$c_now\" 'BEGIN {printf \"%.1f\", (v*c)/1000000000000}'); fi; echo \"$cap:$stat:${watt}W\"; fi"
        ]
        stdout: SplitParser {
            onRead: data => {
                var trimmed = data.trim();
                if (!trimmed) return;
                var parts = trimmed.split(":");
                if (parts.length === 3) {
                    engine.percent = parts[0] + "%";
                    engine.status = parts[1];
                    engine.power = parts[2];
                }
            }
        }
    }

    // Polling Timer (Ticks safely every 10 seconds, only if a battery device is active)
    Timer {
        id: pollTimer
        interval: 10000
        running: engine.hasBattery
        repeat: true
        onTriggered: {
            pollProc.running = false;
            pollProc.running = true;
        }
    }
}
