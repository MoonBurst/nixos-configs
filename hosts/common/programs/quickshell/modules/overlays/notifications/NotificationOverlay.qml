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
    property bool showHistoryMode: false
    property bool notificationsEnabled: true

    property int overlaysHeightBaseline: 350
    property int cardWidth: shell.theme.defaultCardWidth || 400
    property int cardHeight: shell.theme.defaultCardHeight || 140
    property int defaultCardRadius: shell.theme.defaultCardRadius || 10
    property int globalBorderWidth: shell.theme.globalBorderWidth || 3
    property int globalPadding: shell.theme.globalPadding || 20

    property int overlapOffset: 25

    property int cardBorderWidth: shell.theme.globalBorderWidth || 3
    property int textSummarySize: shell.theme.globalFontSize || 20
    property int textBodySize: shell.theme.globalFontSize || 20
    property int holdDurationMs: 5000

    property color outerBorderColor: shell.theme.base03
    property color innerBorderColor: shell.theme.base05

    property alias rulesLoader: rulesEngine
    property var rootItem: root

    property int historyCount: historyModel ? historyModel.count : 0
    property var historyModel: null

    property var cachedAvatarsMap: ({})

    ListModel {
        id: activeNotificationsModel
    }

    function cacheAvatarImmediately(notification) {
        if (!notification) return;

        let notifId = notification.id;
        let resolvedIcon = rulesLoader ? rulesLoader.getCustomIcon(notification) : "";
        let avatarVal = resolvedIcon ? resolvedIcon : "image://icon/" + (notification.desktopEntry || notification.appName || "").toLowerCase();

        if (avatarVal.toString().includes("image://qsimage")) {
            offscreenAvatarCacher.activeNotifId = notifId;
            offscreenAvatarCacher.source = avatarVal;
        } else {
            root.cachedAvatarsMap[notifId] = avatarVal;
        }
    }

    function recordHistoryDirect(notification) {
        if (!notification) return;

        let appNameLower = (notification.desktopEntry || notification.appName || "").toLowerCase();
        let cached = root.cachedAvatarsMap[notification.id];
        let resolvedIcon = cached ? cached : (rulesLoader ? rulesLoader.getCustomIcon(notification) : "");
        let avatarVal = resolvedIcon ? resolvedIcon : "image://icon/" + appNameLower;

        let previewVal = "";
        let hints = notification.hints || {};
        let hintImagePath = hints["image-path"] || hints["image_path"] || hints["image-uri"] || "";

        if (hintImagePath === "") {
            let attachmentUrls = hints["attachment-urls"] || hints["attachment_urls"] || hints["attachment-url"] || "";
            if (attachmentUrls !== "") {
                let firstUrl = root.extractUrl(String(attachmentUrls));
                if (firstUrl !== "") hintImagePath = firstUrl;
            }
        }

        if (hintImagePath !== "") {
            let strHint = String(hintImagePath);
            if (strHint.startsWith("/") || strHint.startsWith("file://") || strHint.startsWith("http")) {
                previewVal = strHint.startsWith("/") ? "file://" + strHint : strHint;
            }
        }

        if (previewVal === "") {
            let bodyImageUrl = root.extractImageUrl(notification.body || "");
            if (bodyImageUrl !== "") previewVal = bodyImageUrl;
        }

        if (previewVal === "") {
            if (notification.image && notification.image !== notification.icon && notification.image !== resolvedIcon) {
                previewVal = notification.image;
            }
        }

        if (avatarVal.toString().startsWith("image://qsimage")) {
            avatarVal = "image://icon/" + appNameLower;
        }
        if (previewVal.toString().startsWith("image://qsimage")) {
            previewVal = "";
        }

        let historyEntry = {
            "cardRef": null,
            "notifId": notification.id,
            "summary": notification.summary || "",
            "body": notification.body || "",
            "appName": notification.desktopEntry || notification.appName || "",
            "avatarSource": avatarVal,
            "previewSource": previewVal
        };

        if (historyDrawer) {
            try {
                historyDrawer.recordHistory(historyEntry);
            } catch(e) {
                console.warn("Failed to record history: " + e);
            }
        }
    }

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

    Local.NotificationIPC {
        id: notificationIPC
        rootItem: root
        notifModel: activeNotificationsModel
    }

    Local.NotificationRules {
        id: rulesEngine
    }

    Local.NotificationHistory {
        id: historyDrawer
        showHistoryMode: root.showHistoryMode
        rulesLoader: root.rulesLoader
        rootItem: root
        controller: notificationIPC

        Component.onCompleted: {
            root.historyModel = historyDrawer.historyModel;
        }
    }

    NotificationServer {
        id: notificationServer
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        actionsSupported: true
        // Set to false to prevent old cached notifications from re-popping on hot-reload/save
        keepOnReload: false

        onNotification: function(notification) {
            root.cacheAvatarImmediately(notification);
            root.handleNotification(notification);
        }
    }

    PanelWindow {
        id: mainDisplayCanvas

        anchors.top: true
        anchors.right: true
        anchors.bottom: true
        anchors.left: false

        screen: Quickshell.screens.find(s => s.name === "DP-2")
        || Quickshell.screens.find(s => s.name === "DP-1")
        || Quickshell.screens.find(s => s.name.startsWith("eDP"))
        || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        || null

        implicitWidth: root.cardWidth + 100
        color: "transparent"

        mask: Region {
            x: 0
            y: {
                if (activeNotificationsModel.count === 0) return 0;
                return root.overlaysHeightBaseline - (root.overlapOffset * (activeNotificationsModel.count - 1));
            }
            width: activeNotificationsModel.count > 0 ? root.cardWidth : 0
            height: {
                if (activeNotificationsModel.count === 0) return 0;
                let topY = root.overlaysHeightBaseline - (root.overlapOffset * (activeNotificationsModel.count - 1));
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

            Image {
                id: offscreenAvatarCacher
                visible: false
                width: 100
                height: 100

                property int activeNotifId: -1

                onStatusChanged: {
                    if (status === Image.Ready && activeNotifId !== -1) {
                        let notifId = activeNotifId;
                        let localPath = "/tmp/qs_avatar_notif_" + notifId + ".png";

                        grabToImage(function(result) {
                            if (result.saveToFile(localPath)) {
                                let fileUrl = "file://" + localPath;
                                root.cachedAvatarsMap[notifId] = fileUrl;

                                for (let i = 0; i < activeNotificationsModel.count; i++) {
                                    let item = activeNotificationsModel.get(i);
                                    if (item && item.notifId === notifId) {
                                        activeNotificationsModel.setProperty(i, "avatarSource", fileUrl);
                                        if (item.cardRef) {
                                            item.cardRef.cachedAvatarPath = fileUrl;
                                        }
                                        break;
                                    }
                                }

                                if (root.historyModel) {
                                    for (let j = 0; j < root.historyModel.count; j++) {
                                        let hItem = root.historyModel.get(j);
                                        if (hItem && hItem.notifId === notifId) {
                                            root.historyModel.setProperty(j, "avatarSource", fileUrl);
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

    function handleNotification(notification) {
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
            avatarVal = notification.icon;
            previewVal = notification.image;
        } else {
            let cached = root.cachedAvatarsMap[notification.id];
            if (cached) {
                avatarVal = cached;
            } else {
                resolvedIcon = rulesLoader ? rulesLoader.getCustomIcon(notification) : "";
                if (resolvedIcon) {
                    avatarVal = resolvedIcon;
                } else {
                    avatarVal = "image://icon/" + (notification.desktopEntry || notification.appName || "").toLowerCase();
                }
            }

            let hints = notification.hints || {};
            let hintImagePath = hints["image-path"] || hints["image_path"] || hints["image-uri"] || "";

            if (hintImagePath === "") {
                let attachmentUrls = hints["attachment-urls"] || hints["attachment_urls"] || hints["attachment-url"] || "";
                if (attachmentUrls !== "") {
                    let firstUrl = root.extractUrl(String(attachmentUrls));
                    if (firstUrl !== "") hintImagePath = firstUrl;
                }
            }

            if (hintImagePath !== "") {
                let strHint = String(hintImagePath);
                if (strHint.startsWith("/") || strHint.startsWith("file://") || strHint.startsWith("http")) {
                    previewVal = strHint.startsWith("/") ? "file://" + strHint : strHint;
                }
            }

            if (previewVal === "") {
                let bodyImageUrl = root.extractImageUrl(notification.body || "");
                if (bodyImageUrl !== "") previewVal = bodyImageUrl;
            }

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
            let cachedPath = root.cachedAvatarsMap[notification.id] || "";

            let popupCard = cardComponentTemplate.createObject(canvasContent, {
                notification: notification,
                rulesLoader: rulesLoader,
                rootItem: root,
                controller: notificationIPC,
                cachedAvatarPath: cachedPath
            });

            if (popupCard) {
                popupCard.notification = notification;
                popupCard.originalNotification = notification;

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

            notificationIPC.playNotificationSound(notification);
            notificationIPC.speakNotification(notification);
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

            currentY -= root.overlapOffset;
        }
    }

    function closeNotificationTrack(itemInstance) {
        if (!itemInstance) return;
        let index = -1;
        for (let i = 0; i < activeNotificationsModel.count; i++) {
            let entry = activeNotificationsModel.get(i);
            if (entry && entry.cardRef === itemInstance) {
                index = i;
                break;
            }
        }

        if (index === -1) return;

        let expiredEntry = activeNotificationsModel.get(index);
        let appNameLower = (expiredEntry.appName || "").toLowerCase();
        let summaryLower = (expiredEntry.summary || "").toLowerCase();
        let bodyLower = (expiredEntry.body || "").toLowerCase();
        let avatarSourceLower = expiredEntry.avatarSource ? expiredEntry.avatarSource.toString().toLowerCase() : "";

        let isMicNotif = appNameLower.includes("microphone") || appNameLower.includes("mic") ||
        summaryLower.includes("microphone") || summaryLower.includes("mic") ||
        bodyLower.includes("microphone") || bodyLower.includes("mic") ||
        avatarSourceLower.includes("microphone") || avatarSourceLower.includes("mic");

        let isClipboardNotif = appNameLower.includes("greenclip") || appNameLower.includes("copyq") ||
        appNameLower.includes("clipboard") || appNameLower.includes("clip") ||
        summaryLower.includes("copied to clipboard") || bodyLower.includes("copied to clipboard") ||
        summaryLower.includes("clipboard manager");

        let isDeDuplicated = expiredEntry.cardRef && expiredEntry.cardRef.notification && expiredEntry.cardRef.notification.isDeDuplicated ? true : false;

        if (!isMicNotif && !isClipboardNotif && !isDeDuplicated) {
            let serializedAvatar = (expiredEntry.cardRef && expiredEntry.cardRef.cachedAvatarPath !== "")
            ? expiredEntry.cardRef.cachedAvatarPath
            : (expiredEntry.avatarSource || "");

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

            if (serializedAvatar.toString().startsWith("image://qsimage")) {
                serializedAvatar = "image://icon/" + appNameLower;
            }
            if (serializedPreview.toString().startsWith("image://qsimage")) {
                serializedPreview = "";
            }

            let historyEntry = {
                "cardRef": expiredEntry.cardRef,
                "notifId": expiredEntry.notifId,
                "summary": expiredEntry.summary,
                "body": expiredEntry.body,
                "appName": expiredEntry.appName,
                "avatarSource": serializedAvatar,
                "previewSource": serializedPreview
            };

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
