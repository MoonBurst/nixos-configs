// BorgSyncEngine.qml
import QtQuick
import Quickshell
import Quickshell.Io
import "../../common" as Common
import "../../common/Utils.js" as Utils

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
        return Utils.formatBytes(mbVal * 1048576, 1);
    }

    function formatDetailedMb(mbVal) {
        return Utils.formatBytes(mbVal * 1048576, 1);
    }

    Timer {
        interval: borgEngine.serviceActive ? 2000 : 10000
        running: true
        repeat: true
        onTriggered: borgProcess.running = true
    }

    Process {
        id: borgProcess
        command: Common.LuaRunner.cmd("modules/bar/unified/backend/BorgSyncEngine.lua")
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
