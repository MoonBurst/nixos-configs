import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import "../../style"
import "../../overlays/launcher" as Launcher

Item {
    id: batBox
    property var barWindow: null
    property string moduleName: "battery"
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: (shell && shell.theme && shell.theme.slantWidth) ? shell.theme.slantWidth : 12

    readonly property color themeBase05: (shell && shell.theme) ? shell.theme.base05 : "yellow"
    readonly property color themeBase08: (shell && shell.theme) ? shell.theme.base08 : "#ff0000"
    readonly property color themeBase09: (shell && shell.theme) ? shell.theme.base09 : "#fe8019"
    readonly property color themeBase0C: (shell && shell.theme) ? shell.theme.base0C : "#04f100"
    readonly property int themeFontSize: (shell && shell.theme) ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"

    Launcher.BatteryEngine { id: batEngine }

    property string activeProfile: "balanced"

    Process {
        id: profileGetter
        running: true
        command: ["powerprofilesctl", "get"]
        stdout: SplitParser {
            onRead: data => { if (data && data.trim()) batBox.activeProfile = data.trim(); }
        }
    }

    readonly property int numPercent: parseInt(batEngine.percent) || 0
    readonly property bool isLow: numPercent <= 20 && batEngine.status === "Discharging"
    readonly property bool isWarning: numPercent <= 40 && batEngine.status === "Discharging"

    readonly property color statusColor: {
        if (batEngine.status === "Charging" || batEngine.status === "Full") return batBox.themeBase0C;
        if (isLow) return batBox.themeBase08;
        if (isWarning) return batBox.themeBase09;
        return batBox.themeBase05;
    }

    visible: batEngine.hasBattery
    implicitWidth: visible ? (batText.implicitWidth + bg.leftPadding + bg.rightPadding + 20) : 0
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: batBox.slantLeft
        slantRight: batBox.slantRight
        slantWidth: batBox.slantWidth
        borderColor: batBox.statusColor
    }

    Text {
        id: batText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 4
        anchors.rightMargin: bg.rightPadding + 4
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        textFormat: Text.RichText

        text: {
            var icon = batEngine.status === "Charging" ? "⚡ " : (batBox.numPercent <= 20 ? "🪫 " : "🔋 ");
            return "<font color='" + batBox.themeBase05 + "'>" + icon + "BAT:</font> <font color='" + batBox.statusColor + "'>" + batEngine.percent + " (" + batEngine.power + ")</font>";
        }

        font.family: batBox.themeFontFamily
        font.pixelSize: batBox.themeFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        clip: true
    }

    HoverHandler { id: batHover }

    Process {
        id: powerProfileProc
        running: false
        onExited: profileGetter.running = true
    }

    SlantedTooltip {
        id: batTooltip
        moduleItem: batBox
        barWindow: batBox.barWindow
        tooltipActive: batHover.hovered
        alignSide: "Right"

        tooltipHeight: 180
        collapsedCoreWidth: 160
        expandedCoreWidth: 420
        topOffset: -2
        slantLeft: batBox.slantLeft
        slantRight: batBox.slantRight

        Text {
            y: 20
            x: batTooltip.slantX(y) + 20
            text: "⚡ BATTERY & POWER PROFILES"
            font.family: batBox.themeFontFamily
            font.pixelSize: Math.max(16, batBox.themeFontSize + 1)
            font.bold: true
            color: batBox.themeBase05
        }

        Text {
            y: 50
            x: batTooltip.slantX(y) + 20
            text: "Status: " + batEngine.status + " | Draw: " + batEngine.power
            font.family: "monospace"
            font.pixelSize: Math.max(14, batBox.themeFontSize - 1)
            color: batBox.themeBase05
            opacity: 0.85
        }

        RowLayout {
            y: 90
            x: batTooltip.slantX(y) + 20
            width: batTooltip.effectiveCoreWidth - 40
            spacing: 8

            // Performance
            Rectangle {
                readonly property bool isCurrent: batBox.activeProfile === "performance"
                Layout.fillWidth: true; height: 36; radius: 4
                color: isCurrent ? batBox.themeBase08 : (pPerf.containsMouse ? "#2a1e1e" : "#181825")
                border.color: batBox.themeBase08; border.width: 1.5
                Text {
                    anchors.centerIn: parent
                    text: isCurrent ? "⚡ Perf (On)" : "⚡ Perf"
                    font.bold: true; font.pixelSize: 12
                    color: isCurrent ? "#000000" : batBox.themeBase08
                }
                MouseArea {
                    id: pPerf; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { powerProfileProc.command = ["powerprofilesctl", "set", "performance"]; powerProfileProc.running = true; }
                }
            }

            // Balanced
            Rectangle {
                readonly property bool isCurrent: batBox.activeProfile === "balanced"
                Layout.fillWidth: true; height: 36; radius: 4
                color: isCurrent ? batBox.themeBase05 : (pBal.containsMouse ? "#2a2818" : "#181825")
                border.color: batBox.themeBase05; border.width: 1.5
                Text {
                    anchors.centerIn: parent
                    text: isCurrent ? "⚖ Bal (On)" : "⚖ Bal"
                    font.bold: true; font.pixelSize: 12
                    color: isCurrent ? "#000000" : batBox.themeBase05
                }
                MouseArea {
                    id: pBal; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { powerProfileProc.command = ["powerprofilesctl", "set", "balanced"]; powerProfileProc.running = true; }
                }
            }

            // Power Saver
            Rectangle {
                readonly property bool isCurrent: batBox.activeProfile === "power-saver"
                Layout.fillWidth: true; height: 36; radius: 4
                color: isCurrent ? batBox.themeBase0C : (pSav.containsMouse ? "#182a1e" : "#181825")
                border.color: batBox.themeBase0C; border.width: 1.5
                Text {
                    anchors.centerIn: parent
                    text: isCurrent ? "🍃 Saver (On)" : "🍃 Saver"
                    font.bold: true; font.pixelSize: 12
                    color: isCurrent ? "#000000" : batBox.themeBase0C
                }
                MouseArea {
                    id: pSav; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { powerProfileProc.command = ["powerprofilesctl", "set", "power-saver"]; powerProfileProc.running = true; }
                }
            }
        }
    }
}
