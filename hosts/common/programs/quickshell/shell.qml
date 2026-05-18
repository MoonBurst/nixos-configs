import Quickshell
import Quickshell.Io 
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

Scope {
    id: root

    readonly property string displayEnv: Quickshell.env("DISPLAY") || ""
    readonly property string waylandEnv: Quickshell.env("WAYLAND_DISPLAY") || ""
    readonly property string homeEnv: Quickshell.env("HOME") || ""
    readonly property string pathEnv: Quickshell.env("PATH") || "/run/current-system/sw/bin:/usr/bin:/bin"

    property string calendarTooltipText: ""

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
            implicitHeight: visible ? 44 : 0 
            
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 5
                border.color: "#003399"
                radius: 12 

                // LEFT SIDE CAPSULES
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 16; spacing: 15 

                    Rectangle {
                        color: Theme.colorBaseBg; radius: Theme.capsuleRadius; border.width: Theme.capsuleBorderWidth; border.color: Theme.colorOutline
                        width: 115; height: Theme.capsuleHeight; anchors.verticalCenter: parent.verticalCenter
                        HoverHandler { id: calendarHover }
                        ToolTip {
                            visible: calendarHover.hovered; delay: 100 
                            contentItem: Text { text: root.calendarTooltipText; color: Theme.colorNormalText; font.family: "monospace"; font.pixelSize: 13 }
                            background: Rectangle { color: Theme.colorBaseBg; border.color: "#003399"; border.width: Theme.capsuleBorderWidth; radius: 6 }
                        }
                        Text { anchors.centerIn: parent; color: Theme.colorNormalText; font.family: "monospace"; font.pixelSize: 15; font.bold: true; text: Qt.formatDateTime(systemTimeGlobal.date, "ddd MMM dd") }
                    }

                    // Direct file loaders use plain string strings natively without Component wrappers
                    Loader { source: "weather.qml"; anchors.verticalCenter: parent.verticalCenter }
                    AlarmCapsule {}
                    Loader { source: "music.qml"; anchors.verticalCenter: parent.verticalCenter }
                }

                // CENTER SIDE CAPSULES
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; spacing: 15 

                    AudioCapsule {}

                    Rectangle {
                        color: Theme.colorBaseBg; radius: Theme.capsuleRadius; border.width: Theme.capsuleBorderWidth; border.color: Theme.colorOutline
                        width: 115; height: Theme.capsuleHeight; anchors.verticalCenter: parent.verticalCenter
                        Text { anchors.centerIn: parent; color: Theme.colorNormalText; font.family: "monospace"; font.pixelSize: 15; font.bold: true; text: Qt.formatDateTime(systemTimeGlobal.date, "hh:mm:ss AP") }
                    }
                }

                // RIGHT SIDE CAPSULES (Tray aligned at the absolute far-right end of the row)
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 16; spacing: 15 

                    NetCapsule {}
                    GpuCapsule {}
                    CpuCapsule {}
                    RamCapsule {}
                    
                    // Direct file path string loader maps cleanly to lowercase tray.qml
                    Loader { source: "tray.qml"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    SystemClock { id: systemTimeGlobal; precision: SystemClock.Seconds }
}
