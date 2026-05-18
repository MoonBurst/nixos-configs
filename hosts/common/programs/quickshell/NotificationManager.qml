import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: notificationManager

    NotificationServer {
        id: notifServer
    }

    ListView {
        id: notificationList
        model: notifServer.trackedNotifications

        // Triggers dynamically on every add, remove, or change event
        onCountChanged: {
            console.log("--> Current Live Count in Model: " + count)
        }

        delegate: Rectangle {
            width: 300
            height: 60
            color: "#222222"
            border.color: "#444444"
            border.width: 1
            radius: 8

            Text {
                anchors.centerIn: parent
                color: "#ffffff"
                text: (modelData.summary || "No Summary") + " - " + (modelData.body || "")
            }
        }
    }
}
