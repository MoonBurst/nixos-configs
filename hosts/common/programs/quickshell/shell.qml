//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io

import "./modules/bar/sound" as SoundModule
import "./modules/bar/tray" as TrayModule

Scope {
    id: root

    // ============================================================================
    // #### MODULE LOGIC: GLOBAL PROPERTY CORE AND STATE STORAGE ####
    // ============================================================================
    property string calendarTooltipText: ""
    property bool launcherVisible: false

    property QtObject theme: null
    property QtObject themeData: null

    // State structural variables cleanly linking your backend mathematical logic lines
    property var filteredAppsModel: ListModel {}
    property bool isMenuOpen: false
    property bool isClipboardMode: false
    property bool isMathMode: false
    property string activeImageCachePath: ""
    property string mathResultString: ""

    property var themableItems: []
    property var pendingNotifications: []

    function shouldLoad(moduleIndex) {
        return moduleIndex <= 8;
    }

    // ============================================================================
    // #### MODULE LOGIC: LAUNCHER INTER-PROCESS COMMUNICATION SHORTCUTS ####
    // ============================================================================
    property alias global_launcher: root

    function toggleMenu() {
        if (launcherControlLoader.item) {
            launcherControlLoader.item.toggleMenu();
            root.launcherVisible = launcherControlLoader.item.visible;
        }
    }

    function openClipboard() {
        if (launcherControlLoader.item) {
            launcherControlLoader.item.openClipboard();
            root.launcherVisible = launcherControlLoader.item.visible;
            console.log("Clipboard path requested safely via root IPC routing properties.");
        }
    }

    // ============================================================================
    // #### MODULE LOGIC: SYSTEM HARDWARE DISPATCH SCREEN DETECTORS ####
    // ============================================================================
    // Lazy property binding loop dynamically tracks screen DP-1 as it mounts on boot
    property var primaryScreen: {
        if (!Quickshell.screens || Quickshell.screens.length === 0) return null;
        var found = Quickshell.screens.find(s => s.name === "DP-1");
        return found ? found : Quickshell.screens;
    }
    // ============================================================================
    // #### MODULE LOGIC: SYSTEM STYLIX LOCAL PROFILE LOAD TRACKER ####
    // ============================================================================
    Loader {
        id: themeLoader
        source: "file:///home/moonburst/.config/quickshell/Theme.qml"
        onLoaded: {
            console.log("Stylix theme loaded successfully.");
            root.theme = item;
            root.themeData = item;
            if (root.themableItems && root.themableItems.length !== undefined) {
                for (var i = 0; i < root.themableItems.length; ++i) {
                    var themable = root.themableItems[i];
                    root.applyCapsuleTheme(themable.frame, themable.text);
                }
            }
        }
    }

    // ============================================================================
    // #### MODULE LOGIC: CALENDAR TEXT GENERATOR TOOL ####
    // ============================================================================
    Process {
        id: calFetcher
        running: true
        command: ["sh", "-c", "cal --color=never"]
        stdout: SplitParser { onRead: data => root.calendarTooltipText = data }
    }

    Timer {
        id: calendarRefreshTimer
        interval: 3600000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: calFetcher.running = true
    }

    // ============================================================================
    // #### MODULE LOGIC: UNIFIED CAPSULE FORMATTING GENERATOR ####
    // ============================================================================
    function applyCapsuleTheme(frameItem, textItem) {
        if (!frameItem) return;

        var found = false;
        for (var i = 0; i < themableItems.length; i++) {
            if (themableItems[i].frame === frameItem) { found = true; break; }
        }
        if (!found) { themableItems.push({frame: frameItem, text: textItem}); }

        try {
            frameItem.height = 35;
            frameItem.radius = 10;
            frameItem.border.width = 3;
            frameItem.color = "black";
            frameItem.border.color = "yellow";

            if (textItem) {
                textItem.color = "yellow";
                textItem.font.pixelSize = 20;
            }
        } catch(e) {}
    }

    SystemClock { id: systemTimeGlobal; precision: SystemClock.Seconds }
    // ============================================================================
    // #### MODULE LOGIC: MASTER MAIN STATUS BAR WINDOW PRIMITIVE ####
    // ============================================================================
    PanelWindow {
        id: standardBarWindow
        screen: root.primaryScreen
        visible: root.primaryScreen !== null

        WlrLayershell.layer: WlrLayershell.Top
        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.keyboardFocus: WlrLayershell.None
        exclusiveZone: implicitHeight

        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 50
        color: "black"

        Rectangle {
            anchors.fill: parent
            color: "black"
            border.color: "#003399"
            border.width: 5
            radius: 10

            Item {
                anchors.fill: parent

                // ============================================================================
                // #### MODULE LOGIC: LEFT BAR REGION TIMING AND TOOLTIP POPS ####
                // ============================================================================
                Row {
                    id: leftRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 15
                    spacing: 5

                    Rectangle {
                        id: clockDateCapsuleFrame
                        color: "#000000"
                        radius: 5
                        border.width: 3
                        border.color: "#111111"
                        width: 150
                        anchors.verticalCenter: parent.verticalCenter

                        HoverHandler { id: calendarHover }

                        PopupWindow {
                            visible: calendarHover.hovered
                            anchor.window: standardBarWindow
                            anchor.rect: Qt.rect(leftRow.x + clockDateCapsuleFrame.x, standardBarWindow.implicitHeight, clockDateCapsuleFrame.width, 0)
                            color: "transparent"
                            Rectangle {
                                anchors.fill: parent
                                border.color: "yellow"
                                border.width: 3
                                radius: 5
                                color: "black"

                                Text {
                                    id: calendarText
                                    anchors.centerIn: parent
                                    text: root.calendarTooltipText
                                    font.family: "monospace"
                                    font.pixelSize: 20
                                    color: "yellow"
                                }
                            }
                        }

                        Text {
                            id: clockDateDisplay
                            anchors.centerIn: parent
                            font.family: "monospace"
                            font.pixelSize: 20
                            font.bold: true
                            color: "yellow"
                            text: systemTimeGlobal ? Qt.formatDateTime(systemTimeGlobal.date, "ddd MMM dd") : "Loading..."
                        }

                        Component.onCompleted: {
                            root.applyCapsuleTheme(clockDateCapsuleFrame, clockDateDisplay);
                        }
                    }

                    Item { width: 1; height: 34 }

                    // ASYNCHRONOUS SYSTEM WIDGET MODULE LOADERS
                    Loader { active: root.shouldLoad(0); source: "./modules/bar/music/Music.qml" }
                    Loader { active: root.shouldLoad(1); source: "./modules/bar/alarm/AlarmCapsule.qml" }
                    Loader { active: root.shouldLoad(2); source: "./modules/bar/borg/BorgCapsule.qml" }
                    Loader { active: root.shouldLoad(3); source: "./modules/bar/weather/Weather.qml"
                        onLoaded: {
                            if (item && typeof item.barWindow !== "undefined") {
                                item.barWindow = standardBarWindow;
                            }
                        }
                    }
                }
                // ============================================================================
                // #### MODULE LOGIC: CENTER BAR REGION SOUND AND PRIMARY CLOCK COMPONENT HUBS ####
                // ============================================================================
                Row {
                    id: centerRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 15

                    SoundModule.AudioCapsule {}
                    SoundModule.MicCapsule {}

                    Item {
                        id: clockContainerBox
                        width: 145
                        height: 35

                        HoverHandler {
                            id: mainClockHoverTracker
                        }

                        Loader {
                            id: clockModuleLoader
                            active: root.shouldLoad(4)
                            anchors.fill: parent
                            source: "./modules/bar/clock/ClockCapsule.qml"

                            onLoaded: {
                                if (item && typeof item.barWindow !== "undefined") {
                                    item.barWindow = standardBarWindow;
                                    if (typeof item.isHoveredExternal !== "undefined") {
                                        item.isHoveredExternal = Qt.binding(function() { return mainClockHoverTracker.hovered; });
                                    }
                                }
                            }
                        }
                    }
                }
                // ============================================================================
                // #### FIXED: UPGRADED FROM POPUPWINDOW TO AN INDEPENDENT PANELWINDOW OVERLAY ####
                // #### This completely breaks through Wayland multi-monitor boundary clipping walls! ####
                // ============================================================================
                PanelWindow {
                    id: globalClockMatrixOverlayWindow

                    // Dynamically inherits the exact monitor screen profile where your status bar is active
                    screen: standardBarWindow.screen
                    // Change this back to "mainClockHoverTracker.hovered" when you are done taking screenshots!
                    visible: true

                    WlrLayershell.layer: WlrLayershell.Overlay
                    WlrLayershell.namespace: "quickshell-clock-matrix-overlay"
                    WlrLayershell.keyboardFocus: WlrLayershell.None

                    anchors.top: true
                    anchors.left: true

                    WlrLayershell.margins.left: standardBarWindow ? Math.max(0, (standardBarWindow.width / 2) - (760 / 2)) : 0


                    implicitWidth: 760
                    implicitHeight: 325
                    color: "transparent"

                    Loader {
                        anchors.fill: parent
                        source: "./modules/bar/clock/ClockMatrixPopupView.qml"
                    }
                }






    // ============================================================================
    // #### MODULE LOGIC: RIGHT BAR REGION PERFORMANCE MONITOR PACKS ####
     // ============================================================================
                Row {
                    id: rightRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 10
                    spacing: 5

                    Loader { active: root.shouldLoad(5); source: "./modules/bar/network/NetCapsule.qml" }
                    Loader { active: root.shouldLoad(6); source: "./modules/bar/cpu/CpuCapsule.qml" }
                    Loader { active: root.shouldLoad(7); source: "./modules/bar/gpu/GpuCapsule.qml" }
                    Loader { active: root.shouldLoad(8); source: "./modules/bar/ram/RamCapsule.qml" }

                    TrayModule.Tray { barWindow: standardBarWindow }
                }
            }
        }
    }

    // ============================================================================
    // #### MODULE LOGIC: INTERACTIVE SYSTEM APP LAUNCHER CONTAINER OVERLAY ####
    // ============================================================================
    PanelWindow {
        id: appLauncherWindow
        screen: root.primaryScreen
        visible: root.launcherVisible && root.primaryScreen !== null

        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.keyboardFocus: root.launcherVisible ? WlrLayershell.Exclusive : WlrLayershell.None

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        Loader {
            anchors.fill: parent
            active: appLauncherWindow.visible
            source: Qt.resolvedUrl("modules/overlays/launcher/LauncherOverlay.qml")
            onLoaded: {
                if (item) {
                    item.requestClose.connect(function() {
                        root.launcherVisible = false;
                        if (launcherControlLoader.item) {
                            launcherControlLoader.item.close();
                        }
                    });
                }
            }
        }
    }
    // ============================================================================
    // #### MODULE LOGIC: BACKGROUND ISOLATED LOADER SERVICES ####
    // ============================================================================
    Loader {
        id: notificationOverlayLoader
        active: true
        source: Qt.resolvedUrl("NotificationOverlay.qml")
        onLoaded: {
            console.log("NotificationOverlay loaded:", item)
            for (let i = 0; i < root.pendingNotifications.length; ++i) {
                if (item && item.handleNotification) {
                    item.handleNotification(root.pendingNotifications[i]);
                }
            }
            root.pendingNotifications = [];
        }
    }

    Loader {
        id: launcherControlLoader
        active: true
        source: Qt.resolvedUrl("modules/overlays/launcher/LauncherController.qml")
        onLoaded: {
            if (item) {
                item.uiRoot = root;
            }
        }
    }
}
