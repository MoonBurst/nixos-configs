import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: sysHealth

    property var failedUnits: []
    property int failedCount: 0
    property int diskRootPercent: 0
    property int diskBackupPercent: 0
    property bool diskWarning: false
    property int nixGenerations: 0
    property string runningKernel: ""
    property string latestKernel: ""
    property bool rebootRequired: false
    property int gitUncommitted: 0
    property int flakeAgeDays: 0

    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: fastHealthProc.running = true
    }

    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: slowHealthProc.running = true
    }

    Process {
        id: fastHealthProc
        command: [
            "bash", "-c",
            "SYS_FAILED=$(systemctl --failed --plain --no-legend 2>/dev/null | awk '{print $1}' | grep -v 'sync-backup-to-nextcloud' | tr '\\n' ' '); " +
            "USER_FAILED=$(systemctl --user --failed --plain --no-legend 2>/dev/null | awk '{print \"user:\" $1}' | tr '\\n' ' '); " +
            "ROOT_USAGE=$(df --output=pcent / 2>/dev/null | tail -n 1 | tr -dc '0-9'); " +
            "BACKUP_USAGE=$(df --output=pcent /mnt/main_backup 2>/dev/null | tail -n 1 | tr -dc '0-9'); " +
            "echo \"FAILED:${SYS_FAILED}${USER_FAILED}::ROOT:${ROOT_USAGE:-0}::BACKUP:${BACKUP_USAGE:-0}\""
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("::");
                var failedList = [];
                var rootP = 0;
                var backupP = 0;
                for (var i = 0; i < parts.length; i++) {
                    var p = parts[i];
                    if (p.startsWith("FAILED:")) {
                        var fStr = p.substring(7).trim();
                        if (fStr) failedList = fStr.split(/\s+/).filter(x => x.length > 0);
                    } else if (p.startsWith("ROOT:")) {
                        rootP = parseInt(p.substring(5)) || 0;
                    } else if (p.startsWith("BACKUP:")) {
                        backupP = parseInt(p.substring(7)) || 0;
                    }
                }
                sysHealth.failedUnits = failedList;
                sysHealth.failedCount = failedList.length;
                sysHealth.diskRootPercent = rootP;
                sysHealth.diskBackupPercent = backupP;
                sysHealth.diskWarning = (rootP >= 90 || backupP >= 90);
            }
        }
    }

    Process {
        id: slowHealthProc
        command: ["lua", Quickshell.shellDir + "/modules/bar/unified/backend/SysHealthEngine.lua"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const h = JSON.parse(data.trim());
                    sysHealth.nixGenerations = h.gens || 0;
                    sysHealth.runningKernel = h.cur_k || "";
                    sysHealth.latestKernel = h.sys_k || "";
                    sysHealth.rebootRequired = (h.reboot === 1);
                    sysHealth.gitUncommitted = h.git_dirty || 0;
                    sysHealth.flakeAgeDays = h.flake_age || 0;
                } catch (e) {}
            }
        }
    }
}
