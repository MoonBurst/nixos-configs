import QtQuick 2.15
import QtQuick.Window 2.15

// import Quickshell 1.0                       // Uncomment if you use Quickshell types or theme singletons
// import Quickshell.Services.Notifications 1.0 // Uncomment if you use notification service types

// import "../../bar/Theme.qml" as Theme        // Uncomment if you use Theme.qml for colors
// import "NotificationAnimation.qml" as Anim   // Uncomment if you have a shared animation helper
// import "CustomNotificationRules.qml" as CustomRules // Uncomment if you plan to use a rules object

Item {
    id: root
    width: parent ? parent.width : 800
    height: parent ? parent.height : 600

    // property var rules: CustomRules.rules    // Uncomment to enable custom notification rules

    property var notifications: []

    // --- Core notification handler ---
    function handleNotification(notification) {
        console.log("handleNotification called:", notification && notification.title, notification && notification.summary, notification && notification.body);

        // Optionally enable rules:
        // if (root.rules && root.rules.apply) {
        //     notification = root.rules.apply(notification);
        //     if (notification.suppress)
        //         return; // skip
        // }

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
            root.notifications.splice(index,1);
            positionNotifications();
        }
    }

    // --- Notification pop-up component ---
    Component {
        id: notificationComponent
        Rectangle {
            id: notificationItem
            property var notification

            width: 380
            height: Math.max(100, col.implicitHeight + 20)
            radius: 10
            color: "#191919"              // Use "#191919" as fallback background
            border.color: "#FFD700"       // Fallback border color (golden)
            border.width: 2
            opacity: 0.97

            // --- Fade animation (example) ---
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // Optional: Fade in on appearance (remove if using Anim module)
            SequentialAnimation on opacity {
                running: true
                loops: 1
                PropertyAnimation { from: 0; to: 1; duration: 180 }
            }

            // Optional: Centralized animation usage
            // Component.onCompleted: Anim.fadeIn(notificationItem)

            function fadeOutAndClose() {
                // Fade out, then destroy (add timeout if needed)
                opacity = 0.0;
                Qt.callLater(function() {
                    if (root) root.closeNotification(notificationItem.notification);
                }, 210);
            }

            Column {
                id: col
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6

                Text {
                    text: notification.summary || notification.title || "(No title)"
                    font.bold: true
                    font.pixelSize: 18
                    color: "#FFFBCC" // pale yellow
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                Text {
                    text: notification.body || ""
                    font.pixelSize: 16
                    color: "#EDEDED"
                    wrapMode: Text.Wrap
                }
            }

            // Auto-close after 6 sec
            Timer {
                interval: 6000; running: true; repeat: false
                onTriggered: notificationItem.fadeOutAndClose()
            }

            MouseArea {
                anchors.fill: parent
                onClicked: notificationItem.fadeOutAndClose()
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    // --- Example for loading rules at startup ---
    // Component.onCompleted: {
    //     root.rules = CustomRules.rules;
    // }
}
