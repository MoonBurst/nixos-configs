import qs.Library
import qs.Utils
import "root:Utils/fuzzy.js" as Fuzzy
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 256
    height: 48
    property bool empty: entry.text.length == 0
    property string content: entry.text
    property string mode: "app"
    scale: 0
    Behavior on scale {
        NumberAnimation {
            duration: 250
            easing.bezierCurve: Config.easing.standard
        }
    }
    Component.onCompleted: {
        scale = 1;
    }
    Connections {
        target: StateManager
        function onShowLauncherChanged() {
            scale = 0;
        }
    }
    Rectangle {
        id: back
        anchors.fill: root
        color: Colors.color.background
        radius: 12
    }
    TextInput {
        id: entry
        focus: true
        onTextChanged: {
            root.empty = text.length == 0;
        }
        anchors.fill: root
        anchors.margins: 8
        anchors.right: parent.right
        anchors.rightMargin: 48
        verticalAlignment: Text.AlignVCenter
        z: 2
        color: Colors.color.primary
        font.family: Config.font.family
        font.pointSize: 10
        font.variableAxes: {
            "wght": 600
        }
    }

    IconButton {
        id: searchBtn
        anchors.verticalCenter: parent.verticalCenter
        colPrimary: root.empty ? 'transparent' : Colors.color.surface_container_low
        Behavior on colPrimary {
            ColorAnimation {
                duration: 250
            }
        }
        Behavior on colIcon {
            ColorAnimation {
                duration: 175
            }
        }
        colDown: Colors.color.on_primary
        colDownIcon: Colors.color.primary_container
        colIcon: root.empty ? Colors.color.surface_container : Colors.color.surface_variant
        anchors.right: parent.right
        anchors.rightMargin: 8
        iconName: {
            switch (root.content[0]) {
            case "#":
                return 'calculate';
                break;
            case "?":
                return 'info';
                break;
            case ">":
                return 'terminal';
                break;
            case ":":
                return 'palette';
            default:
                return 'search';
            }
        }
        animScale: 1.125
        animRotation: 0
    }

    Text {
        opacity: entry.text.length <= 1 ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 250
            }
        }
        font.family: Config.font.family
        font.pointSize: 10
        font.weight: 600
        color: Colors.color.surface_variant
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.leftMargin: 8
        text: {
            switch (root.mode) {
            case "wallpaper":
                return ": Set wallpaper...";
            case "calc":
                return "# Calculate...";
            case "shell":
                return "> Run command...";
            case "search":
                return "? Search Google...";
            default:
                return "Search for something...";
            }
        }
    }
}
