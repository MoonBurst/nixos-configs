import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: musicCapsule
    color: Theme.colorBaseBg
    radius: Theme.capsuleRadius
    border.width: Theme.capsuleBorderWidth
    border.color: Theme.colorOutline
    
    // Explicit sizing constraint rules prevent text from overflowing into neighbors
    width: 180
    height: Theme.capsuleHeight
    anchors.verticalCenter: parent.verticalCenter
    
    // Force canvas boundaries to cut off long track names cleanly
    clip: true

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
        stdout: SplitParser { onRead: data => { if (data) musicCapsule.currentSongText = data.trim(); } }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: musicFetcher.running = true
    }

    TapHandler { onTapped: { musicToggleCmd.running = false; musicToggleCmd.running = true; } }
    
    Text { 
        anchors.centerIn: parent 
        text: musicCapsule.currentSongText 
        color: Theme.colorNormalText 
        font.pixelSize: 15 
        font.bold: true 
        
        // Adds clean retro dot structures (...) if a track name is too wide
        elide: Text.ElideRight
        width: parent.width - 20
    }
}
