import QtQuick
import Quickshell.Io

Item {
    id: rulesEngine

    // Registry map to track and instantly destroy active notifications by app identifier
    property var activeAppCardRegistry: ({})

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

    /*
     * FIXED: Changed the data type handler to return variant properties.
     * Extracts Quickshell's native 'image' or 'icon' ImageSource object values as-is.
     * This passes the active layout memory blocks straight to QML without string decoration crashes.
     */
    function getCustomIcon(notification) {
        if (!notification) return "";

        // FIXED LIFECYCLE MANAGEMENT: Check both fields independently to ensure accurate targets
        let nameString = notification.appName ? notification.appName.toLowerCase() : "";
        let iconString = notification.appIcon ? notification.appIcon.toLowerCase() : "";

        if (nameString.includes("satty") || iconString.includes("satty")) {
            let oldSatty = activeAppCardRegistry["satty"];
            if (oldSatty !== undefined && oldSatty !== null && typeof oldSatty.destroy === "function") {
                oldSatty.destroy();
            }
            activeAppCardRegistry["satty"] = null;
        }

        if (nameString.includes("microphone") || iconString.includes("microphone")) {
            let oldMic = activeAppCardRegistry["microphone"];
            if (oldMic !== undefined && oldMic !== null && typeof oldMic.destroy === "function") {
                oldMic.destroy();
            }
            activeAppCardRegistry["microphone"] = null;
        }

        // 1. Prioritize Quickshell's native ImageSource channels directly (Captures Discord/Vesktop user avatars)
        if (notification.image) {
            return notification.image;
        }
        if (notification.icon) {
            return notification.icon;
        }

        // 2. Fall back to manual string filepath lookups if no object token exists
        if (notification.appIcon && notification.appIcon.length > 0) {
            let iconName = notification.appIcon;
            if (iconName.startsWith("/") || iconName.startsWith("file://")) {
                return iconName.startsWith("file://") ? iconName : "file://" + iconName;
            }

            let lowerApp = iconName.toLowerCase();
            let appNameLower = notification.appName ? notification.appName.toLowerCase() : "";

            if (lowerApp === "vesktop" || lowerApp === "discord" || appNameLower === "vesktop" || appNameLower === "discord") {
                return "file:///home/moonburst/.local/share/icons/Numix/48/apps/discord.png";
            }
            if (lowerApp === "google-chrome" || lowerApp === "chrome" || appNameLower === "google-chrome") {
                return "file:///home/moonburst/.local/share/icons/Numix/48/apps/google-chrome.png";
            }
            if (lowerApp === "steam" || appNameLower === "steam") {
                return "file:///home/moonburst/.local/share/icons/Numix/48/apps/steam.png";
            }
            if (lowerApp === "system-file-manager" || lowerApp === "nautilus" || lowerApp === "thunar") {
                return "file:///home/moonburst/.local/share/icons/Numix/48/apps/system-file-manager.png";
            }
            if (iconName.includes("microphone")) {
                let formattedName = iconName.startsWith("notification-") ? iconName : "notification-" + iconName;
                return "file:///home/moonburst/.local/share/icons/Numix/48/notifications/" + formattedName + ".svg";
            }

            return "file:///home/moonburst/.local/share/icons/Numix/48/apps/" + iconName + ".png";
        }

        // 3. Fall back to character profile keyword matching rules
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
