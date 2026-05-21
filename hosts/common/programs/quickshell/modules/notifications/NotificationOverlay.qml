import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root

    property var notifications: []

    function handleNotification(notification) {
        let existing = root.notifications.find(n => n.id === notification.id);
        if (existing) {
            existing.update(notification);
        } else {
            let newNotification = notificationComponent.createObject(root, { notification: notification });
            root.notifications.push(newNotification);
            positionNotifications();
        }
    }

    function positionNotifications() {
        let y = 20;
        for (var i = 0; i < root.notifications.length; i++) {
            let notification = root.notifications[i];
            notification.y = y;
            y += notification.height + 10;
        }
    }

    function closeNotification(notification) {
        let index = root.notifications.findIndex(n => n.notification.id === notification.id);
        if (index !== -1) {
            root.notifications[index].destroy();
            root.notifications.splice(index, 1);
            positionNotifications();
        }
    }

    Component {
        id: notificationComponent

        Rectangle {
            id: notificationItem

            property var notification
            width: 300
            height: 100
            x: root.width - width - 20

            radius: 10
            color: "#222222"
            border.color: "#333333"
            border.width: 1

            function update(newNotification) {
                notification.title = newNotification.title;
                notification.body = newNotification.body;
                // Update other properties as needed
            }

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                Text {
                    text: notificationItem.notification.title
                    font.bold: true
                    color: "white"
                }

                Text {
                    text: notificationItem.notification.body
                    color: "white"
                    wrapMode: Text.Wrap
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeNotification(notificationItem.notification)
            }
        }
    }
}
