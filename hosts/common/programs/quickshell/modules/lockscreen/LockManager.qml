import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam
import "../common" as Common

Item {
    id: lockManager

    required property var shell

    property string activePamService: "login"
    property string globalPasswordBuffer: ""
    property int passwordLength: 0

    property alias lockPam: lockPam
    property alias sessionLock: sessionLock

    readonly property string secondaryMode: (shell && shell.settingsManager && shell.settingsManager.lockSecondaryScreenMode)
    ? shell.settingsManager.lockSecondaryScreenMode
    : "mirror"

    Process {
        id: dpmsController
        running: false
        function setSecondaryPower(powerOn) {
            var primaryName = (lockManager.shell && lockManager.shell.primaryScreen) ? lockManager.shell.primaryScreen.name : "";
            command = Common.LuaRunner.cmd("modules/lockscreen/backend/LockEngine.lua", primaryName, powerOn ? "on" : "off");
            running = false;
            running = true;
        }
    }

    Process {
        id: pamServiceDetector
        running: true
        command: ["sh", "-c", "[ -f /etc/pam.d/quickshell ] && echo 'quickshell' || echo 'login'"]
        stdout: SplitParser {
            onRead: data => { if (data && data.trim()) lockManager.activePamService = data.trim(); }
        }
    }

    PamContext {
        id: lockPam
        config: lockManager.activePamService
        user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
        onResponseRequiredChanged: {
            if (responseRequired) {
                lockPam.respond(lockManager.globalPasswordBuffer);
            }
        }
        onCompleted: (result) => {
            if (result === PamResult.Success) {
                sessionLock.locked = false;
                lockManager.globalPasswordBuffer = "";
                lockManager.passwordLength = 0;
            } else {
                lockManager.globalPasswordBuffer = "";
                lockManager.passwordLength = -1;
            }
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false
        onLockedChanged: {
            lockManager.globalPasswordBuffer = "";
            lockManager.passwordLength = 0;

            if (locked) {
                if (lockManager.secondaryMode === "off") {
                    dpmsController.setSecondaryPower(false);
                }
            } else {
                dpmsController.setSecondaryPower(true);
            }
        }
        surface: Component {
            LockScreen {
                lockSession: sessionLock
                rootRef: lockManager.shell
            }
        }
    }

    IpcHandler {
        id: lockscreenHandler
        target: "lockscreen"
        function lock(): void { sessionLock.locked = true; }
        function unlock(): void { sessionLock.locked = false; }
    }
}
