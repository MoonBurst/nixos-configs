import QtQuick

// Thin vertical divider between toolbar groups.
Rectangle {
    width: 1
    height: Style.buttonSize - 8
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    color: Style.panelBorder
}
