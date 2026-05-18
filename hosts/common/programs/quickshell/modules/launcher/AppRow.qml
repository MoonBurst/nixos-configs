import QtQuick
import QtQuick.Controls
import "../../" // Import root folder so Theme is visible

ItemDelegate {
    id: root
    property var entryData

    width: parent.width
    height: 45

    background: Rectangle {
        // Highlights if mouse hovers over it OR keyboard arrow targeting selects it
        color: (root.hovered || ListView.isCurrentItem) ? Theme.colorOutline : "transparent"
        radius: Theme.capsuleRadius / 2
    }

    contentItem: Row {
        spacing: 12
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10

        Image {
            source: root.entryData.icon ? "image://icon/" + root.entryData.icon : "../../resources/fallback.png"
            width: 24
            height: 24
            fillMode: Image.PreserveAspectFit
        }

        Text {
            text: root.entryData.name
            color: Theme.colorNormalText
            font.family: "monospace"
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
