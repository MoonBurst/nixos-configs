import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: root

    ListModel {
        id: notificationModel
    }

    NotificationServer {
        id: notificationServer
        bodyMarkupSupported: true
        actionsSupported: true
    }

    Connections {
        target: notificationServer
        onNotification: (notification) => {
            root.handleNotification(notification);
        }
    }

    function handleNotification(n: Notification): void {
        notificationModel.append({
            "notifId": n.id,
            "appName": n.appName,
            "summary": n.summary,
            "body": n.body,
            "objRef": n
        });

        let timer = Qt.createQmlObject('import QtQuick; Timer { interval: 5000; running: true; repeat: false; }', root);
        timer.triggered.connect(() => {
            root.dismissNotificationById(n.id);
            timer.destroy();
        });
    }

    function dismissNotificationById(id: int): void {
        for (let i = 0; i < notificationModel.count; i++) {
            let item = notificationModel.get(i);
            if (item.notifId === id) {
                if (item.objRef) {
                    item.objRef.dismiss(NotificationDismissReason.Expired);
                }
                notificationModel.remove(i);
                break;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: modelData.name === "DP-1" && notificationModel.count > 0

            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.namespace: "quickshell-notifications"
            WlrLayershell.keyboardFocus: WlrLayershell.None

            anchors { top: true; right: true }
            margins { top: 60; right: 20 }

            implicitWidth: 340
            implicitHeight: notifColumn.implicitHeight
            color: "transparent"

            ColumnLayout {
                id: notifColumn
                width: 320
                spacing: 10

                Repeater {
                    model: notificationModel
                    delegate: Rectangle {
                        required property int notifId
                        required property string appName
                        required property string summary
                        required property string body

                        Layout.fillWidth: true
                        height: 110
                        radius: Theme.capsuleRadius || 8
                        color: Theme.colorBaseBg || "#1e1e2e"
                        border.width: Theme.capsuleBorderWidth || 1
                        border.color: Theme.colorOutline || "#003399"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: parent.parent.parent.summary
                                    font.bold: true
                                    font.family: "monospace"
                                    font.pixelSize: 20
                                    color: Theme.colorNormalText || "#ffffff"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: parent.parent.parent.body
                                    font.family: "monospace"
                                    font.pixelSize: 20
                                    color: Theme.colorDimText || "#aaaaaa"
                                    elide: Text.ElideRight
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                cursorShape: Qt.PointingHandCursor

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    font.pixelSize: 24
                                    color: Theme.colorDimText || "#aaaaaa"
                                }

                                onClicked: root.dismissNotificationById(parent.parent.notifId)
                            }
                        }
                    }
                }
            }
        }
    }
}
