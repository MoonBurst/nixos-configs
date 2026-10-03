import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../" as RootTheme
import "./backend" as Backend
import "./frontend" as Frontend

PanelWindow {
    id: launcherWindow

    property string windowId: "launcher"
    readonly property string defaultPolicy: "eager"

    property var shell: null
    readonly property var safeShell: (typeof shell !== "undefined" && shell) ? shell : null
    readonly property var settingsManager: safeShell ? safeShell.settingsManager : null
    readonly property var theme: (safeShell && safeShell.theme) ? safeShell.theme : fallbackTheme
    RootTheme.Theme { id: fallbackTheme }

    readonly property string loadPolicy: settingsManager ? settingsManager.getWindowLoadPolicy(windowId, defaultPolicy) : defaultPolicy
    readonly property bool shouldKeepLoaded: loadPolicy === "eager"

    screen: (safeShell && safeShell.primaryScreen) ? safeShell.primaryScreen : (Quickshell.screens[0] || null)

    readonly property bool isPreviewMode: (settingsManager && settingsManager.previewWindow === windowId)
    property bool isOpenState: false
    visible: isOpenState || isPreviewMode

    property bool isCardActive: true

    // Focused: base03 | Off-focus: base0D
    readonly property color activeBorderColor: (theme && theme.base03) ? theme.base03 : "#003399"
    readonly property color inactiveBorderColor: (theme && theme.base0D) ? theme.base0D : "#003399"

    property bool inGracePeriod: false
    Timer {
        id: graceTimer
        repeat: false
        onTriggered: { launcherWindow.inGracePeriod = false; }
    }

    onIsOpenStateChanged: {
        if (isOpenState) {
            graceTimer.stop();
            inGracePeriod = false;
        } else if (!isPreviewMode) {
            var timeoutSec = settingsManager ? settingsManager.overlayGraceTimeoutSec : 10;
            if (timeoutSec > 0 && !shouldKeepLoaded) {
                inGracePeriod = true;
                graceTimer.interval = timeoutSec * 1000;
                graceTimer.restart();
            } else {
                inGracePeriod = false;
            }
        }
    }

    readonly property bool isUiActive: shouldKeepLoaded || isOpenState || isPreviewMode || inGracePeriod

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (viewLoader.item && typeof viewLoader.item.clearAndFocus === "function") {
                viewLoader.item.clearAndFocus();
            }
        }
    }

    onVisibleChanged: {
        if (visible && !isPreviewMode) {
            if (safeShell && typeof safeShell.closeOtherOverlays === "function") {
                safeShell.closeOtherOverlays(launcherWindow);
            }
            launcherWindow.isCardActive = true;
            launcherEngine.scan();
            focusTimer.restart();
        }
    }

    WlrLayershell.namespace: "quickshell-applauncher"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        return launcherWindow.isCardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: launcherWindow.isCardActive ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: card }

    function open() {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        launcherWindow.isCardActive = true;
        isOpenState = true;
        focusTimer.restart();
    }

    function activateCard() {
        launcherWindow.isCardActive = true;
        focusTimer.restart();
    }

    function close() {
        isOpenState = false;
        launcherWindow.isCardActive = false;
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }

    function toggle() { if (isOpenState) close(); else open(); }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcherWindow.toggle(); }
        function open(): void { launcherWindow.open(); }
        function close(): void { launcherWindow.close(); }
    }

    // Background listener for Escape: catches Escape globally while Launcher is open, even when unfocused
    Process {
        id: escWatcher
        running: launcherWindow.isOpenState && !launcherWindow.isPreviewMode
        command: [
            "python3", "-u", "-c",
            "import glob, struct, select, sys\n" +
            "fds = []\n" +
            "for dev in glob.glob('/dev/input/by-id/*-event-kbd') + glob.glob('/dev/input/event*'):\n" +
            "    try:\n" +
            "        fds.append(open(dev, 'rb', buffering=0))\n" +
            "    except Exception:\n" +
            "        pass\n" +
            "if not fds:\n" +
            "    sys.exit(0)\n" +
            "fmt = 'llHHi' if struct.calcsize('l') == 8 else 'iiHHi'\n" +
            "sz = struct.calcsize(fmt)\n" +
            "while True:\n" +
            "    r, _, _ = select.select(fds, [], [])\n" +
            "    for fd in r:\n" +
            "        try:\n" +
            "            d = fd.read(sz)\n" +
            "            if len(d) == sz:\n" +
            "                _, _, t, code, val = struct.unpack(fmt, d)\n" +
            "                if t == 1 and code == 1 and val == 1:\n" +
            "                    print('ESC', flush=True)\n" +
            "        except Exception:\n" +
            "            pass\n"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim() === "ESC") launcherWindow.close();
            }
        }
    }

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
        Quickshell.execDetached([
            "sh", "-c",
            'QS=$(command -v qs || command -v quickshell); [ -n "$QS" ] && "$QS" ipc call "$1" open "$2"',
            "sh", target, param || ""
        ]);
    }

    // Multi-screen click-off detector
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: otherScreenCatcher
            required property var modelData
            screen: modelData

            visible: launcherWindow.isOpenState && launcherWindow.isCardActive && !launcherWindow.isPreviewMode && (modelData !== launcherWindow.screen)

            WlrLayershell.namespace: "quickshell-launcher-dismiss"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    launcherWindow.isCardActive = false;
                }
            }
        }
    }

    // Same-screen click-off detector
    MouseArea {
        anchors.fill: parent
        enabled: launcherWindow.isCardActive && !launcherWindow.isPreviewMode
        onPressed: {
            launcherWindow.isCardActive = false;
        }
    }

    Backend.AppLauncherEngine { id: launcherEngine }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(launcherWindow.windowId, 840) : 840
        height: settingsManager ? settingsManager.getWindowHeight(launcherWindow.windowId, 700) : 700
        radius: theme.defaultCardRadius
        color: theme.base01
        border.width: (theme && theme.globalBorderWidth !== undefined) ? theme.globalBorderWidth : 3

        // Focused: base03 | Off-focus: base0D
        border.color: launcherWindow.isCardActive ? launcherWindow.activeBorderColor : launcherWindow.inactiveBorderColor
        clip: true

        MouseArea {
            anchors.fill: parent
            enabled: !launcherWindow.isCardActive && !launcherWindow.isPreviewMode
            z: 9999
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                launcherWindow.activateCard();
            }
        }

        Loader {
            id: viewLoader
            anchors.fill: parent
            active: launcherWindow.isUiActive
            sourceComponent: Frontend.AppLauncherView {
                engine: launcherEngine
                theme: launcherWindow.theme
                onCompleted: launcherWindow.close()
                onRouteRequested: (target, param) => launcherWindow.routeTo(target, param)
            }
            onItemChanged: {
                if (item && launcherWindow.isOpenState && launcherWindow.isCardActive) item.clearAndFocus();
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: launcherWindow.visible && !launcherWindow.isPreviewMode
        onActivated: launcherWindow.close()
    }
}
