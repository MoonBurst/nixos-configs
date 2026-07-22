// BorgCapsule.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import "../../style"

Item {
    id: borgBox

    property var barWindow: null
    property string borgProgress: "Idle"
    property int syncPercent: 0
    property string syncStatus: "idle"

    property var tooltipLines: ["Status: Idle", "No active backup operations."]

    // =========================================================================
    // SAFE STRONGLY-TYPED THEME FALLBACKS (Resolves startup warnings)
    // =========================================================================
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property color themeBase01: (shell && shell.theme && typeof shell.theme.base01 !== "undefined") ? shell.theme.base01 : "#1a1a1a"
    readonly property color themeBase02: (shell && shell.theme && typeof shell.theme.base02 !== "undefined") ? shell.theme.base02 : "gray"
    readonly property color themeBase05: (shell && shell.theme && typeof shell.theme.base05 !== "undefined") ? shell.theme.base05 : "yellow"
    // =========================================================================

    property int tooltipHeight: 280
    property int tooltipCollapsedWidth: 105
    property int tooltipExpandedWidth: 380
    property int tooltipTopOffset: -3
    property int tooltipRightOffset: 20

    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: borgBox.themeSlantWidth

    width: 140
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: borgBox.slantLeft
        slantRight: borgBox.slantRight
        slantWidth: borgBox.slantWidth
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            if (borgPoller.running) {
                borgPoller.running = false;
            }
            borgPoller.running = true;
        }
    }

    // JSON Status parser
    Process {
        id: borgPoller
        command: ["cat", "/dev/shm/borg-offsite-status.json"]

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                borgBox.borgProgress = "Idle"
                borgBox.syncStatus = "idle"
                borgBox.syncPercent = 0
                borgBox.tooltipLines = ["Status: Idle", "No active backup operations."]
            }
        }

        stdout: SplitParser {
            onRead: data => {
                const rawLine = data.trim()
                if (!rawLine.length) {
                    borgBox.borgProgress = "Idle"
                    borgBox.syncStatus = "idle"
                    borgBox.syncPercent = 0
                    borgBox.tooltipLines = ["Status: Idle", "No active backup operations."]
                    return
                }
                try {
                    const statusObj = JSON.parse(rawLine)
                    let lines = []

                    borgBox.syncStatus = statusObj.status || "idle"
                    borgBox.syncPercent = statusObj.percent !== undefined ? statusObj.percent : 0

                    if (statusObj.status === "idle") {
                        borgBox.borgProgress = "Idle"
                        lines.push("Status: Idle")
                        lines.push("No active backup operations.")
                    } else if (statusObj.status === "indexing") {
                        borgBox.borgProgress = "Idx..."
                        lines.push("Status: Indexing files...")
                        if (statusObj.archive_name) {
                            lines.push("Archive: " + statusObj.archive_name)
                        }
                    } else if (statusObj.status === "running") {
                        borgBox.borgProgress = statusObj.percent + "%"

                        lines.push("Status: Running Backup")
                        if (statusObj.archive_name) {
                            lines.push("Archive: " + statusObj.archive_name)
                        }
                        lines.push("Progress: " + statusObj.percent + "%")
                        if (statusObj.processed_files !== undefined && statusObj.total_files !== undefined) {
                            lines.push("Files: " + statusObj.processed_files + " / " + statusObj.total_files)
                        }
                        if (statusObj.speed) {
                            lines.push("Speed: " + statusObj.speed)
                        }
                        if (statusObj.eta) {
                            lines.push("ETA: " + statusObj.eta)
                        }
                    } else if (statusObj.status === "syncing") {
                        const pct = statusObj.percent !== undefined ? statusObj.percent : 0
                        borgBox.borgProgress = "Sync: " + pct + "%"

                        lines.push("Status: Syncing to Cloud")
                        lines.push("Progress: " + pct + "%")
                        if (statusObj.uploaded_size && statusObj.total_size) {
                            lines.push("Volume: " + statusObj.uploaded_size + " / " + statusObj.total_size)
                        }
                        if (statusObj.remaining_size) {
                            lines.push("Remaining: " + statusObj.remaining_size)
                        }
                        if (statusObj.speed) {
                            lines.push("Speed: " + statusObj.speed)
                        }
                        if (statusObj.eta) {
                            lines.push("ETA: " + statusObj.eta)
                        }
                    } else {
                        borgBox.borgProgress = "Sync..."
                        lines.push("Status: " + statusObj.status)
                    }

                    borgBox.tooltipLines = lines
                } catch (e) {
                    borgBox.borgProgress = "Sync..."
                    borgBox.tooltipLines = ["Status: Parsing Error", "Error: " + e.message]
                }
            }
        }
    }

    // Main capsule label text
    Text {
        id: borgText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: themePadding
        anchors.bottomMargin: themePadding

        text: {
            const fontColor = themeBase05.toString();
            if (borgBox.borgProgress === "Idx...") {
                return "<font color='" + fontColor + "'>Indexing</font>";
            } else if (borgBox.borgProgress === "Idle" || borgBox.borgProgress === "Sync...") {
                return "<font color='" + fontColor + "'>Borg:</font> <font color='" + fontColor + "'>" + borgBox.borgProgress + "</font>";
            } else {
                return "<font color='" + fontColor + "'>" + borgBox.borgProgress + "</font>";
            }
        }

        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        textFormat: Text.RichText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    HoverHandler {
        id: borgHoverTracker
        onHoveredChanged: {
            if (hovered && !borgPoller.running) {
                borgPoller.running = false;
                borgPoller.running = true;
            }
        }
    }

    // Tooltip Window (Directly Instantiated for smooth reverse collapse)
    SlantedTooltip {
        id: borgTooltip
        moduleItem: borgBox
        barWindow: borgBox.barWindow
        tooltipActive: borgHoverTracker.hovered
        pin: false

        alignSide: "Left"

        tooltipHeight: borgBox.tooltipHeight
        collapsedCoreWidth: borgBox.tooltipCollapsedWidth
        expandedCoreWidth: borgBox.tooltipExpandedWidth
        topOffset: borgBox.tooltipTopOffset
        rightOffset: borgBox.tooltipRightOffset

        slantLeft: borgBox.slantLeft
        slantRight: borgBox.slantRight

        Text {
            text: "BORG OFFSITE STATUS:"
            font.family: themeFontFamily
            font.pixelSize: themeFontSize - 1
            font.bold: true
            color: themeBase05
            y: 35
            x: borgTooltip.slantX(y) + 24
        }

        Rectangle {
            height: 2
            color: themeBase02
            width: 310
            y: 65
            x: borgTooltip.slantX(y) + 24
        }

        // Slanted Progress Bar container
        Rectangle {
            id: progressBarBg
            height: 15
            width: 310
            color: themeBase01
            border.color: themeBase05
            border.width: 3
            radius: 3
            y: 77
            x: borgTooltip.slantX(y) + 25

            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(
                    1, (borgBox.slantLeft === "Right" ? -borgBox.slantWidth : borgBox.slantWidth) / 25, 0, 0,
                                     0, 1, 0, 0,
                                     0, 0, 1, 0,
                                     0, 0, 0, 1
                )
            }

            Rectangle {
                id: progressBarFill
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 1
                height: parent.height - 2
                width: ((parent.width - 2) * borgBox.syncPercent) / 100
                color: themeBase05
                radius: 1
                visible: borgBox.syncStatus !== "indexing"

                Behavior on width {
                    NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                }
            }

            Rectangle {
                id: indeterminateFill
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height - 2
                width: 80
                color: themeBase05
                radius: 1
                visible: borgBox.syncStatus === "indexing"

                SequentialAnimation on x {
                    running: indeterminateFill.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 310 - 80 - 1; duration: 1000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 310 - 80 - 1; to: 1; duration: 1000; easing.type: Easing.InOutQuad }
                }
            }
        }

        Repeater {
            model: borgBox.tooltipLines.length
            Text {
                text: borgBox.tooltipLines[index]
                font.family: "monospace"
                font.pixelSize: themeFontSize - 1
                color: themeBase05
                y: 105 + (index * 28)
                x: borgTooltip.slantX(y) + 24
            }
        }
    }
}
