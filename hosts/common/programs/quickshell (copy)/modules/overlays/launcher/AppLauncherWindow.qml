import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../common" as Common
import "./backend" as Backend
import "./frontend" as Frontend

Common.OverlayWindow {
    id: launcherWindow

    windowId: "launcher"
    defaultW: 840
    defaultH: 700
    defaultPolicy: "eager"

    Backend.AppLauncherEngine { id: launcherEngine }

    onPreShow: launcherEngine.scan()

    // Route a launcher request to another overlay or launch a binary.
    // Called from AppLauncherView via onRouteRequested.
    function routeTo(target, param) {
        launcherWindow.close();
        if (safeShell) {
            switch (target) {
                case "settings": if (safeShell.settingsWindow) safeShell.settingsWindow.open(); return;
                case "clipboard": if (safeShell.clipboardWindow) safeShell.clipboardWindow.open(); return;
                case "calc": if (safeShell.calcWindow) safeShell.calcWindow.open(param); return;
                case "todo": if (safeShell.todoWindow) safeShell.todoWindow.open(); return;
                case "email": if (safeShell.emailWindow) safeShell.emailWindow.open(); return;
                case "dictionary": if (safeShell.dictionaryWindow) safeShell.dictionaryWindow.open(param); return;
                case "rng": if (safeShell.diceRollerWindowInstance) safeShell.diceRollerWindowInstance.openWithTarget(); return;
                case "pass": if (safeShell.passWindow) safeShell.passWindow.open(param); return;
                case "notes": if (safeShell.notesWindow) safeShell.notesWindow.open(param); return;
                case "power": if (safeShell.powerWindow) safeShell.powerWindow.open(); return;
                case "gemini": if (safeShell.geminiWindow) { safeShell.geminiWindow.open(); if (param) safeShell.geminiWindow.sendMessage(param); } return;
                case "unicode": if (safeShell.unicodeWindow) safeShell.unicodeWindow.open(); return;
                case "web": if (safeShell.startPageWindow) safeShell.startPageWindow.open(param); return;
                case "amogus": if (safeShell.amogusWindowInstance) safeShell.amogusWindowInstance.showWindow(); return;
            }
        }

        // Fallback: launch a raw binary detached from the shell so it
        // survives a quickshell restart.
        if (target && target !== "sh" && !target.includes(":") && !target.includes("apps")) {
            Quickshell.execDetached([
                "sh", "-c",
                'if command -v systemd-run >/dev/null 2>&1; then\n' +
                '    systemd-run --user --collect --quiet --slice=app.slice sh -c "$1"\n' +
                'elif command -v swaymsg >/dev/null 2>&1; then\n' +
                '    swaymsg exec -- "$1"\n' +
                'else\n' +
                '    setsid -f sh -c "$1"\n' +
                'fi',
                "launcher-exec", target + " " + (param || "")
            ]);
            return;
        }

        Quickshell.execDetached([
            "sh", "-c",
            'QS=$(command -v qs || command -v quickshell); [ -n "$QS" ] && "$QS" ipc call "$1" open "$2"',
            "sh", target, param || ""
        ]);
    }

    viewComponent: Component {
        Frontend.AppLauncherView {
            engine: launcherEngine
            theme: launcherWindow.theme
            settingsManager: launcherWindow.settingsManager
            onCompleted: launcherWindow.close()
            onRouteRequested: (target, param) => launcherWindow.routeTo(target, param)
        }
    }
}
