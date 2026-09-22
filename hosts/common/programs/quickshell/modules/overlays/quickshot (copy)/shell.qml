// @pragma UseQApplication

import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: shellRoot

    // Ensure the screenshots directory exists before saving
    Process {
        running: true
        command: ["mkdir", "-p", ShotState.saveDir()]
    }

    // Smoke-test fallback when QUICKSHOT_SELFTEST=1
    Timer {
        running: Quickshell.env("QUICKSHOT_SELFTEST") === "1"
        interval: 5000
        onTriggered: Qt.quit()
    }

    Variants {
        model: Quickshell.screens

        ScreenOverlay {}
    }
}
