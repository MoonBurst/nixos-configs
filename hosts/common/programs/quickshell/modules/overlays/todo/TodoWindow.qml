import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../" as RootTheme
import "../../settings" as SettingsTools
import "./backend" as Backend
import "./frontend" as Frontend

PanelWindow {
    id: todoWindow

    property string windowId: "todo"
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

    // True while actively focused on Todo; false when clicked off
    property bool isCardActive: true

    // Focused: base03 | Off-focus: base0D
    readonly property color activeBorderColor: (theme && theme.base03) ? theme.base03 : "#003399"
    readonly property color inactiveBorderColor: (theme && theme.base0D) ? theme.base0D : "#003399"

    property bool inGracePeriod: false
    Timer {
        id: graceTimer
        repeat: false
        onTriggered: { todoWindow.inGracePeriod = false; }
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
                safeShell.closeOtherOverlays(todoWindow);
            }
            todoWindow.isCardActive = true;
            focusTimer.restart();
        }
    }

    WlrLayershell.namespace: "quickshell-todo"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay

    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        return todoWindow.isCardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: todoWindow.isCardActive ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: card }

    function open() {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        todoWindow.isCardActive = true;
        isOpenState = true;
        focusTimer.restart();
    }

    function activateCard() {
        todoWindow.isCardActive = true;
        focusTimer.restart();
    }

    function close() {
        isOpenState = false;
        todoWindow.isCardActive = false;
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }

    function toggle() {
        if (isOpenState) close();
        else open();
    }

    IpcHandler {
        target: "todo"
        function toggle(): void { todoWindow.toggle(); }
        function open(): void { todoWindow.open(); }
        function close(): void { todoWindow.close(); }
    }

    // Background listener for Escape: catches Escape globally while Todo is open, even when unfocused
    Process {
        id: escWatcher
        running: todoWindow.isOpenState && !todoWindow.isPreviewMode
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
                if (data.trim() === "ESC") todoWindow.close();
            }
        }
    }

    Backend.TodoEngine { id: todoEngine }

    // Multi-screen click-off detector
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: otherScreenCatcher
            required property var modelData
            screen: modelData

            visible: todoWindow.isOpenState && todoWindow.isCardActive && !todoWindow.isPreviewMode && (modelData !== todoWindow.screen)

            WlrLayershell.namespace: "quickshell-todo-dismiss"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    todoWindow.isCardActive = false;
                }
            }
        }
    }

    // Same-screen click-off detector
    MouseArea {
        anchors.fill: parent
        enabled: todoWindow.isCardActive && !todoWindow.isPreviewMode
        onPressed: {
            todoWindow.isCardActive = false;
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(todoWindow.windowId, 860) : 860
        height: settingsManager ? settingsManager.getWindowHeight(todoWindow.windowId, 740) : 740
        radius: (theme && theme.defaultCardRadius !== undefined) ? theme.defaultCardRadius : 10
        color: (theme && theme.base01 !== undefined) ? theme.base01 : "#181825"
        border.width: (theme && theme.globalBorderWidth !== undefined) ? theme.globalBorderWidth : 3

        // Focused: base03 | Off-focus: base0D
        border.color: todoWindow.isCardActive ? todoWindow.activeBorderColor : todoWindow.inactiveBorderColor
        clip: true

        MouseArea {
            anchors.fill: parent
            enabled: !todoWindow.isCardActive && !todoWindow.isPreviewMode
            z: 9999
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                todoWindow.activateCard();
            }
        }

        Loader {
            id: viewLoader
            anchors.fill: parent
            active: todoWindow.isUiActive
            sourceComponent: Frontend.TodoView {
                engine: todoEngine
                theme: todoWindow.theme
            }
            onItemChanged: {
                if (item && todoWindow.isOpenState && todoWindow.isCardActive) {
                    item.clearAndFocus();
                }
            }
        }
    }

    SettingsTools.PreviewInspector {
        id: previewInspector
        visible: todoWindow.isPreviewMode
        anchors.left: (card.x + card.width + width + 20 <= todoWindow.width) ? card.right : undefined
        anchors.right: (card.x + card.width + width + 20 > todoWindow.width) ? card.left : undefined
        anchors.leftMargin: 20; anchors.rightMargin: 20
        anchors.verticalCenter: card.verticalCenter

        windowId: todoWindow.windowId
        settingsManager: todoWindow.settingsManager
        theme: todoWindow.theme
        defaultW: 860; defaultH: 740
        defaultFH: 58; defaultIS: 32
        hasField: true; hasIcon: false
        defaultPolicy: todoWindow.defaultPolicy

        onDoneRequested: {
            if (settingsManager) settingsManager.previewWindow = "";
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: todoWindow.visible && !todoWindow.isPreviewMode
        onActivated: todoWindow.close()
    }
}
