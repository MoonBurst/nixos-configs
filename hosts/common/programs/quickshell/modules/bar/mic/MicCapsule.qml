import QtQuick
import Quickshell.Pulse

Rectangle {
    id: micBox
    width: 140

    property color colorLabelYellow: "#FFFF00"
    property color colorMuted: "#FF0000"

    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(micBox);
        }
    }

    property string micDisplayText: "MIC: --"

    PulseAudio {
        id: pulse
        onSourceChanged: {
            var name = pulse.source.description.replace(/\s/g, "");
            var muted = pulse.source.muted;
            var text = muted ? "<font color='" + micBox.colorMuted + "'>MUTED</font>" : (name.length > 10 ? name.substring(0, 10) + "..." : name);
            micBox.micDisplayText = "<font color='" + micBox.colorLabelYellow + "'>MIC:</font> " + text;
        }
    }

    Text { anchors.centerIn: parent; textFormat: Text.RichText; text: micBox.micDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }
}
