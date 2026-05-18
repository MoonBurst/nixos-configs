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

        function onNotification(notification) {
            root.handleNotification(notification);
        }
    }

    function handleNotification(n: Notification): void {
        // Safely pull text fields and normalise them to lowercase
        let appTitle = (n.appName || "").toLowerCase();
        let fullText = (n.summary + " " + n.body).toLowerCase();

        // Character theme lookup array matching your dunstrc matrix mappings
        let characters = [
            { name: "apogee",        summary: "apogee",        color: "#0CD0CD", sound: false },
            { name: "solar_sonata",  summary: "solar sonata",  color: "#f7f716", sound: true  },
            { name: "cageheart",     summary: "cageheart",     color: "#8ad5a6", sound: true  },
            { name: "olivia",        summary: "olivia",        color: "#18FFD5", sound: true  },
            { name: "genesis_frost", summary: "genesis frost", color: "#9ce8ff", sound: false },
            { name: "luster_dawn",   summary: "luster_dawn",   color: "#e041de", sound: true  }
        ];

        let matchedName = "";
        let frameColor = "#0000ff"; // Default urgency_normal blue frame_color fallback

        for (let i = 0; i < characters.length; i++) {
            let item = characters[i];

            // Matches if the application sender is named after the character (e.g. appName: "Solar Sonata" or "sonata")
            // Or falls back to matching if the character name is written inside the message content body
            if (appTitle.includes(item.summary) || appTitle.includes(item.name) || fullText.includes(item.summary)) {
                matchedName = item.name;
                frameColor = item.color;

                // Spawn the background audio sequence if sound tracking is set to true
                if (item.sound) {
                    let soundPath = Quickshell.env("HOME") + "/nix/hosts/common/programs/quickshell/resources/" + matchedName + "/" + matchedName + ".flac";
                    let soundProc = Qt.createQmlObject(
                        'import Quickshell.Io; Process { command: ["pw-play", "' + soundPath + '"]; running: true; }',
                        root
                    );
                    soundProc.exited.connect((exitCode) => { soundProc.destroy(); });
                }
                break;
            }
        }

        let baseDir = "file://" + Quickshell.env("HOME") + "/nix/hosts/common/programs/quickshell/resources/";
        let chosenIcon = baseDir + "fallback.png";

        if (matchedName !== "") {
            chosenIcon = baseDir + matchedName + "/" + matchedName + ".png";
        } else if (n.icon && n.icon !== "") {
            chosenIcon = n.icon;
        }

        notificationModel.append({
            "notifId": n.id,
            "appName": n.appName,
            "summary": n.summary,
            "body": n.body,
            "iconPath": chosenIcon,
            "borderColor": frameColor,
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
            margins { top: 50; right: 15 }

            implicitWidth: 420
            implicitHeight: notifColumn.implicitHeight
            color: "transparent"

            ColumnLayout {
                id: notifColumn
                width: 400
                spacing: 10

                Repeater {
                    model: notificationModel
                    delegate: Rectangle {
                        required property int notifId
                        required property string appName
                        required property string summary
                        required property string body
                        required property string iconPath
                        required property string borderColor

                        Layout.fillWidth: true
                        height: 120
                        radius: 10
                        color: "#000000"
                        border.width: 5
                        border.color: borderColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 15

                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 100
                                visible: parent.parent.iconPath !== ""
                                color: "transparent"

                                Image {
                                    anchors.fill: parent
                                    source: parent.parent.parent.iconPath
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: parent.parent.parent.summary
                                    font.bold: true
                                    font.family: "Iosevka Term"
                                    font.pixelSize: 20
                                    color: "#f7f716"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: parent.parent.parent.body
                                    font.family: "Iosevka Term"
                                    font.pixelSize: 20
                                    color: "#f7f716"
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
                                    font.family: "Iosevka Term"
                                    font.pixelSize: 24
                                    color: "#f7f716"
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
