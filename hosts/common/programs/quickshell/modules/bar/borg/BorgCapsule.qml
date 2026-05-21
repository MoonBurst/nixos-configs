import QtQuick
import QtQuick.Controls
import "Borg.qml"

Rectangle {
    id: borgCapsule
    width: 50

    Component.onCompleted: {
        if (typeof(root.applyCapsuleTheme) !== 'undefined') {
            root.applyCapsuleTheme(borgCapsule);
        }
    }

    Borg {
        anchors.centerIn: parent
    }
}
