import qs.Library
import qs.Utils
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import org.kde.kirigami.primitives

ListView {
    id: root
    height: 204
    width: 256
    clip: true
    y: 52
    Connections {
        target: StateManager
        function onShowLauncherChanged() {
            root.scale = 0;
            root.opacity = 0;
            root.y = -128;
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: 350
            easing.bezierCurve: Config.easing.standard
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 125
            easing.bezierCurve: Config.easing.standard
        }
    }
    populate: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 250
            easing.bezierCurve: Config.easing.standard
        }
    }
    add: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 200
            easing.bezierCurve: Config.easing.standard
        }
    }
    remove: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: 150
            easing.bezierCurve: Config.easing.standard
        }
    }
    displaced: Transition {
        NumberAnimation {
            properties: "y"
            duration: 200
            easing.bezierCurve: Config.easing.standard
        }
    }
    delegate: Item {
        id: container
        height: 204 / 4
        width: 256
        required property var modelData
        property bool selected: ListView.isCurrentItem
        states: [
            State {
                name: "selected"
                when: container.selected
                PropertyChanges {
                    target: delegated
                    width: parent.width - 8
                    height: parent.height - 8
                    color: Colors.color.primary
                }
                PropertyChanges {
                    target: content
                    color: Colors.color.background
                }
                PropertyChanges {
                    target: icon
                    color: Colors.color.background
                }
            }
        ]
        transitions: [
            Transition {
                from: ""
                to: "selected"
                reversible: true
                NumberAnimation {
                    properties: "width, height"
                    duration: 250
                    easing.bezierCurve: Config.easing.standard
                }
                ColorAnimation {
                    duration: 350
                    easing.bezierCurve: Config.easing.standard
                }
            }
        ]
        ClippingRectangle {
            id: delegated
            width: parent.width - 16
            height: parent.height - 16
            anchors.margins: 8
            radius: 8
            color: Colors.color.background
            clip: true
            anchors.centerIn: parent
            Text {
                id: content
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                width: 256 - 72
                elide: Text.ElideMiddle
                font.family: Config.font.family
                font.weight: 650
                color: Colors.color.primary
                z: 2
                text: modelData.name == undefined ? modelData.fileName : modelData.name
            }
            Icon {
                id: icon
                height: 24
                width: 24
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8
                isMask: true
                color: Colors.color.primary
                visible: modelData.icon !== undefined
                // DesktopEntry objects have execute(); custom mode objects use local SVGs
                source: {
                    if (modelData.icon === undefined)
                        return "";
                    if (typeof modelData.execute === "function")
                        return Quickshell.iconPath(modelData.icon, true);
                    return "root:Images/" + 'info' + ".svg";
                }
            }
            Item {
                height: 96
                width: 256
                anchors.right: parent.right
                visible: modelData.filePath !== undefined
                Image {
                    anchors.fill: parent
                    source: modelData.filePath !== undefined ? modelData.filePath : ""
                    asynchronous: true
                    layer.enabled: true
                    opacity: 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 500
                        }
                    }
                    onStatusChanged: {
                        if (status == Image.Ready) {
                            opacity = 1;
                        }
                    }
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 2
                        brightness: -0.05
                    }
                }
            }
        }
    }
}
