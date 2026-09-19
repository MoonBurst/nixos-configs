// PodmanTwitchEngine.qml
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: twitchEngine

    property bool mainRunning: false
    property bool berryRunning: false
    property string mainWatching: ""
    property string berryWatching: ""
    property string mainClaim: ""
    property string berryClaim: ""
    property bool mainError: false
    property bool berryError: false

    property double lastMainRestart: 0
    property double lastBerryRestart: 0
    // Backoff cooldown: 5 minutes between auto-restarts to prevent spam
    readonly property double restartCooldown: 300000

    signal commandRequested(string cmd)

    Timer {
        interval: 15000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: twitchProc.running = true
    }

    Process {
        id: twitchProc
        command: [
            "/run/current-system/sw/bin/bash", "-c",
            "MAIN_RUNNING=$(systemctl is-active podman-twitch-miner.service 2>/dev/null | grep -q 'active' && echo 1 || echo 0); " +
            "BERRY_RUNNING=$(systemctl is-active podman-twitchminer-berrydrop.service 2>/dev/null | grep -q 'active' && echo 1 || echo 0); " +
            "MAIN_LOGS=\"\"; BERRY_LOGS=\"\"; " +
            "[ \"$MAIN_RUNNING\" -eq 1 ] && MAIN_LOGS=$(journalctl -u podman-twitch-miner.service -n 15 --no-pager -o cat 2>/dev/null); " +
            "[ \"$BERRY_RUNNING\" -eq 1 ] && BERRY_LOGS=$(journalctl -u podman-twitchminer-berrydrop.service -n 15 --no-pager -o cat 2>/dev/null); " +
            "MAIN_FINISHED=$(echo \"$MAIN_LOGS\" | tail -n 8 | grep -iqE \"Exiting|All drops claimed|No active campaigns|No channels available|Idle\" && echo 1 || echo 0); " +
            "BERRY_FINISHED=$(echo \"$BERRY_LOGS\" | tail -n 8 | grep -iqE \"Exiting|All drops claimed|No active campaigns|No channels available|Idle\" && echo 1 || echo 0); " +
            "MAIN_WATCHING=$(echo \"$MAIN_LOGS\" | grep -i \"Watching:\" | tail -n 1 | awk '{print $NF}'); " +
            "BERRY_WATCHING=$(echo \"$BERRY_LOGS\" | grep -i \"Watching:\" | tail -n 1 | awk '{print $NF}'); " +
            "[ \"$MAIN_FINISHED\" -eq 1 ] && MAIN_WATCHING=\"\"; " +
            "[ \"$BERRY_FINISHED\" -eq 1 ] && BERRY_WATCHING=\"\"; " +
            "MAIN_CLAIM=$(echo \"$MAIN_LOGS\" | grep -i \"Claimed drop:\" | tail -n 1 | sed 's/.*Claimed drop: //' | cut -c 1-35); " +
            "BERRY_CLAIM=$(echo \"$BERRY_LOGS\" | grep -i \"Claimed drop:\" | tail -n 1 | sed 's/.*Claimed drop: //' | cut -c 1-35); " +
            "MAIN_ERR=$(echo \"$MAIN_LOGS\" | tail -n 5 | grep -iqE \"401 Unauthorized|403 Forbidden|rate limit|integrity check failed\" && echo 1 || echo 0); " +
            "BERRY_ERR=$(echo \"$BERRY_LOGS\" | tail -n 5 | grep -iqE \"401 Unauthorized|403 Forbidden|rate limit|integrity check failed\" && echo 1 || echo 0); " +
            "echo '{\"main_running\": '$MAIN_RUNNING', \"berry_running\": '$BERRY_RUNNING', \"main_watching\": \"'$MAIN_WATCHING'\", \"berry_watching\": \"'$BERRY_WATCHING'\", \"main_claim\": \"'$MAIN_CLAIM'\", \"berry_claim\": \"'$BERRY_CLAIM'\", \"main_err\": '$MAIN_ERR', \"berry_err\": '$BERRY_ERR'}'"
        ]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const obj = JSON.parse(data.trim())
                    twitchEngine.mainRunning = (obj.main_running === 1);
                    twitchEngine.berryRunning = (obj.berry_running === 1);
                    twitchEngine.mainWatching = obj.main_watching || "";
                    twitchEngine.berryWatching = obj.berry_watching || "";
                    twitchEngine.mainClaim = obj.main_claim || "";
                    twitchEngine.berryClaim = obj.berry_claim || "";
                    twitchEngine.mainError = (obj.main_err === 1);
                    twitchEngine.berryError = (obj.berry_err === 1);

                    let now = Date.now();
                    if (twitchEngine.mainError && (now - twitchEngine.lastMainRestart > twitchEngine.restartCooldown)) {
                        twitchEngine.lastMainRestart = now;
                        twitchEngine.commandRequested("sudo -n /run/current-system/sw/bin/podman restart twitch-miner");
                    }
                    if (twitchEngine.berryError && (now - twitchEngine.lastBerryRestart > twitchEngine.restartCooldown)) {
                        twitchEngine.lastBerryRestart = now;
                        twitchEngine.commandRequested("sudo -n /run/current-system/sw/bin/podman restart twitchminer-berrydrop");
                    }
                } catch (e) {}
            }
        }
    }
}
