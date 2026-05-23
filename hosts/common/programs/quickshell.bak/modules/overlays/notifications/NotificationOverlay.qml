import QtQuick
import QtQuick.Controls 2

import Quickshell
import Quickshell.Wayland

import "." as Local

PanelWindow {
    id: root

    // ============================================================================
    // DISPLAY TARGET
    // ============================================================================
    screen: Quickshell.screens.find(s => s.name === "DP-2")
    anchors.top: true
    anchors.right: true
    implicitWidth: 700
    implicitHeight: 1200
    color: "transparent"

    margins {
        top: shell.theme.globalPadding
        right: shell.theme.globalPadding
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ============================================================================
    // GLOBAL CONFIGURATION LINK (FIXED: Binds to root shell theme object instance)
    // ============================================================================
    property int cardWidth: shell.theme.defaultCardWidth + 100
    property int cardHeight: 140
    property int cardRadius: shell.theme.defaultCardRadius
    property int cardBorderWidth: shell.theme.globalBorderWidth

    property int stackOffsetY: 26
    property int stackTopMargin: shell.theme.globalPadding

    property real stackScaleFalloff: 0.02
    property real stackOpacityFalloff: 0.00

    property int summaryFontSize: shell.theme.globalHeaderSize
    property int bodyFontSize: shell.theme.globalFontSize

    property int iconSize: 100

    property int entryDuration: 350
    property int settleDuration: 300
    property int exitDuration: 350
    property int hiddenX: 700
    property int shownX: 0

    // ============================================================================
    // STATE ENGINE
    // ============================================================================
    property var notifications: []

    // ============================================================================
    // MASTER LIFECYCLE CONTROLLER LOOP
    // ============================================================================
    Timer {
        id: activeCardCountdown
        interval: 2000
        repeat: false
        onTriggered: {
            root.dismissOldestNormalCard()
        }
    }

    function checkActiveTimerStatus() {
        if (notifications.length === 0) {
            activeCardCountdown.stop()
            return
        }

        let hasNormalCard = false
        for (let i = 0; i < notifications.length; i++) {
            if (!rulesLoader.getIsUrgent(notifications[i].notification)) {
                hasNormalCard = true
                break
            }
        }

        if (!hasNormalCard) {
            activeCardCountdown.stop()
            return
        }

        let frontCard = notifications[0]
        if (frontCard && rulesLoader.getIsUrgent(frontCard.notification)) {
            activeCardCountdown.stop()
        } else {
            if (!activeCardCountdown.running) {
                activeCardCountdown.restart()
            }
        }
    }

    function dismissOldestNormalCard() {
        for (let i = 0; i < notifications.length; i++) {
            let card = notifications[i]
            if (card && !rulesLoader.getIsUrgent(card.notification)) {
                root.closeNotification(card, false)
                break
            }
        }
    }

    function repositionNotifications() {
        for (let i = 0; i < notifications.length; i++) {
            let item = notifications[i]
            if (!item) continue

                item.targetY = stackTopMargin + (i * stackOffsetY)
                item.z = 1000 - i
                item.scale = 1.0 - (i * stackScaleFalloff)
                item.opacityTarget = 1.0 - (i * stackOpacityFalloff)
                item.animateToStackPosition()
        }

        checkActiveTimerStatus()
    }

    // ============================================================================
    // PUBLIC API
    // ============================================================================
    function handleNotification(notification) {
        let popup = notificationComponent.createObject(
            notificationLayer,
            { notification: notification }
        )

        notifications.push(popup)
        repositionNotifications()
        rulesLoader.handleIncomingNotificationCues(notification)
    }

    function closeNotification(itemInstance, isManualDismiss = false) {
        if (!itemInstance) return
            if (isManualDismiss) { itemInstance.dismissedManually = true }

            let index = notifications.indexOf(itemInstance)
            if (index !== -1) {
                notifications.splice(index, 1)
                activeCardCountdown.stop()
            }

            repositionNotifications()
            itemInstance.startExitAnimation()
    }

    Item {
        id: notificationLayer
        anchors.fill: parent
    }

    Local.NotificationRules {
        id: rulesLoader
    }

    Component {
        id: notificationComponent

        Rectangle {
            id: popup
            required property var notification

            property real targetY: 20
            property real opacityTarget: 1.0
            property bool dismissedManually: false

            property bool isCriticalCard: rulesLoader.getIsUrgent(notification)

            property var notificationImageSource: notification.image ? notification.image : null
            property string fallbackIconSource: rulesLoader.getCustomIcon(notification, "image://icon/" + (notification.appIcon || "fallback"))

            property color normalBorderColor: isCriticalCard ? shell.theme.base08 : rulesLoader.getBorderColor(notification, shell.theme, shell.theme.base05)
            property color textColor: shell.theme.getGlobalTextColor(notification)

            width: root.cardWidth
            height: root.cardHeight
            radius: root.cardRadius
            color: shell.theme.base00
            border.width: root.cardBorderWidth
            border.color: dismissedManually ? shell.theme.base08 : normalBorderColor
            clip: true
            opacity: 1
            x: root.hiddenX
            y: targetY + 40
            scale: 1.0

            Behavior on y { NumberAnimation { duration: root.settleDuration; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: root.settleDuration; easing.type: Easing.OutQuad } }

            Local.NotificationAnimation {
                id: animHook
                targetItem: popup
                entryDuration: root.entryDuration
                stackDuration: root.settleDuration
                exitDuration: root.exitDuration
                hiddenX: root.hiddenX
                shownX: root.shownX
            }

            Component.onCompleted: {
                Qt.callLater(function() { animHook.playEntryAnimation(targetY) })
            }

            function startExitAnimation() {
                animHook.playExitAnimation(function() { popup.destroy() })
            }

            function animateToStackPosition() {
                y = targetY
                opacity = opacityTarget
            }

            Row {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                Image {
                    id: appIconDisplay
                    width: root.iconSize
                    height: root.iconSize
                    source: popup.notificationImageSource ? popup.notificationImageSource : popup.fallbackIconSource
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                    visible: popup.notificationImageSource !== null || popup.fallbackIconSource !== ""
                }

                Column {
                    width: parent.width - (appIconDisplay.visible ? (appIconDisplay.width + parent.spacing) : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        text: notification.summary || ""
                        width: parent.width
                        color: popup.isCriticalCard ? shell.theme.base08 : popup.textColor
                        font.bold: true
                        font.pixelSize: root.summaryFontSize
                        font.family: shell.theme.fontFamily
                        wrapMode: Text.Wrap
                    }

                    Text {
                        text: notification.body || ""
                        width: parent.width
                        color: popup.isCriticalCard ? shell.theme.base08 : popup.textColor
                        font.pixelSize: root.bodyFontSize
                        font.family: shell.theme.fontFamily
                        wrapMode: Text.WordWrap
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.closeNotification(popup, true)
                }
            }
        }
    }
}
