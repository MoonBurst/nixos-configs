import QtQuick
import QtQuick.Controls 2
import Quickshell.Services.Notifications
import Theme
import "." as Local

Item {
    id: root
    anchors.fill: parent

    // ============================================================================
    // ⚙️ CUSTOMIZABLE CONFIGURATION ZONE (EDIT THESE VALUES)
    // ============================================================================
    property int overlaysHeightBaseline: 600
    property int cardWidth: 400
    property int cardHeight: 150
    property int cardBorderWidth: 3
    property int textSummarySize: 20
    property int textBodySize: 20

    // ============================================================================
    // 🧠 CORE ENGINE LAYERS (DO NOT TOUCH)
    // ============================================================================
    property var theme: null
    property var notifications: []

    // ROBUST RESOLUTION FIX: Declaring the rules loader at the global scope level
    // lets all root functions and internal component sandboxes read its values!
    Local.NotificationRules {
        id: rulesLoader
    }

    function handleNotification(notification) {
        console.log("handleNotification called:", notification && notification.summary, notification && notification.body);

        let existing = root.notifications.find(n => n.notification && n.notification.id === notification.id);
        if (existing) {
            existing.update(notification);
        } else {
            let newNotification = notificationComponent.createObject(root, {
                notification: notification
            });
            root.notifications.push(newNotification);
            positionNotifications();

            // Runs the sound checking rules pipeline safely on data arrival
            rulesLoader.handleIncomingNotificationCues(notification);
        }
    }

    function positionNotifications() {
        for (var i = 0; i < root.notifications.length; i++) {
            let item = root.notifications[i];
            if (item.stackAnimator) {
                item.stackAnimator.index = i;
                item.stackAnimator.totalCount = root.notifications.length;
                item.z = root.notifications.length - i;
            }
        }
    }

    function closeNotification(itemInstance, isManualClick) {
        if (!itemInstance) return;
        let index = root.notifications.indexOf(itemInstance);
        if (index !== -1) {
            itemInstance.isManualDismiss = isManualClick;
            root.notifications[index].startExitAnimation();
            root.notifications.splice(index, 1);
            positionNotifications();
        }
    }

    Component {
        id: notificationComponent
        Rectangle {
            id: notificationItem
            property var notification
            property alias stackAnimator: animHook
            property bool isManualDismiss: false

            width: root.cardWidth
            height: root.cardHeight
            radius: 10
            opacity: 0
            x: root.width + 50

            color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
            border.width: root.cardBorderWidth

            // Evaluates colors via the top-level rules engine path hook
            border.color: isManualDismiss
            ? ((typeof Theme !== 'undefined' && Theme.base08 !== undefined) ? Theme.base08 : "red")
            : rulesLoader.getBorderColor(notification, Theme, "#0000ff")

            Local.NotificationAnimation {
                id: animHook
                targetItem: notificationItem
                index: root.notifications.length - 1
                totalCount: root.notifications.length
                isUrgentCard: rulesLoader.getIsUrgent(notificationItem.notification)

                onTimeoutTriggered: function(itemRef) {
                    root.closeNotification(itemRef, false);
                }
            }

            Component.onCompleted: {
                notificationItem.y = root.overlaysHeightBaseline;
            }

            function startExitAnimation() {
                animHook.stopTimer();
                exitAnimation.start();
            }

            ParallelAnimation {
                id: exitAnimation
                NumberAnimation { target: notificationItem; property: "x"; to: root.width + 50; duration: 220; easing.type: Easing.InQuad }
                NumberAnimation { target: notificationItem; property: "opacity"; to: 0; duration: 150 }
                onFinished: notificationItem.destroy()
            }

            function hasIcon(n) {
                if (!n) return false;
                if (n.image || (n.icon && n.icon.trim() !== "")) return true;
                if (n.hints && (n.hints["image-path"] || n.hints["image_path"])) return true;
                return false;
            }

            function getIconSource(n) {
                if (!n) return "";
                if (n.image) return n.image;

                let characterPortrait = rulesLoader.getCustomIcon(n, "");
                if (characterPortrait !== "") return characterPortrait;

                if (n.hints && n.hints["image-path"]) return n.hints["image-path"].startsWith("/") ? "file://" + n.hints["image-path"] : n.hints["image-path"];
                    if (n.hints && n.hints["image_path"]) return n.hints["image_path"].startsWith("/") ? "file://" + n.hints["image_path"] : n.hints["image_path"];
                        if (n.icon && n.icon.trim() !== "") {
                            return (n.icon.startsWith("/") || n.icon.startsWith("file://")) ? (n.icon.startsWith("/") ? "file://" + n.icon : n.icon) : "image://icon/" + n.icon;
                        }
                        return "image://icon/dialog-information";
            }

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                Image {
                    id: notificationIcon
                    width: 100
                    height: 100
                    anchors.verticalCenter: parent.verticalCenter
                    fillMode: Image.PreserveAspectFit
                    source: notificationItem.getIconSource(notification)
                    visible: notificationItem.hasIcon(notification)
                }

                Column {
                    width: notificationIcon.visible ? parent.width - 112 : parent.width
                    height: parent.height
                    spacing: 4

                    Text {
                        id: summary
                        width: parent.width
                        text: notification.summary
                        color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "white"
                        font.bold: true
                        font.pixelSize: root.textSummarySize
                        elide: Text.ElideRight
                    }

                    Text {
                        id: body
                        width: parent.width
                        height: parent.height - summary.height - 4
                        text: notification.body
                        color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "white"
                        font.pixelSize: root.textBodySize
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeNotification(notificationItem, true)
            }

            function update(newNotification) {
                notification = newNotification;
                summary.text = newNotification.summary;
                body.text = newNotification.body;
                notificationIcon.source = notificationItem.getIconSource(newNotification);
                animHook.restartTimer();
            }
        }
    }
}
