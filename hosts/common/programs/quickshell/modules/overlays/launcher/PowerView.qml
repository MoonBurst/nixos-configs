import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: powerRoot
    anchors.fill: parent

    property var shell: null
    readonly property var theme: (shell && shell.theme) ? shell.theme : null

    property string searchQuery: ""
    property int selectedIndex: 0
    property string confirmingId: ""

    signal actionCompleted()

    readonly property var allActions: [
        {
            id: "lock",
            icon: "🔒",
            title: "Lock Session",
            description: "Lock the desktop using Quickshell PAM",
            accent: theme ? theme.base0D : "#675DDB",
            keywords: ["lock", "screen", "session"],
            destructive: false
        },
        {
            id: "sleep",
            icon: "🌙",
            title: "Suspend / Sleep",
            description: "Enter low-power standby mode",
            accent: theme ? theme.base0A : "#FABD2F",
            keywords: ["sleep", "suspend", "standby"],
            destructive: false
        },
        {
            id: "logout",
            icon: "🚪",
            title: "Log Out",
            description: "Exit Sway and terminate graphical session",
            accent: theme ? theme.base09 : "#FE8019",
            keywords: ["logout", "exit", "quit", "leave"],
            destructive: true
        },
        {
            id: "reboot",
            icon: "🔄",
            title: "Reboot System",
            description: "Cleanly restart the machine and boot loader",
            accent: theme ? theme.base05 : "#F7F700",
            keywords: ["reboot", "restart"],
            destructive: true
        },
        {
            id: "shutdown",
            icon: "⏻",
            title: "Power Off",
            description: "Shut down system services and turn off hardware",
            accent: theme ? theme.base08 : "#FF0000",
            keywords: ["shutdown", "poweroff", "power", "off", "halt"],
            destructive: true
        }
    ]

    readonly property var filteredActions: {
        var q = searchQuery.toLowerCase().trim();
        // Strip common prefix triggers
        if (q.startsWith("pwr ")) q = q.substring(4).trim();
        if (q.startsWith("power ")) q = q.substring(6).trim();

        if (q === "" || q === "power" || q === "pwr" || q === "sys" || q === "session") {
            return allActions;
        }

        return allActions.filter(function(action) {
            if (action.title.toLowerCase().indexOf(q) !== -1) return true;
            for (var i = 0; i < action.keywords.length; i++) {
                if (action.keywords[i].indexOf(q) !== -1) return true;
            }
            return false;
        });
    }

    onSearchQueryChanged: {
        selectedIndex = 0;
        confirmingId = "";
    }

    function selectNext() {
        if (filteredActions.length > 0) {
            selectedIndex = (selectedIndex + 1) % filteredActions.length;
            confirmingId = "";
        }
    }

    function selectPrev() {
        if (filteredActions.length > 0) {
            selectedIndex = (selectedIndex - 1 + filteredActions.length) % filteredActions.length;
            confirmingId = "";
        }
    }

    function executeSelected() {
        if (selectedIndex < 0 || selectedIndex >= filteredActions.length) return;
        var act = filteredActions[selectedIndex];

        if (act.destructive && confirmingId !== act.id) {
            confirmingId = act.id;
            return;
        }

        confirmingId = "";
        triggerAction(act.id);
    }

    function triggerAction(actionId) {
        if (actionId === "lock") {
            Quickshell.execDetached([
                "quickshell", "-p",
                "/home/moonburst/nix/hosts/common/programs/quickshell/shell.qml",
                "ipc", "call", "lockscreen", "lock"
            ]);
        } else if (actionId === "sleep") {
            Quickshell.execDetached(["systemctl", "suspend"]);
        } else if (actionId === "logout") {
            Quickshell.execDetached(["swaymsg", "exit"]);
        } else if (actionId === "reboot") {
            Quickshell.execDetached(["systemctl", "reboot"]);
        } else if (actionId === "shutdown") {
            Quickshell.execDetached(["systemctl", "poweroff"]);
        }
        powerRoot.actionCompleted();
    }

    ListView {
        id: powerListView
        anchors.fill: parent
        clip: true
        spacing: 14
        model: powerRoot.filteredActions
        currentIndex: powerRoot.selectedIndex

        delegate: Rectangle {
            id: actionCard
            readonly property var actionData: modelData
            readonly property bool isSelected: index === powerRoot.selectedIndex
            readonly property bool isConfirming: powerRoot.confirmingId === actionData.id

            width: powerListView.width - 16
            height: 90
            radius: theme ? theme.defaultCardRadius : 10

            color: isSelected ? (theme ? theme.base02 : "#222222") : "transparent"
            border.width: isSelected ? (theme ? theme.globalBorderWidth + 2 : 5) : 1
            border.color: isConfirming ? (theme ? theme.base08 : "#FF0000") : (isSelected ? actionData.accent : (theme ? theme.base03 : "#333333"))

            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                Text {
                    text: actionData.icon
                    font.pixelSize: 32
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: isConfirming ? "⚠️ Press [Enter] again to Confirm " + actionData.title : actionData.title
                        font.family: theme ? theme.fontFamily : "Fira Sans"
                        font.pixelSize: 22
                        font.bold: true
                        color: isConfirming ? (theme ? theme.base08 : "#FF0000") : (isSelected ? actionData.accent : (theme ? theme.base05 : "yellow"))
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: actionData.description
                        font.family: theme ? theme.fontFamily : "Fira Sans"
                        font.pixelSize: 15
                        color: theme ? theme.base06 : "#cccccc"
                        opacity: 0.75
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    width: 38
                    height: 28
                    radius: 6
                    color: isSelected ? actionData.accent : "transparent"
                    border.width: 1
                    border.color: actionData.accent
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "⏎"
                        font.bold: true
                        font.pixelSize: 16
                        color: isSelected ? (theme ? theme.base00 : "black") : actionData.accent
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    powerRoot.selectedIndex = index;
                    powerRoot.executeSelected();
                }
            }
        }
    }
}
