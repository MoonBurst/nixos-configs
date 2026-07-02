import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "../../"

WlSessionLockSurface {
    id: windowSurface

    property var lockSession: null
    property var rootRef: null

    FocusScope {
        anchors.fill: parent
        focus: true

        Theme {
            id: stylixTheme
        }

        Rectangle {
            id: secureOverlayBackground
            anchors.fill: parent
            color: "#0a0a0f"

            Loader {
                id: interfaceLoader
                anchors.centerIn: parent
                active: (windowSurface.screen && (windowSurface.screen.name === "DP-1" || windowSurface.screen.name === "eDP-1"))
                sourceComponent: mainUserInterfaceComponent
            }
        }

        Keys.onPressed: (event) => {
            if (windowSurface.screen && windowSurface.screen.name !== "DP-1" && windowSurface.screen.name !== "eDP-1" && windowSurface.rootRef) {
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
