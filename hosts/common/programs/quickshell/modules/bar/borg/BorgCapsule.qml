import QtQuick
import QtQuick.Controls
import "Borg.qml"

import Theme

Rectangle {
    id: borgCapsule

    // Sovereign sizing rules restore visibility and space matching your bar grid layout
    width: 140
    height: 35
    radius: 10
    border.width: 3

    // Direct memory lookups pointing straight to your immutable compiled Nix-Store colors
    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    border.color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "yellow"

    Borg {
        anchors.centerIn: parent
    }
}
