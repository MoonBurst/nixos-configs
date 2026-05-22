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

    property var pendingNotifications: [] // <--- added here

    function shouldLoad(moduleIndex) {
        return moduleIndex <= 8;
    }

    // =========================================================================
    // NATIVE NO-CRASH IPC ROOT CHANNELS
    // =========================================================================
    property alias global_launcher: root

    function toggleMenu() {
        if (launcherControlLoader.item) {
            launcherControlLoader.item.toggleMenu();
            root.launcherVisible = launcherControlLoader.item.active;
        }
    }

    function openClipboard() {
        if (launcherControlLoader.item) {
            launcherControlLoader.item.openClipboard();
            root.launcherVisible = launcherControlLoader.item.active;
            console.log("Clipboard path requested safely via root IPC routing properties.");
        }
    }

    // Lazy property binding loop dynamically tracks screen DP-1 as it mounts on boot
    property var primaryScreen: {
        if (!Quickshell.screens || Quickshell.screens.length === 0) return null;
        var found = Quickshell.screens.find(s => s.name === "DP-1");
        return found ? found : Quickshell.screens;
    }

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

    NotificationServer {
        id: notificationServer
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        actionsSupported: true
        keepOnReload: true
    }

    Connections {
        target: notificationServer
        function onNotification(notification) {
            if (notificationOverlayLoader.item && notificationOverlayLoader.item.handleNotification) {
                notificationOverlayLoader.item.handleNotification(notification);
            } else {
                console.log("Overlay still not loaded or missing handleNotification! Queuing notification.");
                root.pendingNotifications.push(notification);
            }
        }
    }

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

    // =========================================================================
    // UNIFIED CAPSULE FORMATTING GENERATOR
    // =========================================================================
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

    // =========================================================================
    // NATIVE DESKTOP BAR PANEL WINDOW TRACK
    // =========================================================================
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
            border.width:5
            radius: 10

            Item {
                anchors.fill: parent

                // LEFT CONTAINER ROW
                Row {
                    id: leftRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 15
                    spacing: 5

                    Rectangle {
                        id: clockDateCapsuleFrame
                        color: "#000000"
                        radius:5
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

                // 2. CENTER CONTAINER ROW
                Row {
                    id: centerRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 15

                    SoundModule.AudioCapsule {}
                    SoundModule.MicCapsule {}

                    Rectangle {
                        id: clockTimeCapsuleFrame
                        color: "#000000"
                        radius: 6
                        border.width: 5
                        border.color: "#111111"
                        width: 145
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: clockTimeDisplay
                            anchors.centerIn: parent
                            font.family: "monospace"
                            font.pixelSize: 20
                            font.bold: true
                            color: "yellow"
                            text: systemTimeGlobal ? Qt.formatDateTime(systemTimeGlobal.date, "hh:mm:ss AP") : "Loading..."
                        }

                        Component.onCompleted: root.applyCapsuleTheme(clockTimeCapsuleFrame, clockTimeDisplay)
                    }
                }

                // 3. RIGHT CONTAINER ROW
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

    // APPLICATION LAUNCHER OVERLAY WINDOW
    PanelWindow {
        id: appLauncherWindow
        screen: root.primaryScreen
        visible: root.launcherVisible && root.primaryScreen !== null

        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.keyboardFocus: root.launcherVisible ? WlrLayershell.OnDemand : WlrLayershell.None

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

    // =========================================================================
    // NOTIFICATION OVERLAY WINDOW
    // =========================================================================
    PanelWindow {
        id: notificationOverlayWindow
        screen: root.primaryScreen
        visible: true
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.namespace: "quickshell-notifications"
        anchors.top: parent.top
        anchors.right: parent.right
        width: 350
        height: 800
        color: "transparent"

        Loader {
            id: notificationOverlayLoader
            anchors.fill: parent
            active: true
            source: Qt.resolvedUrl("modules/overlays/notifications/NotificationOverlay.qml")
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
