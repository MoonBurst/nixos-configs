//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import QtQuick

// Quickshot — a region-selection screenshot tool with annotation, built on
// Quickshell + Qt Quick. One frozen-frame overlay is created per monitor; the
// user drags a region, annotates it, then copies or saves it.
ShellRoot {
    id: shellRoot

    // Make sure the screenshots directory exists before anyone tries to save.
    Process {
        running: true
        command: ["mkdir", "-p", ShotState.saveDir()]
    }

    // Smoke-test fallback: when QUICKSHOT_SELFTEST=1, ScreenOverlay scripts a
    // full capture→annotate→export run and quits itself. This timer only fires
    // if capture never completes, so the test can never hang.
    Timer {
        running: Quickshell.env("QUICKSHOT_SELFTEST") === "1"
        interval: 5000
        onTriggered: Qt.quit()
    }

    Variants {
        // One overlay per connected screen.
        model: Quickshell.screens

        ScreenOverlay {}
    }
}
