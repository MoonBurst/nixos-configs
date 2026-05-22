import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io

import Theme

Rectangle {
    id: musicCapsule

    // Sovereign styling constraints restore capsule visibility independent of shell.qml management
    width: 180
    height: 35
    radius: 10
    border.width: 3
    clip: true

    // Direct lookups pointing straight to your immutable compiled Nix-Store colors
    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

    property string currentSongText: "No Song Playing"

    Process { id: musicToggleCmd; command: ["/bin/sh", "-c", "audtool current-song >/dev/null 2>&1 && ( [ \"$(audtool playback-status)\" = \"playing\" ] && audtool playback-pause || audtool playback-play ) || ( audacious & sleep 2 && audtool mainwin-show on && audtool playback-play )"] }

    Process {
        id: musicFetcher
        running: true
        command: [
            "sh", "-c",
            "if audtool current-song >/dev/null 2>&1; then " +
            "  [ \"$(audtool playback-status)\" = \"playing\" ] && p=\"▶ \" || p=\"⏸ \"; echo \"$p$(audtool current-song)\"; " +
            "else echo \"Music Offline\"; fi"
        ]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    musicCapsule.currentSongText = data.trim()
                }
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: musicFetcher.running = true
    }

    TapHandler { onTapped: { musicToggleCmd.running = false; musicToggleCmd.running = true; } }

    Text {
        id: musicText
        anchors.centerIn: parent
        text: musicCapsule.currentSongText
        font.family: "monospace"
        font.pixelSize: 20
        font.bold: true
        elide: Text.ElideRight
        width: parent.width - 20
        horizontalAlignment: Text.AlignHCenter
        color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "white"
    }
}
