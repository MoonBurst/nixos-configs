// GameSentinel.qml
import QtQuick
import Quickshell
import Quickshell.Io
import "../../common" as Common

Item {
    id: gameSentinel

    property bool isGaming: false
    property bool isStormHold: false
    property bool autoPausedSync: false

    Process {
        id: pauseProc
        command: ["sudo", "-n", "game-sync-pause"]
        onExited: (code) => {
            if (code !== 0) {
                Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-u", "critical", "Sudoers Missing", "NOPASSWD required for game-sync-pause"]);
            }
        }
    }
    Process { id: resumeProc; command: ["sudo", "-n", "game-sync-resume"] }

    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: gamingProcess.running = true
    }

    Process {
        id: gamingProcess
        command: Common.LuaRunner.cmd("modules/bar/unified/backend/GameSentinel.lua")
        stdout: SplitParser {
            onRead: data => {
                try {
                    const g = JSON.parse(data.trim());
                    let wasHeld = (gameSentinel.isGaming || gameSentinel.isStormHold);
                    gameSentinel.isGaming = (g.gaming === true);
                    gameSentinel.isStormHold = (g.storm === true);

                    let shouldHold = (gameSentinel.isGaming || gameSentinel.isStormHold);

                    if (!wasHeld && shouldHold) {
                        gameSentinel.autoPausedSync = true;
                        pauseProc.running = false;
                        pauseProc.running = true;
                    } else if (wasHeld && !shouldHold && gameSentinel.autoPausedSync) {
                        gameSentinel.autoPausedSync = false;
                        resumeProc.running = false;
                        resumeProc.running = true;
                    }
                } catch (e) {}
            }
        }
    }
}
