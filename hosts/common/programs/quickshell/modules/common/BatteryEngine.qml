import QtQuick
import Quickshell.Io

Item {
    id: engine

    property bool hasBattery: false
    property string batteryName: ""
    property string percent: "0%"
    property string status: "Unknown"
    property string power: "0.0W"

    readonly property real value: {
        var val = parseFloat(percent);
        return isNaN(val) ? 1.0 : Math.min(1.0, Math.max(0.0, val / 100.0));
    }

    readonly property string shortStatus: {
        if (status === "Charging") return "Charging";
        if (status === "Discharging") return "Draw";
        if (status === "Full") return "Full";
        if (status === "Not charging") return "Idle";
        return status;
    }

    function applyPollLine(line) {
        var parts = (line || "").trim().split(":");
        if (parts.length !== 3) return;
        if (parts[0] === "--") return;
        engine.percent = parts[0] + "%";
        engine.status = parts[1];
        engine.power = parts[2];
    }

    Process {
        id: detectProc
        running: true
        command: LuaRunner.cmd("modules/common/backend/BatteryEngine.lua", "detect")
        stdout: SplitParser {
            onRead: data => {
                var name = (data || "").trim();
                if (name !== "") {
                    engine.batteryName = name;
                    engine.hasBattery = true;
                    powerEventListener.running = true;
                    engine.refresh();
                }
            }
        }
    }

    // Kernel events (instant power-draw/plug updates)
    Process {
        id: powerEventListener
        running: false
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=power_supply"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: engine.refresh()
        }
    }

    // Fallback so we never go stale if udev misses an event
    Timer {
        interval: 30000
        running: engine.hasBattery
        repeat: true
        onTriggered: engine.refresh()
    }

    Process {
        id: pollProc
        command: LuaRunner.cmd("modules/common/backend/BatteryEngine.lua", "poll", engine.batteryName)
        stdout: SplitParser { onRead: engine.applyPollLine(data) }
    }

    function refresh() {
        if (!engine.hasBattery) return;
        pollProc.running = false;
        pollProc.running = true;
    }
}
