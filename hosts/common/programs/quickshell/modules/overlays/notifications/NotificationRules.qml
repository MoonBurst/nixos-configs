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

    property string resourcePath: "/home/moonburst/nix/hosts/common/programs/quickshell/resources"

    Process {
        id: soundPlaybackEngine
        running: false
    }

    function findActiveProfile(notification) {
        if (!notification || !notification.summary) return null;
        let textToScan = notification.summary.toLowerCase();

        for (let i = 0; i < characterProfiles.length; i++) {
            let prof = characterProfiles[i];
            if (textToScan.indexOf(prof.summary.toLowerCase()) !== -1) {
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

    function getCustomIcon(notification, standardFallback) {
        let profile = findActiveProfile(notification);
        if (profile) {
            return "file://" + resourcePath + "/" + profile.name + "/" + profile.name + ".png";
        }
        return standardFallback;
    }

    function handleIncomingNotificationCues(notification) {
        if (!notification) return;
        let profile = findActiveProfile(notification);

        if (profile && profile.sound) {
            let flacPath = resourcePath + "/" + profile.name + "/" + profile.name + ".flac";
            soundPlaybackEngine.command = ["pw-play", flacPath];
            soundPlaybackEngine.running = false;
            soundPlaybackEngine.running = true;
        }
    }
}
