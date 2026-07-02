// modules/overlays/notifications/NotificationOverlay.qml
import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io

import "." as Local

Item {
    id: root
    anchors.fill: parent

    // Sync properties bound by shell.qml
    property bool showHistoryMode: false
    property bool notificationsEnabled: true

    // ============================================================================
    // CONFIGURATION CONSTANTS (STYLIX BRIDGED)
    // ============================================================================
    property int overlaysHeightBaseline: 350
    property int cardWidth: shell.theme.defaultCardWidth || 400
    property int cardHeight: shell.theme.defaultCardHeight || 140
    property int defaultCardRadius: shell.theme.defaultCardRadius || 10
    property int globalBorderWidth: shell.theme.globalBorderWidth || 3
    property int globalPadding: shell.theme.globalPadding || 20

    // Properties expected by NotificationCard.qml
    property int cardBorderWidth: shell.theme.globalBorderWidth || 3
    property int textSummarySize: shell.theme.globalFontSize || 20
    property int textBodySize: shell.theme.globalFontSize || 20
    property int holdDurationMs: 5000

    // CUSTOM BORDER COLOR SLOTS MAP TO LAUNCHER PANELS
    property color outerBorderColor:  shell.theme.base03
    property color innerBorderColor:  shell.theme.base05

    // Expose the rules engine as a standard alias to guarantee it resolves
    property alias rulesLoader: rulesEngine
    property var rootItem: null

    // Exposes the history model count to the master scope
    property int historyCount: historyModel ? historyModel.count : 0

    // Dynamically bound at runtime to prevent compile-time alias target resolution failures
    property var historyModel: null

    // Global cache to map active notification IDs to local, persistent cache files
    property var cachedAvatarsMap: ({})
    property int cacheCounter: 0

    ListModel {
        id: activeNotificationsModel
    }

    // Immediately caches temporary D-Bus provider images upon DBus server entry to prevent expirations
    function cacheAvatarImmediately(notification) {
        if (!notification) return;

        let appNameLower = (notification.desktopEntry || notification.appName || "").toLowerCase();
        let resolvedIcon = rulesLoader ? rulesLoader.getCustomIcon(notification) : "";
        let avatarVal = resolvedIcon ? resolvedIcon : "image://icon/" + appNameLower;

        if (avatarVal.includes("image://qsimage")) {
            offscreenAvatarCacher.activeNotifId = notification.id;
            offscreenAvatarCacher.source = avatarVal;
        }
    }

    // Direct History Commit: Formats and records incoming notifications directly to history while DND is active
    function recordHistoryDirect(notification) {
        if (!notification) return;

        let appNameLower = (notification.desktopEntry || notification.appName || "").toLowerCase();
        let summaryLower = (notification.summary || "").toLowerCase();
        let bodyLower = (notification.body || "").toLowerCase();

        // Check if we have already compiled a persistent local copy of this temporary avatar
        let cached = root.cachedAvatarsMap[notification.id];
        let resolvedIcon = cached ? cached : (rulesLoader ? rulesLoader.getCustomIcon(notification) : "");
        let avatarVal = resolvedIcon ? resolvedIcon : "image://icon/" + appNameLower;

        // Compare underlying string locations to prevent avatar payloads from being treated as shared preview attachments
        let resolvedStr = resolvedIcon ? String(resolvedIcon) : "";
        let imageStr = notification.image ? String(notification.image) : "";

        // Parse shared image/GIF link from metadata hints (only used for local direct uploads)
        let previewVal = "";
        let hints = notification.hints || {};
        let hintImagePath = hints["image-path"] || hints["image_path"] || hints["image-uri"] || hints["image-uri"] || "";

        if (hintImagePath === "") {
            let attachmentUrls = hints["attachment-urls"] || hints["attachment_urls"] || hints["attachment-url"] || hints["attachment-url"] || "";
            if (attachmentUrls !== "") {
                let strUrls = String(attachmentUrls);
                let firstUrl = root.extractUrl(strUrls);
                if (firstUrl !== "") {
                    hintImagePath = firstUrl;
                }
            }
        }

        if (hintImagePath !== "") {
            let strHint = String(hintImagePath);
            if (strHint.startsWith("/") || strHint.startsWith("file://") || strHint.startsWith("http")) {
                previewVal = strHint.startsWith("/") ? "file://" + strHint : strHint;
            }
        }

        // Fallback 1: Extract direct image URLs from body text directly (for direct PNG/JPG links)
        if (previewVal === "") {
            let bodyImageUrl = root.extractImageUrl(notification.body || "");
            if (bodyImageUrl !== "") {
                previewVal = bodyImageUrl;
            }
        }

        // Fallback 2: Raw uploaded image payload (only if distinct from the user avatar)
        if (previewVal === "") {
            if (notification.image && notification.image !== notification.icon && notification.image !== resolvedIcon) {
                previewVal = notification.image;
            }
        }

        // PREVENT DEAD HANDLES: Fallback to the stable app icon if the cached avatar fails before direct DND save
        if (avatarVal.toString().startsWith("image://qsimage")) {
            avatarVal = "image://icon/" + appNameLower;
        }
        if (previewVal.toString().startsWith("image://qsimage")) {
            previewVal = "";
        }

        let historyEntry = {
            "cardRef": null, // Safely pass null since no visual card was instantiated
            "notifId": notification.id,
            "summary": notification.summary || "",
            "body": notification.body || "",
            "appName": notification.desktopEntry || notification.appName || "",
            "avatarSource": avatarVal,
            "previewSource": previewVal
        };

        // Record history safely without blocking popup dismissals
        if (historyDrawer) {
            try {
                historyDrawer.recordHistory(historyEntry);
            } catch(e) {
                console.warn("Failed to record history: " + e);
            }
        }
    }

    // ============================================================================
    // DEDUPLICATED UTILITIES (Compiled once at startup instead of per-delegate)
    // ============================================================================
    readonly property var urlRegex: /(https?:\/\/[^\s<]+)/

    function extractUrl(text) {
        if (!text) return "";
        var match = text.match(urlRegex);
        return match ? match[0] : "";
    }

    function extractImageUrl(text) {
        if (!text) return "";
        var match = text.match(/(https?:\/\/[^\s<]+\.(?:png|jpg|jpeg|gif|svg|webp)(?:\?[^\s<]+)?)/i);
        return match ? match[0] : "";
    }

    // ============================================================================
    // ROUTING & IPC
    // ============================================================================
    Local.NotificationIPC {
        id: notificationIPC
        rootItem: root
        notifModel: activeNotificationsModel
    }

    Local.NotificationRules {
        id: rulesEngine
    }

    // Instantiate the history drawer cleanly as a decoupled sibling
    Local.NotificationHistory {
        id: historyDrawer
        showHistoryMode: root.showHistoryMode
        rulesLoader: root.rulesLoader
        rootItem: root // Passes parent reference to allow warning-free property modifications

        // Pass the controller
        controller: notificationIPC

        Component.onCompleted: {
            root.historyModel = historyDrawer.historyModel; // Dynamically binds the model on completed safely
        }
    }

    NotificationServer {
        id: notificationServer
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        actionsSupported: true
        keepOnReload: true

        onNotification: function(notification) {
            // Instantly cache temporary D-Bus provider images while they are active and valid
            root.cacheAvatarImmediately(notification);
            root.handleNotification(notification);
        }
    }

    /*
     * SINGLE LAYER-SHELL WINDOW CANVAS CONTAINER (Checks for DP-2, desktop primary DP-1, laptop eDP, or defaults to first connected)
     */
    PanelWindow {
        id: mainDisplayCanvas

        anchors.top: true
        anchors.right: true
        anchors.bottom: true
        anchors.left: false

        // Startup-safe dynamic monitor assignment (Falls back to 'null' instead of 'undefined' during initialization)
        screen: Quickshell.screens.find(s => s.name === "DP-2")
        || Quickshell.screens.find(s => s.name === "DP-1")
        || Quickshell.screens.find(s => s.name.startsWith("eDP"))
        || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        || null

        implicitWidth: root.cardWidth + 100
        color: "transparent"

        // Dynamic input mask calculation using Region type
        mask: Region {
            x: 0
            y: {
                if (activeNotificationsModel.count === 0) return 0;
                // Maps y boundary perfectly to the top (newest) item index
                return root.overlaysHeightBaseline - (root.cardHeight + 10) * (activeNotificationsModel.count - 1);
            }
            width: activeNotificationsModel.count > 0 ? root.cardWidth : 0
            height: {
                if (activeNotificationsModel.count === 0) return 0;
                let topY = root.overlaysHeightBaseline - (root.cardHeight + 10) * (activeNotificationsModel.count - 1);
                let bottomY = root.overlaysHeightBaseline + root.cardHeight;
                return bottomY - topY;
            }
        }

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay

        WlrLayershell.margins.top: 0
        WlrLayershell.margins.right: shell.theme.globalPadding || 20
        WlrLayershell.margins.bottom: 0

        Item {
            id: canvasContent
            anchors.fill: parent

            // Placed inside canvasContent (inside PanelWindow) to satisfy grabToImage's scene graph requirements
            Image {
                id: offscreenAvatarCacher
                visible: false
                width: 100
                height: 100

                property int activeNotifId: -1

                onStatusChanged: {
                    if (status === Image.Ready && activeNotifId !== -1) {
                        let notifId = activeNotifId;
                        grabToImage(function(result) {
                            var localPath = "/tmp/qs_avatar_" + notifId + "_" + root.cacheCounter++ + ".png";
                            if (result.saveToFile(localPath)) {
                                root.cachedAvatarsMap[notifId] = "file://" + localPath;

                                // Push the new cache URL immediately to the active list view model
                                for (let i = 0; i < activeNotificationsModel.count; i++) {
                                    let item = activeNotificationsModel.get(i);
                                    if (item && item.notifId === notifId) {
                                        activeNotificationsModel.setProperty(i, "avatarSource", "file://" + localPath);
                                        if (item.cardRef) {
                                            item.cardRef.cachedAvatarPath = "file://" + localPath;
                                        }
                                        break;
                                    }
                                }

                                // Push the new cache URL immediately to the history list view model
                                if (root.historyModel) {
                                    for (let j = 0; j < root.historyModel.count; j++) {
                                        let hItem = root.historyModel.get(j);
                                        if (hItem && hItem.notifId === notifId) {
                                            root.historyModel.setProperty(j, "avatarSource", "file://" + localPath);
                                            break;
                                        }
                                    }
                                }
                            }
                        });
                        activeNotifId = -1;
                    }
                }
            }
        }
    }

    // ============================================================================
    // STATE SELECTION ENGINE
    // ============================================================================
    function handleNotification(notification) {
        // MASTER DND FILTER: Block active screen popups completely if DND is active
        if (!root.notificationsEnabled) {
            return;
        }

        if (notification) {
            notification.tracked = true;
        }

        const isShowEvent = notification.summary && notification.summary.length > 0;

        if (!isShowEvent) {
            for (let idx = 0; idx < activeNotificationsModel.count; idx++) {
                let itemEntry = activeNotificationsModel.get(idx);
                if (itemEntry && itemEntry.notifId === notification.id) {
                    notificationIPC.dismiss(itemEntry.cardRef);
                    break;
                }
            }
            return;
        }

        let existingIndex = -1;
        for (let idx = 0; idx < activeNotificationsModel.count; idx++) {
            let itemEntry = activeNotificationsModel.get(idx);
            if (itemEntry && itemEntry.notifId === notification.id) {
                existingIndex = idx;
                break;
            }
        }

        let resolvedIcon = "";
        let previewVal = "";
        let avatarVal = "";

        if (notification.isMock) {
            // Read pre-resolved filepaths directly from your background-buffered mock object
            avatarVal = notification.icon;
            previewVal = notification.image;
        } else {
            // Check our pre-resolved local file cache map first to bypass expired DBus handles
            let cached = root.cachedAvatarsMap[notification.id];
            if (cached) {
                avatarVal = cached;
            } else {
                resolvedIcon = rulesLoader ? rulesLoader.getCustomIcon(notification) : "";
                if (resolvedIcon) {
                    avatarVal = resolvedIcon; // User's avatar object or string
                } else {
                    avatarVal = "image://icon/" + (notification.desktopEntry || notification.appName || "").toLowerCase();
                }
            }

            // Compare underlying string locations to prevent avatar payloads from being treated as shared preview attachments
            let resolvedStr = resolvedIcon ? String(resolvedIcon) : "";
            let imageStr = notification.image ? String(notification.image) : "";

            // Parse shared image/GIF link from metadata hints (only used for local direct uploads)
            let hints = notification.hints || {};
            let hintImagePath = hints["image-path"] || hints["image_path"] || hints["image-uri"] || hints["image-uri"] || "";

            if (hintImagePath === "") {
                let attachmentUrls = hints["attachment-urls"] || hints["attachment_urls"] || hints["attachment-url"] || hints["attachment-url"] || "";
                if (attachmentUrls !== "") {
                    let strUrls = String(attachmentUrls);
                    let firstUrl = root.extractUrl(strUrls);
                    if (firstUrl !== "") {
                        hintImagePath = firstUrl;
                    }
                }
            }

            if (hintImagePath !== "") {
                let strHint = String(hintImagePath);
                if (strHint.startsWith("/") || strHint.startsWith("file://") || strHint.startsWith("http")) {
                    previewVal = strHint.startsWith("/") ? "file://" + strHint : strHint;
                }
            }

            // Fallback 1: Extract direct image URLs from body text directly (for direct PNG/JPG links)
            if (previewVal === "") {
                let bodyImageUrl = root.extractImageUrl(notification.body || "");
                if (bodyImageUrl !== "") {
                    previewVal = bodyImageUrl;
                }
            }

            // Fallback 2: Raw uploaded image payload (only if distinct from the user avatar)
            if (previewVal === "") {
                if (notification.image && notification.image !== notification.icon && notification.image !== resolvedIcon) {
                    previewVal = notification.image;
                }
            }
        }

        if (existingIndex !== -1) {
            let existingEntry = activeNotificationsModel.get(existingIndex);
            if (existingEntry && existingEntry.cardRef) {
                existingEntry.cardRef.notification = notification;
                existingEntry.cardRef.originalNotification = notification;
                existingEntry.avatarSource = avatarVal;
                existingEntry.previewSource = previewVal;
            }
        } else {
            // Instantiates popupCard inside the designated canvasContent directly
            let popupCard = cardComponentTemplate.createObject(canvasContent, {
                notification: notification,
                rulesLoader: rulesLoader,
                rootItem: root,
                controller: notificationIPC,
                // Pass the cached avatar path directly if already available
                cachedAvatarPath: root.cachedAvatarsMap[notification.id] || ""
            });

            if (popupCard) {
                popupCard.notification = notification;
                popupCard.originalNotification = notification;

                // Populates the ruleEngine registry with the dynamic object reference for auto-destruction
                let appName = (notification.desktopEntry || notification.appName || "").toLowerCase();
                if (appName.includes("satty") && rulesLoader) {
                    rulesLoader.activeAppCardRegistry["satty"] = popupCard;
                } else if ((appName.includes("microphone") || appName.includes("mic")) && rulesLoader) {
                    rulesLoader.activeAppCardRegistry["microphone"] = popupCard;
                }
            }

            activeNotificationsModel.insert(0, {
                "cardRef": popupCard,
                "notifId": notification.id,
                "summary": notification.summary || "",
                "body": notification.body || "",
                "appName": notification.desktopEntry || notification.appName || "",
                "avatarSource": avatarVal,
                "previewSource": previewVal
            });

            // Trigger sound effects and callbacks
            notificationIPC.playNotificationSound(notification);
            positionNotificationsDeck();
            rulesLoader.handleIncomingNotificationCues(notification);
        }
    }

    function positionNotificationsDeck() {
        let currentY = root.overlaysHeightBaseline;
        const totalCards = activeNotificationsModel.count;

        for (let i = totalCards - 1; i >= 0; i--) {
            let entry = activeNotificationsModel.get(i);
            if (!entry || !entry.cardRef) continue;

            let item = entry.cardRef;
            item.targetY = currentY;
            item.stackIndex = (totalCards - 1) - i;

            // Shift the stack using card height offset instead of static 35px to stop overlapping block issues
            currentY -= (root.cardHeight + 10);
        }
    }

    function closeNotificationTrack(itemInstance) {
        if (!itemInstance)
            return;
        let index = -1;
        for (let i = 0; i < activeNotificationsModel.count; i++) {
            let entry = activeNotificationsModel.get(i);
            if (entry && entry.cardRef === itemInstance) {
                index = i;
                break;
            }
        }

        if (index === -1)
            return;

        let expiredEntry = activeNotificationsModel.get(index);

        // Check if this is a microphone toggle notification
        let appNameLower = (expiredEntry.appName || "").toLowerCase();
        let summaryLower = (expiredEntry.summary || "").toLowerCase();
        let bodyLower = (expiredEntry.body || "").toLowerCase();

        let avatarSourceLower = expiredEntry.avatarSource ? expiredEntry.avatarSource.toString().toLowerCase() : "";

        let isMicNotif = appNameLower.includes("microphone") || appNameLower.includes("mic") ||
        summaryLower.includes("microphone") || summaryLower.includes("mic") ||
        bodyLower.includes("microphone") || bodyLower.includes("mic") ||
        avatarSourceLower.includes("microphone") || avatarSourceLower.includes("mic");

        // Clipboard managers filter (prevents Greenclip/CopyQ spam from entering history)
        let isClipboardNotif = appNameLower.includes("greenclip") || appNameLower.includes("copyq") ||
        appNameLower.includes("clipboard") || appNameLower.includes("clip") ||
        summaryLower.includes("copied to clipboard") || bodyLower.includes("copied to clipboard") ||
        summaryLower.includes("clipboard manager");

        // De-duplication check: Detects if this was already recorded by the backlog direct commit
        let isDeDuplicated = expiredEntry.cardRef && expiredEntry.cardRef.notification && expiredEntry.cardRef.notification.isDeDuplicated ? true : false;

        // Only insert into history if it is NOT a microphone toggle alert, NOT a clipboard sync notification, and NOT a duplicate
        if (!isMicNotif && !isClipboardNotif && !isDeDuplicated) {
            // Prioritize the locally cached persistent avatar picture saved during the active popup phase
            let serializedAvatar = (expiredEntry.cardRef && expiredEntry.cardRef.cachedAvatarPath !== "")
            ? expiredEntry.cardRef.cachedAvatarPath
            : (expiredEntry.avatarSource || "");

            // ============================================================================
            // AVATAR INHERIT ENGINE
            // If this notification is missing an icon, search history for the most recent
            // message from the exact same sender and inherit their avatar!
            // ============================================================================
            if (serializedAvatar === "" && expiredEntry.summary !== "") {
                if (root.historyModel) {
                    for (let i = 0; i < root.historyModel.count; i++) {
                        let past = root.historyModel.get(i);
                        if (past && past.summary === expiredEntry.summary && past.avatarSource && past.avatarSource !== "") {
                            serializedAvatar = past.avatarSource;
                            break;
                        }
                    }
                }
            }

            let serializedPreview = expiredEntry.previewSource || "";

            // PREVENT DEAD HANDLES: Fallback to stable app icon or blank if the handles have been invalidated on close
            if (serializedAvatar.toString().startsWith("image://qsimage")) {
                serializedAvatar = "image://icon/" + appNameLower;
            }
            if (serializedPreview.toString().startsWith("image://qsimage")) {
                serializedPreview = "";
            }

            // Repackage entry with local persistent filepath
            let historyEntry = {
                "cardRef": expiredEntry.cardRef,
                "notifId": expiredEntry.notifId,
                "summary": expiredEntry.summary,
                "body": expiredEntry.body,
                "appName": expiredEntry.appName,
                "avatarSource": serializedAvatar,
                "previewSource": serializedPreview
            };

            // Record history safely without blocking popup dismissals
            if (historyDrawer) {
                try {
                    historyDrawer.recordHistory(historyEntry);
                } catch(e) {
                    console.warn("Failed to record history: " + e);
                }
            }
        }

        activeNotificationsModel.remove(index);
        positionNotificationsDeck();
    }

    Component {
        id: cardComponentTemplate
        Local.NotificationCard {}
    }
}
