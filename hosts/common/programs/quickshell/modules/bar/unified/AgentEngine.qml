// AgentEngine.qml
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: agentEngine

    property bool isRunning: false
    property bool isPaused: false
    property string statusLabel: "Idle"

    Timer {
        id: pollTimer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statusChecker.running = false;
            statusChecker.running = true;
        }
    }

    Process {
        id: statusChecker
        command: [
            "/run/current-system/sw/bin/bash", "-c",
            "RUNNING='false'; " +
            "if pgrep -f '[a]gent-worker' >/dev/null 2>&1; then RUNNING='true'; fi; " +
            "PAUSED='false'; " +
            "if [ \"$RUNNING\" = 'false' ] && [ -f /home/agent/workspace/.agent_state.json ]; then PAUSED='true'; fi; " +
            "echo \"$RUNNING $PAUSED\""
        ]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(" ");
                if (parts.length >= 2) {
                    agentEngine.isRunning = (parts[0] === "true");
                    agentEngine.isPaused = (parts[1] === "true");

                    if (agentEngine.isRunning) agentEngine.statusLabel = "Working";
                    else if (agentEngine.isPaused) agentEngine.statusLabel = "Paused";
                    else agentEngine.statusLabel = "Idle";
                }
            }
        }
    }
}
