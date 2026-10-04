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
    id: window

    property string windowId: "email"
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

    QtObject {
        id: dynamicEmailTheme
        readonly property var src: window.theme

        property color base00: src ? src.base00 : "#121212"
        property color base01: src ? src.base01 : "#181825"
        property color base02: src ? src.base02 : "#313244"
        property color base03: src ? src.base03 : "#003399"
        property color base04: src ? src.base04 : "#45475a"
        property color base05: src ? src.base05 : "yellow"
        property color base06: src ? src.base06 : "white"
        property color base07: src ? src.base07 : "#cccccc"
        property color base08: src ? src.base08 : "#ff5555"
        property color base09: src ? src.base09 : "#fe8019"
        property color base0A: src ? src.base0A : "#fabd2f"
        property color base0B: src ? src.base0B : "#545454"
        property color base0C: src ? src.base0C : "#04f100"
        property color base0D: src ? src.base0D : "#003399"
        property color base0E: src ? src.base0E : "#675ddb"
        property color base0F: src ? src.base0F : "#ff8019"

        property string fontFamily: src ? src.fontFamily : "monospace"
        property int defaultCardWidth: (src && src.defaultCardWidth) ? src.defaultCardWidth : 420
        property int defaultCardHeight: (src && src.defaultCardHeight) ? src.defaultCardHeight : 140
        property int defaultCardRadius: (src && src.defaultCardRadius) ? src.defaultCardRadius : 10
        property int globalBorderWidth: (src && src.globalBorderWidth) ? src.globalBorderWidth : 3
        property int globalPadding: (src && src.globalPadding) ? src.globalPadding : 16
        property int globalFontSize: (src && src.globalFontSize) ? src.globalFontSize : 14
        property color scrollHandleColor: (src && src.scrollHandleColor) ? src.scrollHandleColor : "#003399"

        property color innerBorderColor: (src && src.base05) ? src.base05 : "yellow"
        property color outerBorderColor: window.isCardActive ? window.activeBorderColor : window.inactiveBorderColor
    }

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
            emailEngine.readMailCache();
            emailEngine.syncMail();
            focusTimer.restart();
        }
    }

    WlrLayershell.namespace: "quickshell-email-window"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        return window.isCardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: window.isCardActive ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: emailCard }

    function open() {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        window.isCardActive = true;
        isOpenState = true;
        emailEngine.readMailCache();
        emailEngine.syncMail();
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
        target: "email"
        function toggle(): void { window.toggle(); }
        function open(): void { window.open(); }
        function close(): void { window.close(); }
    }

    Process {
        id: escWatcher
        running: window.isOpenState && !window.isPreviewMode && (!viewLoader.item || !viewLoader.item.isModalActive())
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
                if (data.trim() === "ESC") {
                    if (emailEngine.isComposing) {
                        emailEngine.isComposing = false;
                    } else {
                        window.close();
                    }
                }
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

            WlrLayershell.namespace: "quickshell-email-dismiss"
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

    Backend.EmailEngine { id: emailEngine }

    Item {
        id: emailCard
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(window.windowId, 1500) : 1500
        height: settingsManager ? settingsManager.getWindowHeight(window.windowId, 900) : 900

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
            sourceComponent: Frontend.EmailView {
                engine: emailEngine
                theme: dynamicEmailTheme
                settingsManager: window.settingsManager
                onCloseRequested: window.close()
            }
            onItemChanged: {
                if (item && window.isOpenState && window.isCardActive) item.clearAndFocus();
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 14
            width: 28; height: 28; radius: 6
            color: closeHov.hovered ? ((theme && theme.base08 !== undefined) ? theme.base08 : "#ff5555") : "transparent"
            border.color: (theme && theme.base08 !== undefined) ? theme.base08 : "#ff5555"
            border.width: 1.5
            z: 10000

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.bold: true; font.pixelSize: 13
                color: closeHov.hovered ? ((theme && theme.base00 !== undefined) ? theme.base00 : "#000") : ((theme && theme.base08 !== undefined) ? theme.base08 : "#ff5555")
            }
            HoverHandler { id: closeHov }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: window.close()
            }
        }
    }

    SettingsTools.PreviewInspector {
        id: previewInspector
        visible: window.isPreviewMode
        anchors.left: emailCard.right
        anchors.leftMargin: 20
        anchors.verticalCenter: emailCard.verticalCenter

        windowId: window.windowId
        settingsManager: window.settingsManager
        theme: window.theme
        defaultW: 1500; defaultH: 900
        defaultFH: 48; defaultIS: 32
        hasField: true; hasIcon: false
        defaultPolicy: window.defaultPolicy

        onDoneRequested: {
            if (settingsManager) settingsManager.previewWindow = "";
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: window.visible && !window.isPreviewMode && (!viewLoader.item || !viewLoader.item.isModalActive())
        onActivated: window.close()
    }
}
