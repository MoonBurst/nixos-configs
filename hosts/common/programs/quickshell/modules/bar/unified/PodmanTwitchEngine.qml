import QtQuick
import Quickshell
import Quickshell.Io
import "../../common" as Common

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
    readonly property double restartCooldown: 300000

    signal commandRequested(string cmd)

    Timer {
        interval: 15000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: twitchProc.running = true
    }

    Process {
        id: twitchProc
        command: Common.LuaRunner.cmd("/modules/bar/unified/backend/PodmanTwitchEngine.lua")
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
                        twitchEngine.commandRequested("sudo -n podman restart twitch-miner");
                    }
                    if (twitchEngine.berryError && (now - twitchEngine.lastBerryRestart > twitchEngine.restartCooldown)) {
                        twitchEngine.lastBerryRestart = now;
                        twitchEngine.commandRequested("sudo -n podman restart twitchminer-berrydrop");
                    }
                } catch (e) {}
            }
        }
    }
}
