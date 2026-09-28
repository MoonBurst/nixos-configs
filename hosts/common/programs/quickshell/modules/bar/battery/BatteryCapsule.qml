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

    property string currentProfile: "balanced"
    property bool hasPowerProfilesDaemon: false

    Launcher.BatteryEngine {
        id: batEngine
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

    implicitWidth: batText.implicitWidth + bg.leftPadding + bg.rightPadding + 20
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

    // Safe detection that never fails if powerprofilesctl is missing
    Process {
        id: profileChecker
        running: true
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl get 2>/dev/null || echo ''"]
        stdout: SplitParser {
            onRead: data => {
                var p = (data || "").trim();
                if (p.length > 0) {
                    batBox.hasPowerProfilesDaemon = true;
                    batBox.currentProfile = p;
                } else {
                    batBox.hasPowerProfilesDaemon = false;
                }
            }
        }
    }

    Process { id: powerProfileProc; running: false }

    function setProfile(name) {
        batBox.currentProfile = name;
        powerProfileProc.command = ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl set " + name + " || true"];
        powerProfileProc.running = true;
    }

    SlantedTooltip {
        id: batTooltip
        moduleItem: batBox
        barWindow: batBox.barWindow
        tooltipActive: batHover.hovered
        alignSide: "Right"

        tooltipHeight: 200
        expandedCoreWidth: 420
        topOffset: -2
        slantLeft: batBox.slantLeft
        slantRight: batBox.slantRight

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            Text {
                text: "⚡ BATTERY STATUS"
                font.family: batBox.themeFontFamily
                font.pixelSize: batBox.themeFontSize - 1
                font.bold: true
                color: batBox.themeBase05
            }

            Text {
                text: "Status: " + batEngine.status + " | Power: " + batEngine.power + " | Level: " + batEngine.percent
                font.family: "monospace"
                font.pixelSize: 12
                color: batBox.themeBase05
                opacity: 0.85
            }

            Text {
                visible: batBox.hasPowerProfilesDaemon
                text: "Power Profile: " + batBox.currentProfile.toUpperCase()
                font.family: "monospace"
                font.pixelSize: 11
                color: batBox.themeBase0C
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: batBox.hasPowerProfilesDaemon

                // Performance Button
                Rectangle {
                    id: pPerfRect
                    readonly property bool isCurrent: batBox.currentProfile === "performance"
                    Layout.fillWidth: true; height: 28; radius: 4
                    color: isCurrent ? batBox.themeBase08 : (pPerf.containsMouse ? "#313244" : "#181825")
                    border.color: batBox.themeBase08; border.width: isCurrent ? 2 : 1
                    Text { anchors.centerIn: parent; text: "⚡ Perf"; font.bold: true; font.pixelSize: 11; color: pPerfRect.isCurrent ? "#000000" : batBox.themeBase08 }
                    MouseArea { id: pPerf; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: batBox.setProfile("performance") }
                }

                // Balanced Button
                Rectangle {
                    id: pBalRect
                    readonly property bool isCurrent: batBox.currentProfile === "balanced"
                    Layout.fillWidth: true; height: 28; radius: 4
                    color: isCurrent ? batBox.themeBase05 : (pBal.containsMouse ? "#313244" : "#181825")
                    border.color: batBox.themeBase05; border.width: isCurrent ? 2 : 1
                    Text { anchors.centerIn: parent; text: "⚖ Bal"; font.bold: true; font.pixelSize: 11; color: pBalRect.isCurrent ? "#000000" : batBox.themeBase05 }
                    MouseArea { id: pBal; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: batBox.setProfile("balanced") }
                }

                // Power-Saver Button
                Rectangle {
                    id: pSavRect
                    readonly property bool isCurrent: batBox.currentProfile === "power-saver"
                    Layout.fillWidth: true; height: 28; radius: 4
                    color: isCurrent ? batBox.themeBase0C : (pSav.containsMouse ? "#313244" : "#181825")
                    border.color: batBox.themeBase0C; border.width: isCurrent ? 2 : 1
                    Text { anchors.centerIn: parent; text: "🍃 Saver"; font.bold: true; font.pixelSize: 11; color: pSavRect.isCurrent ? "#000000" : batBox.themeBase0C }
                    MouseArea { id: pSav; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: batBox.setProfile("power-saver") }
                }
            }
        }
    }
}
