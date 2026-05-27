pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

import "modules/lockscreen"

ShellRoot {
    id: root

    Timer {
        id: safetyNet
        interval: 10000
        running: true
        repeat: false
        onTriggered: {
            console.log("SAFETY TRIGGERED: Automatically unlocking screen...");
            sessionLock.locked = false;
            Qt.quit();
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: true

        // Let the surface factory handle instantiation loops across files cleanly
        surface: Component {
            LockScreen {
                globalTimer: safetyNet
                lockSession: sessionLock
            }
        }
    }
}
