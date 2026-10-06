import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../style" as Style
import "Utils.js" as Utils
import "FallbackTheme.js" as FallbackTheme
import "." as Common

// Shared base for every overlay window in the shell. Provides:
//   - open/close/toggle state machine with grace-period unload
//   - card-active focus state, click-off behavior across all screens
//   - IPC handler target, Escape watcher, preview-mode support
//   - shape-aware card + Loader for injected content
//
// Subclasses set `windowId`, `defaultW/H`, `defaultPolicy`, provide a
// `content:` block, and may override the `opened`/`closed`/`preShow`
// signals for module-specific behavior.
PanelWindow {
    id: base

    // ---- Identity -----------------------------------------------------------
    property string windowId: ""
    property string ipcTarget: windowId
    property string layerNamespace: "quickshell-" + windowId

    // ---- Geometry / policy --------------------------------------------------
    property int defaultW: 840
    property int defaultH: 650
    property string defaultPolicy: "lazy"
    property bool eagerLoad: false

    // ---- Shell context ------------------------------------------------------
    property var shell: null
    readonly property var safeShell: (typeof shell !== "undefined" && shell) ? shell : null
    readonly property var settingsManager: safeShell ? safeShell.settingsManager : null
    readonly property var theme: (safeShell && safeShell.theme) ? safeShell.theme : FallbackTheme.theme

    // ---- Argument passed to open(arg); subclasses cast as needed -----------
    property var pendingArg: null

    // ---- Hooks & Window Dismissal Policies ----------------------------------
    // Subclasses provide their hardcoded design defaults here; the effective
    // properties below resolve whether the user has customized this specific
    // overlay via the Settings GUI / SettingsManager.
    property bool escapeCloses: true
    property bool dismissOnBlurDefault: true

    // Dynamically queries SettingsManager. If a per-window override exists in
    // settings.json, that takes precedence; otherwise falls back to the subclass default.
    readonly property bool effectiveDismissOnBlur: settingsManager
    ? settingsManager.getWindowDismissOnBlur(windowId, dismissOnBlurDefault)
    : dismissOnBlurDefault

    readonly property bool effectiveEscapeCloses: settingsManager
    ? settingsManager.getWindowEscapeCloses(windowId, escapeCloses)
    : escapeCloses

    signal windowOpened()
    signal windowClosed()
    signal preShow()

    // ---- Content (subclass provides an explicit Component) ------------------
    // Using a named Component property instead of a default property alias:
    // the alias wraps the assigned body in a Component in *this* file's
    // scope, so ids declared by the subclass (engines, models) can't be
    // resolved. An explicit `viewComponent: Component { ... }` in the
    // subclass keeps the body in the subclass's own scope.
    property Component viewComponent: null

    // ---- State machine ------------------------------------------------------
    readonly property string loadPolicy: settingsManager
        ? settingsManager.getWindowLoadPolicy(windowId, defaultPolicy)
        : defaultPolicy
    readonly property bool shouldKeepLoaded: eagerLoad || loadPolicy === "eager"

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
        onTriggered: base.inGracePeriod = false
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (viewLoader.item && typeof viewLoader.item.clearAndFocus === "function") {
                viewLoader.item.clearAndFocus(base.pendingArg);
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
                safeShell.closeOtherOverlays(base);
            }
            base.isCardActive = true;
            base.preShow();
            focusTimer.restart();
        }
    }

    // ---- Window geometry / role --------------------------------------------
    screen: (safeShell && safeShell.primaryScreen) ? safeShell.primaryScreen : (Quickshell.screens[0] || null)

    WlrLayershell.namespace: base.layerNamespace
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        // Exclusive for the whole open lifetime. Previously this dropped to
        // None on click-off, which killed the Shortcut and left the user
        // unable to close with Escape. Holding Exclusive throughout keeps
        // the Shortcut alive; click-off remains a purely visual focus-ring
        // change.
        return WlrKeyboardFocus.Exclusive;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: base.isCardActive ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: card }

    // ---- Public API --------------------------------------------------------
    function open(arg) {
        if (safeShell && safeShell.sessionLock && safeShell.sessionLock.locked) return;
        base.pendingArg = (arg !== undefined) ? arg : null;
        base.isCardActive = true;
        base.isOpenState = true;
        base.windowOpened();
        focusTimer.restart();
    }

    function activateCard() {
        base.isCardActive = true;
        focusTimer.restart();
    }

    function close() {
        base.isOpenState = false;
        base.isCardActive = false;
        base.pendingArg = null;
        base.windowClosed();
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }

    function toggle() {
        if (isOpenState) close();
        else open();
    }

    // ---- IPC ---------------------------------------------------------------
    // Subclasses can set ipcTarget: "" to opt out (e.g. windows whose IPC is
    // handled elsewhere, like Amogus and RNG in OverlayHost.qml).
    IpcHandler {
        target: base.ipcTarget
        enabled: base.ipcTarget !== ""
        function toggle(): void { base.toggle(); }
        function open(arg: string): void { base.open(arg); }
        function close(): void { base.close(); }
    }


    // ---- Multi-screen click-off catcher ------------------------------------
    // Captures mouse clicks that occur on secondary displays while this overlay is open.
    // If dismiss-on-blur is enabled, clicking another display closes the overlay.
    // If disabled, it only deactivates card focus visually, leaving the overlay on-screen.
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: otherScreenCatcher
            required property var modelData
            screen: modelData

            visible: base.isOpenState && base.isCardActive && !base.isPreviewMode && (modelData !== base.screen)

            WlrLayershell.namespace: base.layerNamespace + "-dismiss"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    if (base.effectiveDismissOnBlur) base.close();
                    else base.isCardActive = false;
                }
            }
        }
    }

    // ---- Same-screen click-off ---------------------------------------------
    // Handles clicks occurring on the dark backdrop outside the centered card.
    // Dismisses immediately if effectiveDismissOnBlur is true; otherwise deactivates focus.
    MouseArea {
        anchors.fill: parent
        enabled: base.isCardActive && !base.isPreviewMode
        onPressed: {
            if (base.effectiveDismissOnBlur) base.close();
            else base.isCardActive = false;
        }
    }

    // ---- Card + injected view ----------------------------------------------
    Item {
        id: card
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(base.windowId, base.defaultW) : base.defaultW
        height: settingsManager ? settingsManager.getWindowHeight(base.windowId, base.defaultH) : base.defaultH

        readonly property var safePad: Utils.getSafeCardPadding(settingsManager)
        readonly property color currentBorderColor: base.isCardActive ? base.activeBorderColor : base.inactiveBorderColor
        readonly property int currentBorderWidth: (theme && theme.globalBorderWidth !== undefined) ? theme.globalBorderWidth : 3

        Style.ShapeBox {
            anchors.fill: parent
            role: "card"
            color: theme.base01
            borderColor: card.currentBorderColor
            borderWidth: card.currentBorderWidth
        }

        MouseArea {
            anchors.fill: parent
            enabled: !base.isCardActive && !base.isPreviewMode
            z: 9999
            cursorShape: Qt.PointingHandCursor
            onPressed: base.activateCard()
        }

        Loader {
            id: viewLoader
            anchors.fill: parent
            anchors.leftMargin: card.safePad.h
            anchors.rightMargin: card.safePad.h
            anchors.topMargin: card.safePad.v
            anchors.bottomMargin: card.safePad.v
            active: base.isUiActive
            sourceComponent: base.viewComponent
            onItemChanged: {
                if (item && base.isOpenState && base.isCardActive
                    && typeof item.clearAndFocus === "function") {
                    item.clearAndFocus(base.pendingArg);
                }
            }
        }
    }

    // Native Wayland layer-shell shortcut. Catches Escape while this window holds
    // active surface focus, respecting the user's per-window GUI setting.
    Shortcut {
        sequence: "Escape"
        enabled: base.visible && !base.isPreviewMode && base.effectiveEscapeCloses
        onActivated: base.close()
    }
}
