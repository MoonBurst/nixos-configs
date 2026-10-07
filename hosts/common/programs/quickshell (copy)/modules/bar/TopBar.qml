import QtQuick
import Quickshell
import Quickshell.Wayland

import "../style" as Style
import "./tray" as SystemTray
import "./battery" as BatteryCapsule
import "./ram" as RamCapsule
import "./gpu" as GpuCapsule
import "./cpu" as CpuCapsule
import "./network" as NetCapsule
import "./clock" as ClockCapsule
import "./sound" as SoundModule
import "./music" as MusicCapsule
import "./alarm" as AlarmCapsule
import "./notify" as NotifyCapsule
import "./weather" as WeatherCapsule
import "./calendar" as CalendarCapsule
import "./unified" as UnifiedMonitor
import "./custom" as CustomCapsule

PanelWindow {
    id: topBarWindow

    required property var shell
    readonly property var settingsManager: shell.settingsManager
    readonly property var theme: shell.theme

    visible: !shell.sessionLock.locked
    screen: shell.primaryScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: (settingsManager && settingsManager.barHeight > 0)
        ? settingsManager.barHeight
        : (theme.globalPadding + 32)
    color: "transparent"

    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Auto

    function applyCapsuleSlants(loadedItem, modelData, section) {
        if (!settingsManager || !loadedItem) return;
        var slantType = settingsManager.getModuleSlant(modelData, section) || "left";
        var sLeft = "Left";
        var sRight = "Left";
        var tAlign = "Left";

        if (slantType === "left") {
            sLeft = "Left"; sRight = "Left"; tAlign = "Left";
        } else if (slantType === "right") {
            sLeft = "Right"; sRight = "Right"; tAlign = "Right";
        } else if (slantType === "center") {
            sLeft = "Left"; sRight = "Right"; tAlign = "Center";
        }

        try {
            if ("slantLeft" in loadedItem) loadedItem.slantLeft = sLeft;
            if ("slantRight" in loadedItem) loadedItem.slantRight = sRight;
            if ("tooltipAlign" in loadedItem) loadedItem.tooltipAlign = tAlign;

            for (var i = 0; i < loadedItem.children.length; i++) {
                var c = loadedItem.children[i];
                if (c && (c.id === "bg" || ("slantLeft" in c && "leftPadding" in c))) {
                    c.slantLeft = sLeft;
                    c.slantRight = sRight;
                }
            }
        } catch(e) {}
    }

    Component { id: calendarFactory; CalendarCapsule.Calendar { barWindow: topBarWindow } }
    Component { id: musicFactory; MusicCapsule.Music { barWindow: topBarWindow } }
    Component { id: alarmFactory; AlarmCapsule.AlarmCapsule { barWindow: topBarWindow } }
    Component { id: weatherFactory; WeatherCapsule.Weather { barWindow: topBarWindow } }
    Component { id: unifiedFactory; UnifiedMonitor.UnifiedMonitor { barWindow: topBarWindow } }
    Component { id: notifyFactory; NotifyCapsule.NotifyCapsule { barWindow: topBarWindow } }
    Component { id: clockFactory; ClockCapsule.ClockCapsule { barWindow: topBarWindow } }
    Component { id: audioFactory; SoundModule.AudioCapsule { barWindow: topBarWindow } }
    Component { id: micFactory; SoundModule.MicCapsule { barWindow: topBarWindow } }
    Component { id: netFactory; NetCapsule.NetCapsule { barWindow: topBarWindow } }
    Component { id: cpuFactory; CpuCapsule.CpuCapsule { barWindow: topBarWindow } }
    Component { id: gpuFactory; GpuCapsule.GpuCapsule { barWindow: topBarWindow } }
    Component { id: ramFactory; RamCapsule.RamCapsule { barWindow: topBarWindow } }
    Component { id: trayFactory; SystemTray.Tray { barWindow: topBarWindow } }
    Component { id: batteryFactory; BatteryCapsule.BatteryCapsule { barWindow: topBarWindow } }
    Component { id: customFactory; CustomCapsule.CustomCapsule { barWindow: topBarWindow } }

    function getFactoryComponent(idStr) {
        var clean = idStr.toLowerCase();
        switch(clean) {
            case "calendar": return calendarFactory;
            case "music": return musicFactory;
            case "alarm": return alarmFactory;
            case "weather": return weatherFactory;
            case "unified": return unifiedFactory;
            case "notify":
            case "notifications": return notifyFactory;
            case "clock": return clockFactory;
            case "audio": return audioFactory;
            case "mic": return micFactory;
            case "net": return netFactory;
            case "cpu": return cpuFactory;
            case "gpu": return gpuFactory;
            case "ram": return ramFactory;
            case "tray": return trayFactory;
            case "battery": return batteryFactory;
            case "custom": return customFactory;
        }
        return null;
    }

    Style.SlantedBox {
        id: mainBarContainer
        anchors.fill: parent
        anchors.leftMargin: theme.globalPadding / 2
        anchors.rightMargin: theme.globalPadding / 2

        slantLeft: settingsManager.slantStyleMode === "all-right" ? "Right" : "Left"
        slantRight: settingsManager.slantStyleMode === "all-left" ? "Left" : "Right"

        slantWidth: theme.slantWidth * 1.5
        color: theme.base00
        borderColor: theme.base03
        borderWidth: theme.globalBorderWidth

        readonly property int capsuleHeight: height - (theme.globalBorderWidth * 2) - 8

        // Left Section
        Row {
            anchors.left: parent.left
            anchors.leftMargin: mainBarContainer.leftPadding
            anchors.verticalCenter: parent.verticalCenter
            height: mainBarContainer.capsuleHeight
            spacing: settingsManager.capsuleSpacing

            Repeater {
                model: settingsManager.barLeftModules
                delegate: Loader {
                    id: leftLoader
                    height: parent.height
                    active: settingsManager.isCapsuleVisible(modelData)
                    visible: active
                    width: { var cw = settingsManager ? settingsManager.getCapsuleBarWidth(modelData) : 0; if (cw > 0) return cw; return (active && item) ? item.implicitWidth : 0; }
                    sourceComponent: topBarWindow.getFactoryComponent(modelData)
                    onItemChanged: topBarWindow.applyCapsuleSlants(item, modelData, "left")
                    Component.onCompleted: topBarWindow.applyCapsuleSlants(item, modelData, "left")

                    Connections {
                        target: settingsManager
                        function onSlantRevisionChanged() { topBarWindow.applyCapsuleSlants(leftLoader.item, modelData, "left"); }
                    }
                }
            }
        }

        // Center Section
        Row {
            anchors.centerIn: parent
            height: mainBarContainer.capsuleHeight
            spacing: settingsManager.capsuleSpacing

            Repeater {
                model: settingsManager.barCenterModules
                delegate: Loader {
                    id: centerLoader
                    height: parent.height
                    active: settingsManager.isCapsuleVisible(modelData)
                    visible: active
                    width: { var cw = settingsManager ? settingsManager.getCapsuleBarWidth(modelData) : 0; if (cw > 0) return cw; return (active && item) ? item.implicitWidth : 0; }
                    sourceComponent: topBarWindow.getFactoryComponent(modelData)
                    onItemChanged: topBarWindow.applyCapsuleSlants(item, modelData, "center")
                    Component.onCompleted: topBarWindow.applyCapsuleSlants(item, modelData, "center")

                    Connections {
                        target: settingsManager
                        function onSlantRevisionChanged() { topBarWindow.applyCapsuleSlants(centerLoader.item, modelData, "center"); }
                    }
                }
            }
        }

        // Right Section
        Row {
            anchors.right: parent.right
            anchors.rightMargin: mainBarContainer.rightPadding
            anchors.verticalCenter: parent.verticalCenter
            height: mainBarContainer.capsuleHeight
            spacing: settingsManager.capsuleSpacing
            layoutDirection: Qt.RightToLeft

            Repeater {
                model: settingsManager.barRightModules
                delegate: Loader {
                    id: rightLoader
                    height: parent.height
                    active: settingsManager.isCapsuleVisible(modelData)
                    visible: active
                    width: { var cw = settingsManager ? settingsManager.getCapsuleBarWidth(modelData) : 0; if (cw > 0) return cw; return (active && item) ? item.implicitWidth : 0; }
                    sourceComponent: topBarWindow.getFactoryComponent(modelData)
                    onItemChanged: topBarWindow.applyCapsuleSlants(item, modelData, "right")
                    Component.onCompleted: topBarWindow.applyCapsuleSlants(item, modelData, "right")

                    Connections {
                        target: settingsManager
                        function onSlantRevisionChanged() { topBarWindow.applyCapsuleSlants(rightLoader.item, modelData, "right"); }
                    }
                }
            }
        }
    }
}
