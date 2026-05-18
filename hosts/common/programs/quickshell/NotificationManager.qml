pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "."

Item {
    id: rootManagerItem
    anchors.fill: parent
    required property var bar

    NotificationServer {
        id: notifServer
        actionsSupported: true

        onNotification: notif => {
            notif.tracked = true;
            notifListModel.append({"notifObject": notif});
        }
    }

    ListView {
        id: stackDisplayView
        
        model: ListModel {
            id: notifListModel
        }

        y: rootManagerItem.bar.height + 15
        anchors.right: parent.right
        anchors.rightMargin: 15
        
        width: 250
        height: parent.height > y ? parent.height - y : 400
        spacing: 15
        interactive: false

        delegate: Notif {
            // Natively passes down the correct data property block
            notif: model.notifObject
            
            onDismissed: {
                if (model.notifObject) model.notifObject.dismiss();
                notifListModel.remove(index);
            }
        }
    }
}
