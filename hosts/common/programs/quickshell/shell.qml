//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "." as Modules

Scope {
    id: root

    readonly property string displayEnv: Quickshell.env("DISPLAY") || ""
    readonly property string waylandEnv: Quickshell.env("WAYLAND_DISPLAY") || ""
    readonly property string homeEnv: Quickshell.env("HOME") || ""
    readonly property string pathEnv: Quickshell.env("PATH") || "/run/current-system/sw/bin:/usr/bin:/bin"

    property string calendarTooltipText: ""

    NotificationServer {
        id: notificationServer
        bodyHyperlinksSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        persistenceSupported: true
        bodyImagesSupported: true
        inlineReplySupported: true
        keepOnReload: true
    }

    Connections {
        target: notificationServer

        function onNotification(notification) {
            notificationOverlay.handleNotification(notification);
        }

        function notificationClosed(id, reason) {
            for (let i = 0; i < notificationOverlay.notificationModel.count; i++) {
                if (notificationOverlay.notificationModel.get(i).notifId === id) {
                    notificationOverlay.notificationModel.setProperty(i, "forceDismiss", true);
                    break;
                }
            }
            if (notificationOverlay.activeNotifications[id]) {
                delete notificationOverlay.activeNotifications[id];
            }
        }
    }

    Process {
        id: calFetcher
        running: true
        command: ["sh", "-c", "cal --color=never"]
        stdout: SplitParser { onRead: data => { if (data) root.calendarTooltipText = data; } }
    }

    Timer {
        interval: 3600000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: calFetcher.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: standardBarWindow
            required property var modelData
            screen: modelData
            visible: modelData.name === "DP-1"

            WlrLayershell.layer: WlrLayershell.Top
            WlrLayershell.namespace: "quickshell-bar"
            WlrLayershell.keyboardFocus: WlrLayershell.None

            anchors { top: true; left: true; right: true }
            implicitHeight: visible ? 50 : 0
            color: "transparent"

            mask: Region {
                item: mainVisibleBarContainer
            }

            Rectangle {
                id: mainVisibleBarContainer
                anchors.fill: parent
                color: "transparent"
                border.width: 5
                border.color: "#003399"
                radius: 12

                // FIXED CENTERING CONTAINER: Replaced your cascading Column loop blocks
                // with a flat parent canvas explicitly locked to the vertical center line of the bar window.
                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 32 // Hardlocked height boundary matches your capsule footprint heights perfectly

                    // LEFT CAPSULES
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16
                        spacing: 15

                        Rectangle {
                            id: clockCapsuleFrame
                            color: "#000000"
                            radius: 6
                            border.width: 2
                            border.color: "#111111"
                            width: 115
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            HoverHandler { id: calendarHover }

                            ToolTip {
                                visible: calendarHover.hovered; delay: 100
                                contentItem: Text { id: tooltipTextElement; text: root.calendarTooltipText; font.family: "monospace"; font.pixelSize: 13; color: "#ffffff" }
                                background: Rectangle { id: tooltipBackgroundElement; color: "#000000"; border.color: "#003399"; border.width: 2; radius: 6 }
                            }

                            Text {
                                id: clockDateDisplay
                                anchors.centerIn: parent
                                color: "#ffffff"
                                font.family: "monospace"
                                font.pixelSize: 15
                                font.bold: true
                                text: Qt.formatDateTime(systemTimeGlobal.date, "ddd MMM dd")
                            }

                            Component.onCompleted: {
                                try {
                                    if (typeof Theme !== "undefined") {
                                        clockCapsuleFrame.color = Theme.colorBaseBg; clockCapsuleFrame.radius = Theme.capsuleRadius; clockCapsuleFrame.border.width = Theme.capsuleBorderWidth; clockCapsuleFrame.border.color = Theme.colorOutline; clockCapsuleFrame.height = Theme.capsuleHeight;
                                        tooltipTextElement.color = Theme.colorNormalText; tooltipBackgroundElement.color = Theme.colorBaseBg; tooltipBackgroundElement.border.width = Theme.capsuleBorderWidth;
                                        clockDateDisplay.color = Theme.colorNormalText;
                                    }
                                } catch(e) {}
                            }
                        }

                        Modules.Weather {}
                        AlarmCapsule {}
                        Modules.Music {}
                        Modules.Borg {}
                    }

                    // CENTER CAPSULES
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 15

                        Modules.AudioCapsule {}
                        Modules.MicCapsule {}

                        Rectangle {
                            id: clockTimeCapsuleFrame
                            color: "#000000"
                            radius: 6
                            border.width: 2
                            border.color: "#111111"
                            width: 115
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: clockTimeDisplay
                                anchors.centerIn: parent
                                color: "#ffffff"
                                font.family: "monospace"
                                font.pixelSize: 15
                                font.bold: true
                                text: Qt.formatDateTime(systemTimeGlobal.date, "hh:mm:ss AP")
                            }

                            Component.onCompleted: {
                                try {
                                    if (typeof Theme !== "undefined") {
                                        clockTimeCapsuleFrame.color = Theme.colorBaseBg; clockTimeCapsuleFrame.radius = Theme.capsuleRadius; clockTimeCapsuleFrame.border.width = Theme.capsuleBorderWidth; clockTimeCapsuleFrame.border.color = Theme.colorOutline; clockTimeCapsuleFrame.height = Theme.capsuleHeight;
                                        clockTimeDisplay.color = Theme.colorNormalText;
                                    }
                                } catch(e) {}
                            }
                        }
                    }

                    // RIGHT CAPSULES
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 15
                        spacing: 15

                        NetCapsule {}
                        GpuCapsule {}
                        CpuCapsule {}
                        RamCapsule {}

                        Modules.Tray { barWindow: standardBarWindow }
                    }
                }
            }
        }
    }

    SystemClock { id: systemTimeGlobal; precision: SystemClock.Seconds }

    NotificationOverlay {
        id: notificationOverlay
    }
}
