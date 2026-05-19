import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

        // Enabled all specification settings per your documentation
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        persistenceSupported: true
        inlineReplySupported: true
        keepOnReload: true
        extraHints: []
    }

    Connections {
        target: notificationServer
        onNotification: (notification) => {
            root.handleNotification(notification);
        }
    }

    function handleNotification(n) {
        // Extracting image source or fallback icon path from notification data
        let iconSrc = n.image ? n.image : (n.icon ? n.icon : "");

        // Parse flat action array pairs ([id1, text1, id2, text2...]) into safe primitive metadata pairs
        let actionPairs = [];
        if (n.actions && n.actions.length > 0) {
            for (let i = 0; i < n.actions.length; i += 2) {
                if (i + 1 < n.actions.length) {
                    actionPairs.push({
                        "actionId": n.actions[i],
                        "label": n.actions[i+1]
                    });
                }
            }
        }

        notificationModel.append({
            "notifId": n.id,
            "appName": n.appName,
            "summary": n.summary,
            "body": n.body,
            "iconPath": iconSrc.toString(),
                                 "rawActionsJson": JSON.stringify(actionPairs)
        });

        let timer = Qt.createQmlObject('import QtQuick; Timer { interval: 5000; running: true; repeat: false; }', root);
        timer.triggered.connect(() => {
            root.dismissNotificationById(n.id);
            timer.destroy();
        });
    }

    function dismissNotificationById(id) {
        for (let i = 0; i < notificationModel.count; i++) {
            let item = notificationModel.get(i);
            if (item.notifId === id) {
                // Safely broadcast server closure states out over DBus using native daemon method
                notificationServer.dismiss(id, NotificationDismissReason.Expired);
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
                        id: card

                        // Explicitly preserve unique tracking signatures outside inner button loops
                        readonly property int cardRowIdx: index
                        readonly property int targetedNotifId: model ? model.notifId : -1

                        required property int notifId
                        required property string appName
                        required property string summary
                        required property string body
                        required property string iconPath
                        required property string rawActionsJson

                        Layout.fillWidth: true
                        height: (rawActionsJson && rawActionsJson !== "[]") ? 150 : 110
                        radius: 8
                        color: "#1e1e2e"
                        border.width: 1
                        border.color: "#003399"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Image {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    source: card.iconPath
                                    visible: card.iconPath !== ""
                                    fillMode: Image.PreserveAspectFit
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: card.summary
                                        font.bold: true
                                        font.family: "monospace"
                                        font.pixelSize: 20
                                        color: "#ffffff"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: card.body
                                        font.family: "monospace"
                                        font.pixelSize: 20
                                        color: "#aaaaaa"
                                        elide: Text.ElideRight
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 5
                                        Layout.fillWidth: true
                                        textFormat: Text.StyledText
                                    }
                                }

                                MouseArea {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    cursorShape: Qt.PointingHandCursor

                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        font.pixelSize: 20
                                        color: "#aaaaaa"
                                    }

                                    onClicked: {
                                        notificationServer.dismiss(card.targetedNotifId, NotificationDismissReason.Dismissed);
                                        notificationModel.remove(card.cardRowIdx);
                                    }
                                }
                            }

                            RowLayout {
                                id: actionButtonsRow
                                Layout.fillWidth: true
                                spacing: 8
                                visible: card.rawActionsJson && card.rawActionsJson !== "[]"

                                Repeater {
                                    model: (card.rawActionsJson && card.rawActionsJson !== "[]") ? JSON.parse(card.rawActionsJson) : []

                                    delegate: Button {
                                        id: actionBtn
                                        text: modelData.label

                                        background: Rectangle {
                                            color: actionBtn.down ? "#333344" : (actionBtn.hovered ? "#252538" : "#111111")
                                            border.color: "#003399"
                                            border.width: 1
                                            radius: 4
                                        }

                                        contentItem: Text {
                                            text: actionBtn.text
                                            font.family: "monospace"
                                            font.pixelSize: 14
                                            color: "#ffffff"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onClicked: {
                                            // --- FIX: EMIT THE INTERACTION SIGNAL FIRST, THEN CLOSE ---
                                            if (modelData && modelData.actionId !== undefined && card.targetedNotifId !== -1) {
                                                notificationServer.actionInvoked(card.targetedNotifId, modelData.actionId);
                                            }

                                            // Close and remove the UI layout block immediately
                                            notificationModel.remove(card.cardRowIdx);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
