// BorgSyncEngine.qml
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: borgEngine

    property string status: "idle"
    property int percent: 0
    property string speed: "0 MB/s"
    property string remaining: ""
    property string eta: ""
    property bool serviceActive: false
    property bool isMounted: false
    property string progressLabel: "Idle"

    function formatCompactMb(mbVal) {
        if (isNaN(mbVal) || mbVal <= 0) return "0M";
        if (mbVal >= 1024) return (mbVal / 1024).toFixed(1) + "G";
        return Math.round(mbVal) + "M";
    }

    function formatDetailedMb(mbVal) {
        if (isNaN(mbVal) || mbVal <= 0) return "0 MB";
        if (mbVal >= 1024) return (mbVal / 1024).toFixed(1) + " GB";
        return Math.round(mbVal) + " MB";
    }

    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: borgProcess.running = true
    }

    Process {
        id: borgProcess
        command: [
            "/run/current-system/sw/bin/bash", "-c",
            "STATUS_JSON=$(cat /dev/shm/borg-offsite-status.json 2>/dev/null || echo '{\"status\": \"idle\"}'); " +
            "IS_ACTIVE=$(systemctl is-active sync-backup-to-nextcloud.service 2>/dev/null | tr -d '[:space:]'); " +
            "IS_MOUNTED=$(mount | grep -q '/tmp/borg-mount' && echo 1 || echo 0); " +
            "[ -z \"$IS_ACTIVE\" ] && IS_ACTIVE='inactive'; " +
            "echo \"$STATUS_JSON\" | jq -c --arg is_act \"$IS_ACTIVE\" --arg is_mnt \"$IS_MOUNTED\" '. + {service_active: ($is_act == \"active\" or $is_act == \"activating\"), mounted: ($is_mnt == \"1\")}'"
        ]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const obj = JSON.parse(data.trim())
                    borgEngine.status = obj.status || "idle"
                    borgEngine.percent = obj.percent || 0
                    borgEngine.speed = obj.speed || "0 MB/s"
                    borgEngine.eta = (obj.eta && obj.eta !== "Calculating...") ? obj.eta : ""
                    borgEngine.serviceActive = (obj.service_active === true)
                    borgEngine.isMounted = (obj.mounted === true)

                    let total = parseFloat(obj.total_size) || 0;
                    let uploaded = parseFloat(obj.uploaded_size) || 0;
                    let remVal = Math.max(0, total - uploaded);

                    borgEngine.remaining = borgEngine.formatDetailedMb(remVal);

                    if (borgEngine.status === "running") {
                        borgEngine.progressLabel = "Borg " + obj.percent + "%";
                    } else if (borgEngine.serviceActive) {
                        if (obj.status === "syncing" && borgEngine.speed !== "0 MB/s") {
                            borgEngine.progressLabel = borgEngine.formatCompactMb(remVal) + " (" + obj.percent + "%)";
                        } else {
                            borgEngine.progressLabel = "Resuming...";
                        }
                    } else if (!borgEngine.serviceActive && borgEngine.remaining !== "0 MB" && borgEngine.remaining !== "") {
                        borgEngine.progressLabel = "Paused";
                    } else if (obj.status === "indexing") {
                        borgEngine.progressLabel = "Indexing";
                    } else {
                        borgEngine.progressLabel = "Idle";
                    }
                } catch (e) {
                    borgEngine.status = "idle";
                }
            }
        }
    }
}
