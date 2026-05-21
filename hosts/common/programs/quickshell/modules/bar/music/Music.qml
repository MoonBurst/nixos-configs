 import QtQuick
 import Quickshell
 import Quickshell.Io

 Rectangle {
     id: musicCapsule

     width: 180

     clip: true

     property string currentSongText: "No Song Playing"

     Component.onCompleted: {
         if (typeof(root.applyCapsuleTheme) !== "undefined") {
             root.applyCapsuleTheme(musicCapsule, musicText);
         }
     }

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
         font.pixelSize: 20
         font.bold: true
         elide: Text.ElideRight
         width: parent.width - 20
     }
 }
