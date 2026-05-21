import QtQuick
import Quickshell.Pulse

Rectangle {
    id: audioBox
    width: 140

    property color colorLabelYellow: "#FFFF00"
    property color colorMuted: "#FF0000"

    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(audioBox);
        }
    }

    property string audioDisplayText: "VOL: --"

    PulseAudio {
        id: pulse
        onDefaultSinkChanged: {
            var name = pulse.defaultSink.description.replace(/\s/g, "");
            var muted = pulse.defaultSink.muted;
            var text = muted ? "<font color='" + audioBox.colorMuted + "'>MUTED</font>" : Math.round(pulse.defaultSink.volume * 100) + "%";
            audioBox.audioDisplayText = "<font color='" + audioBox.colorLabelYellow + "'>VOL:</font> " + text;
        }
    }

    Text { anchors.centerIn: parent; textFormat: Text.RichText; text: audioBox.audioDisplayText; font.family: "monospace"; font.pixelSize: 15; font.bold: true }
}
