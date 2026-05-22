import QtQuick
import QtQuick.Controls 2
import Quickshell.Services.Notifications

Item {
    id: root

    property var theme: null

    anchors.fill: parent

    property var notifications: []

    function handleNotification(notification) {
        console.log("handleNotification called:", notification && notification.summary, notification && notification.body);

        let existing = root.notifications.find(n =>
        n.notification && n.notification.id === notification.id
        );
        if (existing) {
            existing.update(notification);
        } else {
            let newNotification = notificationComponent.createObject(root, {
                notification: notification
            });
            root.notifications.push(newNotification);
            positionNotifications();
        }
    }

    function positionNotifications() {
        let y = 30;
        for (var i = 0; i < root.notifications.length; i++) {
            let notification = root.notifications[i];
            notification.y = y;
            notification.x = root.width - notification.width - 30;
            y += notification.height + 16;
        }
    }

    function closeNotification(notification) {
        let index = root.notifications.findIndex(n =>
        n.notification && n.notification.id === notification.id
        );
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
            height: 80
            // Fixed fallback string value to prevent type constructor cast warnings
            color: root.theme ? root.theme.base00 : "black"
            radius: 10

            Text {
                id: summary
                text: notification.summary
                // Fixed fallback string value to prevent type constructor cast warnings
                color: root.theme ? root.theme.base05 : "white"
                font.bold: true
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 10
                anchors.leftMargin: 10
            }

            Text {
                id: body
                text: notification.body
                // Fixed fallback string value to prevent type constructor cast warnings
                color: root.theme ? root.theme.base05 : "white"
                wrapMode: Text.WordWrap
                anchors.top: summary.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 5
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.bottomMargin: 10
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeNotification(notification)
            }

            function update(newNotification) {
                notification = newNotification;
                summary.text = newNotification.summary;
                body.text = newNotification.body;
            }
        }
    }
}
