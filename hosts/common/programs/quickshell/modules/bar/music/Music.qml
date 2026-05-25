import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Rectangle {
    id: musicBox

    property var barWindow: null
    property string trackStr: "No Track"
    property string tooltipTitle: "No Title Playing"
    property string tooltipArtist: "No Artist Data"

    // Toggle flag to keep tracking state persistent on click
    property bool popupActive: false

    width: 200
    height: parent.height
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth
    color: shell.theme.base00
    border.color: shell.theme.base05

    // Core Playerctl Metadata Query Loop
    Process {
        id: musicProc
        running: true
        command: ["sh", "-c", "playerctl metadata --format '{{ title }}|{{ artist }}' 2>/dev/null || echo 'No Track|Unknown Artist'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim() !== "") {
                    var parts = data.trim().split("|");
                    var rawTitle = parts[0] ? parts[0] : "No Track";
                    var rawArtist = parts[1] ? parts[1] : "Unknown Artist";

                    musicBox.tooltipTitle = rawTitle;
                    musicBox.tooltipArtist = rawArtist;
                    musicBox.trackStr = (rawArtist + " - " + rawTitle).substring(0, 15);
                }
            }
        }
    }

    // Top Bar Capsule Display Typography
    Text {
        id: musicText
        anchors.fill: parent
        anchors.margins: 5
        color: shell.theme.base05
        text: "🎵 " + musicBox.trackStr
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize - 2
        font.bold: true
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: {
            musicProc.running = false;
            musicProc.running = true;
        }
    }

    // Click interactive handler
    TapHandler {
        onTapped: musicBox.popupActive = !musicBox.popupActive
    }

    // ============================================================================
    // INLINE COMPONENT BLOCK
    // ============================================================================
    Component {
        id: musicTooltipViewComponent

        Rectangle {
            id: tooltipCardRoot
            radius: shell.theme.defaultCardRadius ?? 8
            border.width: shell.theme.globalBorderWidth ?? 3
            color: shell.theme.base00 ?? "black"
            border.color: shell.theme.base05 ?? "yellow"

            // Media Control Sub-processes
            Process { id: playPauseProc; command: ["playerctl", "play-pause"] }
            Process { id: prevProc; command: ["playerctl", "previous"] }
            Process { id: nextProc; command: ["playerctl", "next"] }

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                // Dynamic Header Track Title & Artist Metadata Bubble
                Rectangle {
                    width: parent.width
                    height: 70
                    radius: shell.theme.defaultCardRadius ?? 8
                    border.width: shell.theme.globalBorderWidth ?? 3
                    color: "transparent"
                    border.color: tooltipCardRoot.border.color

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 4

                        Text {
                            width: parent.width
                            text: musicBox.tooltipTitle
                            font.family: shell.theme.fontFamily ?? "monospace"
                            font.pixelSize: 18
                            font.bold: true
                            color: tooltipCardRoot.border.color
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: musicBox.tooltipArtist
                            font.family: shell.theme.fontFamily ?? "monospace"
                            font.pixelSize: 14
                            color: tooltipCardRoot.border.color
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                // Interactive Media Player Layout Controls Row
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 20

                    Repeater {
                        model: [
                            { icon: "⏮", proc: prevProc },
                            { icon: "⏯", proc: playPauseProc },
                            { icon: "⏭", proc: nextProc }
                        ]

                        delegate: Rectangle {
                            width: 60
                            height: 40
                            radius: shell.theme.defaultCardRadius ?? 4
                            border.width: shell.theme.globalBorderWidth ?? 2
                            color: "transparent"
                            border.color: tooltipCardRoot.border.color

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.pixelSize: 20
                                color: parent.border.color
                            }

                            TapHandler {
                                onTapped: modelData.proc.running = true
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================================
    // THE MUSIC HUB PANEL WINDOW OVERLAY LAYER
    // ============================================================================
    PanelWindow {
        id: musicTooltipWindow

        screen: musicBox.barWindow ? musicBox.barWindow.screen : null
        visible: musicBox.popupActive

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-music-tooltip"

        WlrLayershell.keyboardFocus: musicBox.popupActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors.top: true
        anchors.left: true
        anchors.right: false
        anchors.bottom: false

        implicitWidth: 400
        implicitHeight: 180
        color: "transparent"

        Shortcut {
            sequence: "Escape"
            enabled: musicBox.popupActive
            onActivated: musicBox.popupActive = false
        }

        WlrLayershell.margins.top: {
            if (!musicBox.barWindow || typeof mainBarContainer === "undefined" || !mainBarContainer) return 100;
            return shell.theme.globalPadding + mainBarContainer.capsuleHeight + 8;
        }

        WlrLayershell.margins.left: {
            if (!musicBox.barWindow) return 100;

            var containerX = musicBox.x;
            var musicCenterAbsolute = containerX + (musicBox.width / 2);
            var targetLeftMargin = Math.round(musicCenterAbsolute - (implicitWidth / 2));

            if (targetLeftMargin < shell.theme.globalPadding) {
                return shell.theme.globalPadding;
            }

            return targetLeftMargin;
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: musicTooltipViewComponent
        }
    }
}
