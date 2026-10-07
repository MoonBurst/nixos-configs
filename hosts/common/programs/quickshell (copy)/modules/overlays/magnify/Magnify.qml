import "../../common" as Common
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

    // Public in-memory control API
    function toggle() { rootState.active = !rootState.active; }
    function show() { rootState.active = true; }
    function hide() { rootState.active = false; }

    QtObject {
        id: rootState
        property bool active: false
        property real zoomFactor: (typeof shell !== "undefined" && shell && shell.settingsManager) ? shell.settingsManager.magnifierDefaultZoom : 8.0
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            // Controlled purely by native state
            visible: rootState.active

            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay

            // Only grab keyboard focus when active
            WlrLayershell.keyboardFocus: rootState.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            ScreencopyView {
                id: shot
                anchors.fill: parent
                captureSource: win.modelData
                live: false
                paintCursor: false
            }

            Connections {
                target: rootState
                function onActiveChanged() {
                    if (rootState.active) {
                        shot.captureFrame();
                        mouseArea.forceActiveFocus();
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.BlankCursor

                onWheel: function(wheel) {
                    var step = 1.0;
                    if (wheel.angleDelta.y > 0) {
                        rootState.zoomFactor = Math.min(30.0, rootState.zoomFactor + step);
                    } else if (wheel.angleDelta.y < 0) {
                        rootState.zoomFactor = Math.max(2.0, rootState.zoomFactor - step);
                    }
                }

                focus: true
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        rootState.active = false;
                    }
                }
            }

            // Magnifier Box Container
            Item {
                id: magnifier
                width: (typeof shell !== 'undefined' && shell && shell.settingsManager) ? shell.settingsManager.magnifierLensSize : 300
                height: width
                x: mouseArea.mouseX - width / 2
                y: mouseArea.mouseY - height / 2
                visible: shot.hasContent && mouseArea.containsMouse

                // 1. Masking Container (Clips all child content to a circle)
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#151515"
                    clip: true
                    layer.enabled: true // Performs the actual circular alpha mask

                    ShaderEffectSource {
                        id: zoomSource
                        anchors.fill: parent
                        sourceItem: shot
                        live: true
                        smooth: false

                        property real sourceW: parent.width / rootState.zoomFactor
                        property real sourceH: parent.height / rootState.zoomFactor

                        sourceRect: Qt.rect(
                            mouseArea.mouseX - sourceW / 2,
                            mouseArea.mouseY - sourceH / 2,
                            sourceW,
                            sourceH
                        )
                    }

                    // Central targeting square (rendered inside the circle)
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width / rootState.zoomFactor
                        height: parent.height / rootState.zoomFactor
                        color: "transparent"
                        border.color: "red"
                        border.width: 1
                    }
                }

                // 2. Circular Outline (Drawn ON TOP of all clipped contents)
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: "white"
                    border.width: 3
                    z: 10 // Explicitly stacked on top
                }
            }
        }
    }
}
