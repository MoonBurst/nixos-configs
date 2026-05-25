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

    property var activeNotifications: []

    // ============================================================================
    // ROUTING & IPC
    // ============================================================================
    Local.NotificationIPC {
        id: notificationIPC
        rootItem: root
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

        /*
         * CLICK THROUGH
         */

        mask: Region {}

        WlrLayershell.keyboardFocus:
        WlrKeyboardFocus.None

        WlrLayershell.exclusiveZone: 0

        WlrLayershell.layer:
        WlrLayer.Overlay

        WlrLayershell.margins.top: 0
        WlrLayershell.margins.right:
        shell.theme.globalPadding || 20
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
        const isShowEvent = notification.summary && notification.summary.length > 0;

        if (!isShowEvent) {
            let existingEntry = activeNotifications.find(entry => entry.notification.id === notification.id);
            if (existingEntry) {
                notificationIPC.dismiss(existingEntry.card);
            }
            return;
        }

        let existingEntry = activeNotifications.find(entry => entry.notification.id === notification.id);

        if (existingEntry) {
            if (existingEntry.card) {
                existingEntry.card.notification = notification;
            }
            existingEntry.notification = notification;
        } else {
            let popupCard = cardComponentTemplate.createObject(canvasContent, {
                notification: notification,
                rulesLoader: rulesLoader,
                rootItem: root,
                controller: notificationIPC
            });

            let entry = {
                card: popupCard,
                notification: notification
            };

            activeNotifications.unshift(entry);
            notificationIPC.playNotificationSound(notification);
            positionNotificationsDeck();
            rulesLoader.handleIncomingNotificationCues(notification);
        }
    }

    function positionNotificationsDeck() {
        let currentY = root.overlaysHeightBaseline;
        const totalCards = activeNotifications.length;

        for (let i = totalCards - 1; i >= 0; i--) {
            let entry = activeNotifications[i];
            if (!entry || !entry.card) continue;

            let item = entry.card;
            item.targetY = currentY;
            item.stackIndex = (totalCards - 1) - i;

            currentY -= 35;
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

    Component {
        id: cardComponentTemplate
        Local.NotificationCard {}
    }
}
