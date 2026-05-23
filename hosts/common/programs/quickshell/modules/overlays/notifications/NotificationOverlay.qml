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

    // =========================
    // CONFIG
    // =========================
    property int overlaysHeightBaseline: 150
    property int cardWidth: 400
    property int cardHeight: 200
    property int cardBorderWidth: 3
    property int textSummarySize: 20
    property int textBodySize: 20
    property int holdDurationMs: 2500

    // [0] = newest
    // [last] = oldest
    property var activeNotifications: []

    // =========================
    // IPC / ROUTING
    // =========================
    Local.NotificationIPC {
        id: notificationIPC
        rootItem: root
    }

    // =========================
    // RULES
    // =========================
    Local.NotificationRules {
        id: rulesLoader
    }

    // =========================
    // NOTIFICATION SERVER
    // =========================
    NotificationServer {
        id: notificationServer

        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        actionsSupported: true
        keepOnReload: true
        onNotification: function(notification) {

            console.log(
                "Notification received:",
                notification.summary
            );

            root.handleNotification(notification);
        }
    }

    // =========================
    // STATE
    // =========================
    function handleNotification(notification) {
        // Pass rulesLoader inside the initialization dictionary
        let popupCard = cardComponentTemplate.createObject(root, {
            notification: notification,
            rulesLoader: rulesLoader // <-- FIX: Injected at creation time
        });

        let entry = {
            card: popupCard,
            notification: notification
        };

        activeNotifications.unshift(entry);
        positionNotificationsDeck();
        rulesLoader.handleIncomingNotificationCues(notification);
    }




    function positionNotificationsDeck() {
        let totalCount = activeNotifications.length;
        for (let i = 0; i < totalCount; i++) {
            let entry = activeNotifications[i];

            if (!entry || !entry.card)
                continue;
            let item = entry.card;
            item.targetY =
            root.overlaysHeightBaseline
            + (i * 12);
            item.currentQueueIndex = i;
            item.stackIndex = i;
            item.animateToStackPosition();
        }
    }


    function closeNotificationTrack(itemInstance) {
        if (!itemInstance)
            return;
        let index = -1;
        for (let i = 0; i < activeNotifications.length; i++) {
            let entry = activeNotifications[i];
            if (entry.card === itemInstance) {
                index = i;
                break;
            }
        }

        if (index === -1)
            return;
        activeNotifications.splice(index, 1);
        positionNotificationsDeck();
    }


    // =========================
    // CARD
    // =========================
    Component {
        id: cardComponentTemplate
        Local.NotificationCard {
            rulesLoader: rulesLoader
            rootItem: root
            controller: notificationIPC
        }
    }
}
