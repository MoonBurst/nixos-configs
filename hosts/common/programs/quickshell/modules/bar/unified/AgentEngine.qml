// AgentEngine.qml
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: agentEngine

    property bool isRunning: false
    property bool isPaused: false
    property string statusLabel: "Idle"

    // Poll status every 1.5 seconds
    Timer {
        id: pollTimer
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusChecker.running = true
    }

    Process {
        id: statusChecker
        command: [
            "/run/current-system/sw/bin/bash", "-c",
            "RUNNING=$(pgrep -f agent-worker >/dev/null && echo 'true' || echo 'false'); " +
            "PAUSED=$([ -f /home/agent/workspace/.agent_state.json ] && echo 'true' || echo 'false'); " +
            "echo \"$RUNNING $PAUSED\""
        ]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(" ");
                if (parts.length >= 2) {
                    agentEngine.isRunning = (parts[0] === "true");
                    // Only considered paused if the checkpoint file exists and process is NOT running
                    agentEngine.isPaused = (parts[1] === "true") && !agentEngine.isRunning;
                    
                    if (agentEngine.isRunning) agentEngine.statusLabel = "Working";
                    else if (agentEngine.isPaused) agentEngine.statusLabel = "Paused";
                    else agentEngine.statusLabel = "Idle";
                }
            }
        }
    }
}
