import QtQuick
import Quickshell
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

    // FIXED: Uses Quickshell.shellDir to resolve deprecation warnings in newer runtimes
    property string resourcePath: Quickshell.shellDir + "/resources"

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

    // Determine the border outline color natively using global theme tokens
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

        // 1. Prioritize character profile keyword matching rules!
        // This ensures custom profiles (Apogee, Luster Dawn, etc.) always override generic avatars/icons
        let profile = findActiveProfile(notification);
        if (profile) {
            return "file://" + resourcePath + "/" + profile.name + "/" + profile.name + ".png";
        }

        // 2. Fall back to Quickshell's native ImageSource channels directly (Captures Discord/Vesktop user avatars)
        if (notification.image) {
            return notification.image;
        }
        if (notification.icon) {
            return notification.icon;
        }

        // 3. Fall back to standard system icon theme lookup or manual string filepaths
        if (notification.appIcon && notification.appIcon.length > 0) {
            let iconName = notification.appIcon;
            if (iconName.startsWith("/") || iconName.startsWith("file://")) {
                return iconName.startsWith("file://") ? iconName : "file://" + iconName;
            }
            return "image://icon/" + iconName;
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
