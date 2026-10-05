import QtQuick
import Quickshell
import Quickshell.Io
import "../../common" as Common

// Front-end facade for RecordingEngine.lua. Polls the lua backend on a
// cadence that adapts to whether capture is active, and exposes the same
// public properties the UnifiedMonitor relies on.
Item {
    id: recordingEngine

    property bool isRecording: false
    property bool isStreaming: false
    readonly property bool isActive: isRecording || isStreaming

    property string statusLabel: {
        if (isRecording && isStreaming) return "Rec + Live";
        if (isStreaming) return "Live Twitch";
        if (isRecording) return "Recording";
        return "Idle";
    }

    Timer {
        interval: recordingEngine.isActive ? 1000 : 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            checkProc.running = false;
            checkProc.running = true;
        }
    }

    Process {
        id: checkProc
        command: Common.LuaRunner.cmd("modules/bar/unified/backend/RecordingEngine.lua")
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(" ");
                if (parts.length >= 2) {
                    recordingEngine.isRecording = (parts[0] === "1");
                    recordingEngine.isStreaming = (parts[1] === "1");
                }
            }
        }
    }

    // Stop-all is a one-shot action, still handled by the existing external
    // commands. These are user-triggered (rare) so forking a shell here is
    // fine; no polling.
    function stopAll() {
        Quickshell.execDetached([
            "bash", "-c",
            "twitch-stream || record-region || pkill -SIGINT -f 'wf-recorder.*Region_' || pkill -f 'gpu-screen-recorder.*rtmp'"
        ]);
    }
}
