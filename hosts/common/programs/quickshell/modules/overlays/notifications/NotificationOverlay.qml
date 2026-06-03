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

    // ============================================================================
    // CONFIGURATION CONSTANTS (STYLIX BRIDGED)
    // ============================================================================
    property int overlaysHeightBaseline: 350
    property int cardWidth: shell.theme.defaultCardWidth || 400
    property int cardHeight: shell.theme.defaultCardHeight || 140
    property int cardBorderWidth: shell.theme.globalBorderWidth || 3
    property int textSummarySize: shell.theme.globalFontSize || 20
    property int textBodySize: shell.theme.globalFontSize || 20
    property int holdDurationMs: 5000

    ListModel {
        id: activeNotificationsModel
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
        id: rulesLoader
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
            root.handleNotification(notification);
        }
    }

    /*
     * SINGLE LAYER-SHELL WINDOW CANVAS CONTAINER
     */
    PanelWindow {
        id: mainDisplayCanvas

        anchors.top: true
        anchors.right: true
        anchors.bottom: true
        anchors.left: false

        screen: Quickshell.screens.find(
            s => s.name === "DP-2"
        )

        implicitWidth: root.cardWidth + 100
        color: "transparent"
        mask: Region {}

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay

        WlrLayershell.margins.top: 0
        WlrLayershell.margins.right: shell.theme.globalPadding || 20
        WlrLayershell.margins.bottom: 0

        Item {
            id: canvasContent
            anchors.fill: parent
        }
    }

    // ============================================================================
    // STATE SELECTION ENGINE
    // ============================================================================
    function handleNotification(notification) {
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

        if (existingIndex !== -1) {
            let existingEntry = activeNotificationsModel.get(existingIndex);
            if (existingEntry && existingEntry.cardRef) {
                existingEntry.cardRef.notification = notification;
                // Update persistent structural handle links
                existingEntry.cardRef.originalNotification = notification;
            }
        } else {
            let popupCard = cardComponentTemplate.createObject(canvasContent, {
                notification: notification,
                rulesLoader: rulesLoader,
                rootItem: root,
                controller: notificationIPC
            });

            // CRITICAL ARCHITECTURAL CONTEXT LOCK:
            // Injects the raw notification handle directly as an instance variable onto the visual card node.
            // This forces Quickshell's internal QML layout garbage collector to anchor the live C++ properties.
            if (popupCard) {
                popupCard.notification = notification;
                popupCard.originalNotification = notification;
            }

            activeNotificationsModel.insert(0, {
                "cardRef": popupCard,
                "notifId": notification.id,
                "summary": notification.summary || "",
                "body": notification.body || "",
                "appName": notification.desktopEntry || notification.appName || ""
            });

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

            currentY -= 35;
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

        activeNotificationsModel.remove(index);
        positionNotificationsDeck();
    }

    Component {
        id: cardComponentTemplate
        Local.NotificationCard {}
    }
}
