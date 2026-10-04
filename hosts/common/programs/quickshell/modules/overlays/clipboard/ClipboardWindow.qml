import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../" as RootTheme
import "../../settings" as SettingsTools
import "./frontend" as Frontend

PanelWindow {
    id: window

    property string windowId: "clipboard"
    readonly property string defaultPolicy: "lazy"

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

    readonly property color activeBorderColor: (theme && theme.base03) ? theme.base03 : "#003399"
    readonly property color inactiveBorderColor: (theme && theme.base0D) ? theme.base0D : "#003399"

    property bool inGracePeriod: false
    Timer {
        id: graceTimer
        repeat: false
        onTriggered: { window.inGracePeriod = false; }
    }

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

    onVisibleChanged: {
        if (visible && !isPreviewMode) {
            if (safeShell && typeof safeShell.closeOtherOverlays === "function") {
                safeShell.closeOtherOverlays(window);
            }
            window.isCardActive = true;
            focusTimer.restart();
        }
    }

    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        return window.isCardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: window.isCardActive ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: card }

    function open() {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        window.isCardActive = true;
        isOpenState = true;
        focusTimer.restart();
    }

    function activateCard() {
        window.isCardActive = true;
        focusTimer.restart();
    }

    function close() {
        isOpenState = false;
        window.isCardActive = false;
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }

    function toggle() { if (isOpenState) close(); else open(); }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { window.toggle(); }
        function open(): void { window.open(); }
        function close(): void { window.close(); }
    }

    Process {
        id: escWatcher
        running: window.isOpenState && !window.isPreviewMode
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
                if (data.trim() === "ESC") window.close();
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: otherScreenCatcher
            required property var modelData
            screen: modelData

            visible: window.isOpenState && window.isCardActive && !window.isPreviewMode && (modelData !== window.screen)

            WlrLayershell.namespace: "quickshell-clipboard-dismiss"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    window.isCardActive = false;
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: window.isCardActive && !window.isPreviewMode
        onPressed: {
            window.isCardActive = false;
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(window.windowId, 1080) : 1080
        height: settingsManager ? settingsManager.getWindowHeight(window.windowId, 700) : 700
        radius: theme.defaultCardRadius
        color: theme.base01
        border.width: (theme && theme.globalBorderWidth !== undefined) ? theme.globalBorderWidth : 3
        border.color: window.isCardActive ? window.activeBorderColor : window.inactiveBorderColor
        clip: true

        MouseArea {
            anchors.fill: parent
            enabled: !window.isCardActive && !window.isPreviewMode
            z: 9999
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                window.activateCard();
            }
        }

        Loader {
            id: viewLoader
            anchors.fill: parent
            active: window.isUiActive
            sourceComponent: Frontend.ClipboardView {
                theme: window.theme
                onCompleted: window.close()
            }
            onItemChanged: {
                if (item && window.isOpenState && window.isCardActive) item.clearAndFocus();
            }
        }
    }

    SettingsTools.PreviewInspector {
        id: previewInspector
        visible: window.isPreviewMode
        anchors.left: card.right
        anchors.leftMargin: 20
        anchors.verticalCenter: card.verticalCenter

        windowId: window.windowId
        settingsManager: window.settingsManager
        theme: window.theme
        defaultW: 1080; defaultH: 700
        defaultFH: 52; defaultIS: 36
        hasField: true; hasIcon: false
        defaultPolicy: window.defaultPolicy

        onDoneRequested: {
            if (settingsManager) settingsManager.previewWindow = "";
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: window.visible && !window.isPreviewMode
        onActivated: window.close()
    }
}
