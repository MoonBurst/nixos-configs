import QtQuick
import QtQuick.Controls 2

QtObject {
    id: rulesEngine

    function getBorderColor(notification, themeObject, defaultColor) {
        if (themeObject && themeObject.base0A !== undefined) return themeObject.base0A;
        if (root && root.theme && root.theme.base0A !== undefined) return root.theme.base0A;
        return defaultColor || "#f1fa8c";
    }

    // FIXED: Multi-layered validation catching integer codes, object maps, and string labels
    function getIsUrgent(notification) {
        if (!notification) return false;

        // 1. Check raw property string or integer
        if (notification.urgency === 2 || notification.urgency === "critical") return true;

        // 2. Fallback check for common dbus hint properties
        if (notification.hints && (notification.hints.urgency === 2 || notification.hints.urgency === "critical")) return true;

        return false;
    }

    // FIXED: Resolves icon source targets out of notifications
    function getCustomIcon(notification, fallbackIcon) {
        if (!notification) return fallbackIcon || "";

        // Return app icon path or raw image paths sent by apps
        if (notification.appIcon && notification.appIcon !== "") return notification.appIcon;
        if (notification.icon && notification.icon !== "") return notification.icon;

        return fallbackIcon || "";
    }

    function handleIncomingNotificationCues(notification) {
        if (!notification) return;
        console.log("Processing custom notification audio rules pipeline for summary: " + notification.summary);
    }
}
