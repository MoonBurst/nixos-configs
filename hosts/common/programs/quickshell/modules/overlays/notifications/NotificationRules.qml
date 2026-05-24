import QtQuick
import Quickshell.Io

Item {
    id: rulesEngine

    property var characterProfiles: [
        { name: "apogee",        summary: "Apogee",        color: "#0CD0CD", sound: false },
        { name: "solar_sonata",  summary: "Solar Sonata",  color: "#f7f716", sound: true  },
        { name: "cageheart",     summary: "Cageheart",     color: "#8ad5a6", sound: true  },
        { name: "olivia",        summary: "Olivia",        color: "#18FFD5", sound: true  },
        { name: "genesis_frost", summary: "Genesis Frost", color: "#9ce8ff", sound: false },
        { name: "luster_dawn",   summary: "Luster Dawn",   color: "#e041de", sound: true  }
    ]

    property string resourcePath: (typeof shellWindow !== "undefined" ? shellWindow.projectRootPath : "/home/moonburst/nix/hosts/common/programs/quickshell") + "/resources"

    Process {
        id: soundPlaybackEngine
        running: false
    }

    function findActiveProfile(notification) {
        if (!notification) return null;

        let summaryText = (notification.summary || "").toLowerCase();
        let bodyText = (notification.body || "").toLowerCase();

        for (let i = 0; i < characterProfiles.length; i++) {
            let prof = characterProfiles[i];
            let targetKeyword = prof.summary.toLowerCase();

            if (summaryText.includes(targetKeyword) || bodyText.includes(targetKeyword)) {
                return prof;
            }
        }
        return null;
    }

    function getIsUrgent(notification) {
        if (!notification) return false;
        let urgency = notification.urgency;
        if (notification.hints && notification.hints["urgency"] !== undefined) {
            urgency = parseInt(notification.hints["urgency"], 10);
        }
        return urgency === 2;
    }

    function getBorderColor(notification, themeObject, defaultBlue) {
        if (getIsUrgent(notification)) return shell.theme.base08;
        let profile = findActiveProfile(notification);
        return profile ? profile.color : shell.theme.base0D;
    }

    function getCustomIcon(notification) {
        if (!notification) return "";

        if (notification.appIcon && notification.appIcon.length > 0) {
            let iconName = notification.appIcon;
            if (iconName.startsWith("/") || iconName.startsWith("file://")) {
                return iconName.startsWith("file://") ? iconName : "file://" + iconName;
            }

            let lowerApp = iconName.toLowerCase();
            if (lowerApp === "vesktop" || lowerApp === "discord") iconName = "discord";
            if (lowerApp === "google-chrome" || lowerApp === "chrome") iconName = "google-chrome";
            if (lowerApp === "steam") return "image://icon/steam";

                return "image://icon/" + iconName;
        }

        let profile = findActiveProfile(notification);
        if (profile) {
            return "file://" + resourcePath + "/" + profile.name + "/" + profile.name + ".png";
        }

        return "";
    }

    function handleIncomingNotificationCues(notification) {
        if (!notification) return;
        let profile = findActiveProfile(notification);

        if (profile && profile.sound) {
            let flacPath = resourcePath + "/" + profile.name + "/" + profile.name + ".flac";

            soundPlaybackEngine.running = false;
            soundPlaybackEngine.command = ["pw-play", flacPath];
            soundPlaybackEngine.running = true;
        }
    }
}
