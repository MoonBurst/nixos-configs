import QtQuick
import Quickshell.Io
import Theme

Item {
    id: rulesEngine

    // ============================================================================
    // ⚙️ CHARACTER PROFILE METRICS CONFIGURATION MATRIX
    // ============================================================================
    property var characterProfiles: [
        { name: "apogee",        summary: "Apogee",        color: "#0CD0CD", sound: false },
        { name: "solar_sonata",  summary: "Solar Sonata",  color: "#f7f716", sound: true  },
        { name: "cageheart",     summary: "Cageheart",     color: "#8ad5a6", sound: true  },
        { name: "olivia",        summary: "Olivia",        color: "#18FFD5", sound: true  },
        { name: "genesis_frost", summary: "Genesis Frost", color: "#9ce8ff", sound: false },
        { name: "luster_dawn",   summary: "Luster Dawn",   color: "#e041de", sound: true  }
    ]

    // Local base directory mapping target string matching your resources tree structure
    property string resourcePath: "/home/moonburst/nix/hosts/common/programs/quickshell/resources"

    // Underlying engine runner task block to handle fluid, asynchronous flac media playback
    Process {
        id: soundPlaybackEngine
        running: false
    }

    // ============================================================================
    // 🧠 INTERNAL PARSING UTILITIES (DO NOT TOUCH)
    // ============================================================================

    // Internal helper to scan strings and extract profile information matching the character data arrays
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

    // TAG: Evaluates title summaries to return the exact stylized hex color accent rule
    function getBorderColor(notification, themeObject, defaultBlue) {
        // 1. Critical/Urgent priority alerts take absolute priority and turn red instantly
        if (getIsUrgent(notification)) {
            return (typeof Theme !== 'undefined' && Theme.base08 !== undefined) ? Theme.base08 : "red";
        }

        // 2. Scan if a character summary profile match is actively parsed from text
        let profile = findActiveProfile(notification);
        if (profile) {
            return profile.color;
        }

        // 3. Standard fallback rules point right to your default blue configuration accents
        return (typeof Theme !== 'undefined' && Theme.base0D !== undefined) ? Theme.base0D : defaultBlue;
    }

    // TAG: Processes summary matching criteria to intercept path icons and serve portrait graphics
    function getCustomIcon(notification, standardFallback) {
        let profile = findActiveProfile(notification);
        if (profile) {
            // Re-routes target file URLs directly to your local assets resources folder path
            return "file://" + resourcePath + "/" + profile.name + "/" + profile.name + ".png";
        }
        return standardFallback;
    }

    // TAG: Scans new entries on arrival and fires audio cues if character audio profiles permit it
    function handleIncomingNotificationCues(notification) {
        if (!notification) return;
        let profile = findActiveProfile(notification);

        // Execute background player streams instantly if a character profile has sound enabled
        if (profile && profile.sound) {
            let flacPath = resourcePath + "/" + profile.name + "/" + profile.name + ".flac";
            soundPlaybackEngine.command = ["pw-play", flacPath];
            soundPlaybackEngine.running = false;
            soundPlaybackEngine.running = true;
        }
    }
}
