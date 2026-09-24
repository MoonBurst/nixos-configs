import QtQuick
import Quickshell
import Quickshell.Io

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
        interval: 1000
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
        command: [
            "/run/current-system/sw/bin/bash", "-c",
            "REC=0; [ -f /tmp/record-region.pid ] && kill -0 $(cat /tmp/record-region.pid 2>/dev/null) 2>/dev/null && REC=1; " +
            "if [ $REC -eq 0 ]; then pgrep -x wf-recorder >/dev/null 2>&1 && REC=1; fi; " +
            "STREAM=0; [ -f /tmp/twitch-stream.pid ] && kill -0 $(cat /tmp/twitch-stream.pid 2>/dev/null) 2>/dev/null && STREAM=1; " +
            "if [ $STREAM -eq 0 ]; then pgrep -f '[r]tmp://live.twitch.tv' >/dev/null 2>&1 && STREAM=1; fi; " +
            "echo \"$REC $STREAM\""
        ]
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

    function stopAll() {
        Quickshell.execDetached([
            "/run/current-system/sw/bin/bash", "-c",
            "twitch-stream || record-region || pkill -SIGINT -f 'wf-recorder.*Region_' || pkill -f 'gpu-screen-recorder.*rtmp'"
        ]);
    }
}
