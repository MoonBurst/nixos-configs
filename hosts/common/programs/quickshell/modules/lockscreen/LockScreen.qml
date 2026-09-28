import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "../../"
import "../overlays/launcher" as Launcher
import Quickshell.Io

WlSessionLockSurface {
    id: windowSurface

    property var lockSession: null
    property var rootRef: null
    property bool isCapsLockActive: false
    property bool hasBattery: lockBat.hasBattery

    readonly property bool isPrimaryScreen: {
        if (!windowSurface || !windowSurface.screen) return false;
        var pScreen = (rootRef && rootRef.primaryScreen) ? rootRef.primaryScreen : (Quickshell.screens[0] || null);
        return pScreen ? windowSurface.screen.name === pScreen.name : true;
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Theme {
            id: stylixTheme
        }

        Launcher.BatteryEngine { id: lockBat }

        Process {
            id: capslockDetector
            running: true
            command: ["sh", "-c", "cat /sys/class/leds/*capslock*/brightness 2>/dev/null | grep -q '1' && echo 1 || echo 0"]
            stdout: SplitParser {
                onRead: data => {
                    windowSurface.isCapsLockActive = (data.trim() === "1");
                }
            }
        }

        Rectangle {
            id: secureOverlayBackground
            anchors.fill: parent
            color: "#0a0a0f"

            Rectangle {
                visible: windowSurface.hasBattery && windowSurface.isPrimaryScreen
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 32
                width: batRow.implicitWidth + 24
                height: 40
                radius: 8
                color: "#181825"
                border.width: 1.5
                border.color: (parseInt(lockBat.percent) <= 20 && lockBat.status === "Discharging") ? stylixTheme.base08 : stylixTheme.base05

                Row {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: lockBat.status === "Charging" ? "⚡" : (parseInt(lockBat.percent) <= 20 ? "🪫" : "🔋")
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: lockBat.percent + " (" + lockBat.power + ")"
                        color: (parseInt(lockBat.percent) <= 20 && lockBat.status === "Discharging") ? stylixTheme.base08 : stylixTheme.base05
                        font.family: stylixTheme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Loader {
                id: interfaceLoader
                anchors.centerIn: parent
                active: windowSurface.isPrimaryScreen
                sourceComponent: mainUserInterfaceComponent
            }
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_CapsLock) {
                windowSurface.isCapsLockActive = !windowSurface.isCapsLockActive;
            } else if (event.text !== "" && event.text.length === 1) {
                var c = event.text;
                var isShift = (event.modifiers & Qt.ShiftModifier) !== 0;
                if (c >= 'A' && c <= 'Z' && !isShift) windowSurface.isCapsLockActive = true;
                else if (c >= 'a' && c <= 'z' && !isShift) windowSurface.isCapsLockActive = false;
                else if (c >= 'A' && c <= 'Z' && isShift) windowSurface.isCapsLockActive = false;
            }

            if (!windowSurface || !windowSurface.screen || !windowSurface.rootRef) return;
            if (!windowSurface.isPrimaryScreen) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    lockPam.active = true;
                } else if (event.key === Qt.Key_Backspace) {
                    var str = windowSurface.rootRef.globalPasswordBuffer;
                    if (str.length > 0) {
                        windowSurface.rootRef.globalPasswordBuffer = str.substring(0, str.length - 1);
                        windowSurface.rootRef.passwordLength = windowSurface.rootRef.globalPasswordBuffer.length;
                    }
                } else if (event.text !== "") {
                    windowSurface.rootRef.globalPasswordBuffer += event.text;
                    windowSurface.rootRef.passwordLength = windowSurface.rootRef.globalPasswordBuffer.length;
                }
                event.accepted = true;
            }
        }
    }

    property Component mainUserInterfaceComponent: Component {
        ColumnLayout {
            id: centerFormContainer
            spacing: 40

            Timer {
                id: clockTimer
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    var d = new Date();
                    timeDisplay.text = d.toLocaleTimeString(Qt.locale(), "hh:mm");
                    dateDisplay.text = d.toLocaleDateString(Qt.locale(), "dddd, MMMM d");
                }
            }

            Component.onCompleted: {
                passwordField.forceActiveFocus();
                var d = new Date();
                timeDisplay.text = d.toLocaleTimeString(Qt.locale(), "hh:mm");
                dateDisplay.text = d.toLocaleDateString(Qt.locale(), "dddd, MMMM d");
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 5

                Text {
                    id: timeDisplay
                    text: "00:00"
                    color: stylixTheme.base05
                    font.pixelSize: stylixTheme.globalFontSize * 4
                    font.bold: true
                    font.family: stylixTheme.fontFamily
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    id: dateDisplay
                    text: "Date Loading..."
                    color: stylixTheme.base07
                    font.pixelSize: stylixTheme.globalFontSize * 1.2
                    font.family: stylixTheme.fontFamily
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 15

                TextField {
                    id: passwordField
                    echoMode: TextInput.Password
                    placeholderText: windowSurface.rootRef && windowSurface.rootRef.passwordLength === -1 ? "Authentication Failed..." : "Enter password..."
                    placeholderTextColor: windowSurface.rootRef && windowSurface.rootRef.passwordLength === -1 ? stylixTheme.base08 : stylixTheme.base04
                    width: stylixTheme.defaultCardWidth
                    height: 50

                    color: passwordField.activeFocus ? stylixTheme.base06 : "transparent"
                    font.pixelSize: stylixTheme.globalFontSize
                    font.family: stylixTheme.fontFamily
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    focus: true

                    text: windowSurface.rootRef ? windowSurface.rootRef.globalPasswordBuffer : ""
                    background: Rectangle {
                        implicitWidth: stylixTheme.defaultCardWidth
                        implicitHeight: 50
                        color: passwordField.activeFocus ? stylixTheme.base02 : stylixTheme.base01
                        border.color: windowSurface.rootRef && windowSurface.rootRef.passwordLength === -1 ? stylixTheme.base08 : (passwordField.activeFocus ? stylixTheme.base0D : stylixTheme.base04)
                        border.width: stylixTheme.globalBorderWidth
                        radius: stylixTheme.defaultCardRadius

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            visible: !passwordField.activeFocus && windowSurface.rootRef && windowSurface.rootRef.passwordLength > 0
                            spacing: 3

                            Repeater {
                                model: windowSurface.rootRef && windowSurface.rootRef.passwordLength > 0 ? windowSurface.rootRef.passwordLength : 0
                                Text {
                                    text: "•"
                                    color: stylixTheme.base06
                                    font.pixelSize: stylixTheme.globalFontSize
                                }
                            }
                        }
                    }

                    onTextEdited: {
                        if (windowSurface.rootRef) {
                            windowSurface.rootRef.globalPasswordBuffer = passwordField.text;
                            windowSurface.rootRef.passwordLength = passwordField.text.length;
                        }
                    }

                    Rectangle {
                        visible: windowSurface.isCapsLockActive
                        Layout.alignment: Qt.AlignHCenter
                        width: capsRow.implicitWidth + 20
                        height: 28
                        radius: 6
                        color: "#332200"
                        border.color: stylixTheme.base09
                        border.width: 1

                        Row {
                            id: capsRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "⇪"; color: stylixTheme.base09; font.bold: true; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "CAPS LOCK ACTIVE"; color: stylixTheme.base09; font.bold: true; font.pixelSize: 11; font.family: stylixTheme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    onAccepted: {
                        if (passwordField.text === "") return;
                        if (windowSurface.rootRef) {
                            windowSurface.rootRef.globalPasswordBuffer = passwordField.text;
                            windowSurface.rootRef.passwordLength = passwordField.text.length;
                        }
                        lockPam.active = true;
                    }
                }
            }
        }
    }
}
