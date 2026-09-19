// SysHealthEngine.qml
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
        interval: 3000; running: true; repeat: true
        onTriggered: fastHealthProc.running = true
    }

    Process {
        id: fastHealthProc
        command: [
            "/run/current-system/sw/bin/bash", "-c",
            "SYS_FAILED=$(systemctl --failed --plain --no-legend 2>/dev/null | awk '{print $1}' | grep -v 'sync-backup-to-nextcloud'); " +
            "USER_FAILED=$(systemctl --user --failed --plain --no-legend 2>/dev/null | awk '{print \"user:\" $1}'); " +
            "ALL_FAILED=$(echo -e \"$SYS_FAILED\n$USER_FAILED\" | jq -R -s -c 'split(\"\n\") | map(select(length > 0))'); " +
            "ROOT_USAGE=$(df --output=pcent / 2>/dev/null | tail -n 1 | tr -dc '0-9'); " +
            "BACKUP_USAGE=$(df --output=pcent /mnt/main_backup 2>/dev/null | tail -n 1 | tr -dc '0-9'); " +
            "[ -z \"$ROOT_USAGE\" ] && ROOT_USAGE=0; [ -z \"$BACKUP_USAGE\" ] && BACKUP_USAGE=0; " +
            "GEN_COUNT=$(find /nix/var/nix/profiles/ -maxdepth 1 -name 'system-*-link' 2>/dev/null | wc -l); " +
            "[ \"$GEN_COUNT\" -eq 0 ] && GEN_COUNT=$(nix-env --list-generations -p /nix/var/nix/profiles/system 2>/dev/null | wc -l); " +
            "CUR_KERNEL=$(uname -r); SYS_KERNEL=$(ls /run/current-system/kernel-modules/lib/modules 2>/dev/null | head -n 1); " +
            "[ -z \"$SYS_KERNEL\" ] && SYS_KERNEL=\"$CUR_KERNEL\"; " +
            "REBOOT_REQ=$([ \"$CUR_KERNEL\" != \"$SYS_KERNEL\" ] && echo 1 || echo 0); " +
            "GIT_DIRTY=$(git -C /home/moonburst/nix status --porcelain 2>/dev/null | wc -l); " +
            "FLAKE_FILE='/home/moonburst/nix/flake.lock'; FLAKE_AGE=0; " +
            "[ -f \"$FLAKE_FILE\" ] && FLAKE_AGE=$(( ($(date +%s) - $(stat -c %Y \"$FLAKE_FILE\")) / 86400 )); " +
            "echo '{\"failed\": '$ALL_FAILED', \"root_pcent\": '$ROOT_USAGE', \"backup_pcent\": '$BACKUP_USAGE', \"gens\": '$GEN_COUNT', \"cur_k\": \"'$CUR_KERNEL'\", \"sys_k\": \"'$SYS_KERNEL'\", \"reboot\": '$REBOOT_REQ', \"git_dirty\": '$GIT_DIRTY', \"flake_age\": '$FLAKE_AGE'}'"
        ]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const h = JSON.parse(data.trim());
                    sysHealth.failedUnits = h.failed || [];
                    sysHealth.failedCount = sysHealth.failedUnits.length;
                    sysHealth.diskRootPercent = h.root_pcent || 0;
                    sysHealth.diskBackupPercent = h.backup_pcent || 0;
                    sysHealth.diskWarning = (sysHealth.diskRootPercent >= 90 || sysHealth.diskBackupPercent >= 90);
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
