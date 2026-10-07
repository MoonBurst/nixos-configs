import QtQuick
import Quickshell

QtObject {
    id: engine

    property int selectedIndex: 0
    property string confirmingId: ""

    readonly property var allActions: [
        { id: "lock",     icon: "🔒", title: "Lock Session",    description: "Lock screen using PAM authentication",  destructive: false },
        { id: "sleep",    icon: "🌙", title: "Suspend / Sleep", description: "Enter low-power system standby",       destructive: false },
        { id: "logout",   icon: "🚪", title: "Log Out",         description: "Exit current compositor session",      destructive: true  },
        { id: "reboot",   icon: "🔄", title: "Reboot System",   description: "Restart computer and operating system", destructive: true  },
        { id: "shutdown", icon: "⏻",  title: "Power Off",       description: "Completely power down the hardware",    destructive: true  }
    ]

    function execute(act) {
        if (!act) return false;
        if (act.destructive && confirmingId !== act.id) {
            confirmingId = act.id;
            return false;
        }
        confirmingId = "";

        if (act.id === "lock") {
            Quickshell.execDetached(["sh", "-c", "QS=$(command -v qs || command -v quickshell); [ -n \"$QS\" ] && \"$QS\" ipc call lockscreen lock"]);
        } else if (act.id === "sleep") {
            Quickshell.execDetached(["systemctl", "suspend"]);
        } else if (act.id === "logout") {
            Quickshell.execDetached(["sh", "-c", "command -v swaymsg >/dev/null && swaymsg exit || command -v hyprctl >/dev/null && hyprctl dispatch exit || loginctl terminate-session self"]);
        } else if (act.id === "reboot") {
            Quickshell.execDetached(["systemctl", "reboot"]);
        } else if (act.id === "shutdown") {
            Quickshell.execDetached(["systemctl", "poweroff"]);
        }
        return true;
    }
}
