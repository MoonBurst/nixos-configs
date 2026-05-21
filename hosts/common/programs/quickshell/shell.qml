//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts
import QtQuick.Window

import Quickshell
import Quickshell.Wayland // FIXED: Restored to resolve the non-existent attached object layer window error
import Quickshell.Services.Notifications
import Quickshell.Io
import "." as Modules

Scope {
    id: root

    property string calendarTooltipText: ""

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
            notificationOverlay.handleNotification(notification);
        }
    }

    Process {
        id: calFetcher
        running: true
        command: ["sh", "-c", "cal --color=never"]
        stdout: SplitParser { onRead: data => root.calendarTooltipText = data }
    }

    Timer {
        interval: 3600000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: calFetcher.running = true
    }

    function applyCapsuleTheme(frameItem, textItem) {
        try {
            frameItem.color = Theme.colorBaseBg;
            frameItem.radius = Theme.capsuleRadius;
            frameItem.border.width = Theme.capsuleBorderWidth;
            frameItem.border.color = Theme.colorOutline;
            frameItem.height = Theme.capsuleHeight;
            if (textItem) textItem.color = Theme.colorNormalText;
        } catch(e) {}
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
            implicitHeight: 50
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 5
                border.color: "#003399"
                radius: 12

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 32

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
                                contentItem: Text { id: tooltipTextElement; text: root.calendarTooltipText; font.family: "monospace"; font.pixelSize: 13 }
                                background: Rectangle { id: tooltipBackgroundElement; border.color: "#003399"; radius: 6 }
                            }

                            Text {
                                id: clockDateDisplay
                                anchors.centerIn: parent
                                font.family: "monospace"
                                font.pixelSize: 15
                                font.bold: true
                                text: Qt.formatDateTime(systemTimeGlobal.date, "ddd MMM dd")
                            }

                            Component.onCompleted: {
                                root.applyCapsuleTheme(clockCapsuleFrame, clockDateDisplay);
                                try {
                                    tooltipTextElement.color = Theme.colorNormalText;
                                    tooltipBackgroundElement.color = Theme.colorBaseBg;
                                    tooltipBackgroundElement.border.width = Theme.capsuleBorderWidth;
                                } catch(e) {}
                            }
                        }

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
                                font.family: "monospace"
                                font.pixelSize: 15
                                font.bold: true
                                text: Qt.formatDateTime(systemTimeGlobal.date, "hh:mm:ss AP")
                            }

                            Component.onCompleted: root.applyCapsuleTheme(clockTimeCapsuleFrame, clockTimeDisplay)
                        }
                    }

                    // RIGHT CAPSULES
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 15
                        spacing: 15


                        Modules.Tray { barWindow: standardBarWindow }
                    }
                }
            }
        }
    }

    SystemClock { id: systemTimeGlobal; precision: SystemClock.Seconds }
    NotificationOverlay {  id: notificationOverlay  }
    LauncherOverlay {   id: systemApplicationLauncher }
}
