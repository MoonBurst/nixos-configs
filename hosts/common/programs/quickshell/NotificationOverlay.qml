import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io

Scope {
    id: root

    property var activeNotifications: ({})

    ListModel {
        id: notificationModel
    }

    NotificationServer {
        id: notificationServer
        bodyMarkupSupported: true
        actionsSupported: true
    }

    // UNIFIED PIPELINE ENGINE: Tracks /run/user/1000/quickshell-input perpetually using tail -f
    Process {
        id: pipeListener
        command: ["sh", "-c", "mkdir -p /run/user/1000 && rm -f /run/user/1000/quickshell-input && mkfifo /run/user/1000/quickshell-input && exec tail -f /run/user/1000/quickshell-input"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line) return;
                let cmd = line.trim();
                if (cmd === "dismiss") {
                    root.displayDismissalMessageAndClear();
                } else if (cmd === "action") {
                    root.triggerLatestNotificationAction();
                }
            }
        }
    }

    // Targets and dismisses ONLY the single oldest active notification (index 0)
    function displayDismissalMessageAndClear(): void {
        if (notificationModel.count === 0) return;

        let oldestIndex = 0;
        notificationModel.setProperty(oldestIndex, "summary", "System Alert");
        notificationModel.setProperty(oldestIndex, "body", "Dismissing notification...");
        notificationModel.setProperty(oldestIndex, "borderColor", "#ff0000");
        notificationModel.setProperty(oldestIndex, "isManualDismissing", true);

        // Minimal 100ms visual buffer to process the red color flip before accelerating out
        let timer = Qt.createQmlObject('import QtQuick; Timer { interval: 100; running: true; repeat: false; }', root);
        timer.triggered.connect(() => {
            if (notificationModel.count > 0) {
                notificationModel.setProperty(oldestIndex, "forceDismiss", true);
            }
            timer.destroy();
        });
    }

    Connections {
        target: notificationServer
        function onNotification(notification) { root.handleNotification(notification); }
        function onNotificationClosed(id, reason) {
            for (let i = 0; i < notificationModel.count; i++) {
                if (notificationModel.get(i).notifId === id) {
                    notificationModel.setProperty(i, "forceDismiss", true);
                    break;
                }
            }
            if (root.activeNotifications[id]) delete root.activeNotifications[id];
        }
    }

    function updateHotkeyTargetCacheFile(): void {
        let currentTargetId = 0;
        if (notificationModel.count > 0) {
            currentTargetId = notificationModel.get(notificationModel.count - 1).notifId;
        }
        let proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["sh", "-c", "echo ' + currentTargetId + ' > /tmp/qs_latest_id"]; running: true; }', root);
        proc.exited.connect(() => { proc.destroy(); });
    }

    function triggerLatestNotificationAction(): void {
        if (notificationModel.count > 0) {
            let latestIndex = notificationModel.count - 1;
            let item = notificationModel.get(latestIndex);
            let nativeNotif = root.activeNotifications[item.notifId];
            if (nativeNotif) {
                let actionsList = nativeNotif.actions;
                if (actionsList && actionsList.length > 0) actionsList.trigger();
                else nativeNotif.dismiss();
            }
            notificationModel.setProperty(latestIndex, "forceDismiss", true);
        }
    }

    function handleNotification(n: Notification): void {
        let cleanSummary = (n.summary || "").trim().toLowerCase();
        if (cleanSummary.includes("!!action")) {
            root.triggerLatestNotificationAction();
            n.dismiss(NotificationDismissReason.Dismissed);
            return;
        }

        let appTitle = (n.appName || "").toLowerCase();
        if (appTitle.includes("satty")) {
            for (let i = 0; i < notificationModel.count; i++) {
                let existingItem = notificationModel.get(i);
                if ((existingItem.appName || "").toLowerCase().includes("satty")) {
                    let updatedBody = existingItem.body + "\n" + n.body;
                    notificationModel.setProperty(i, "body", updatedBody);
                    n.dismiss(NotificationDismissReason.Dismissed);
                    return;
                }
            }
        }

        let characters = [
            { name: "apogee",        summary: "apogee",        color: "#0CD0CD", sound: false },
            { name: "solar_sonata",  summary: "solar sonata",  color: "#f7f716", sound: true  },
            { name: "cageheart",     summary: "cageheart",     color: "#8ad5a6", sound: true  },
            { name: "olivia",        summary: "olivia",        color: "#18FFD5", sound: true  },
            { name: "genesis_frost", summary: "genesis frost", color: "#9ce8ff", sound: false },
            { name: "luster_dawn",   summary: "luster_dawn",   color: "#e041de", sound: true  }
        ];

        let matchedName = "";
        let frameColor = "#0000ff";

        for (let i = 0; i < characters.length; i++) {
            let item = characters[i];
            if (appTitle.includes(item.summary) || appTitle.includes(item.name) || (n.summary + " " + n.body).toLowerCase().includes(item.summary)) {
                matchedName = item.name;
                frameColor = item.color;
                if (item.sound) {
                    let soundPath = Quickshell.env("HOME") + "/nix/hosts/common/programs/quickshell/resources/" + matchedName + "/" + matchedName + ".flac";
                    let soundProc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["pw-play", "' + soundPath + '"]; running: true; }', root);
                    soundProc.exited.connect(() => { soundProc.destroy(); });
                }
                break;
            }
        }

        let baseDir = "file://" + Quickshell.env("HOME") + "/nix/hosts/common/programs/quickshell/resources/";
        let chosenIcon = baseDir + "fallback.png";

        if (matchedName !== "") chosenIcon = baseDir + matchedName + "/" + matchedName + ".png";
        else if (n.icon && n.icon !== "") chosenIcon = n.icon;

        root.activeNotifications[n.id] = n;

        notificationModel.append({
            "notifId": n.id,
            "appName": n.appName,
            "summary": n.summary,
            "body": n.body,
            "iconPath": chosenIcon,
            "borderColor": frameColor,
            "forceDismiss": false,
            "isExternalClose": false,
            "isManualDismissing": false
        });
        root.updateHotkeyTargetCacheFile();
    }

    function removeNotificationCardInstance(id: int, isExternalClose: bool): void {
        for (let i = 0; i < notificationModel.count; i++) {
            let item = notificationModel.get(i);
            if (item.notifId === id) {
                if (!isExternalClose) {
                    let nativeNotif = root.activeNotifications[id];
                    if (nativeNotif) nativeNotif.dismiss();
                }
                notificationModel.remove(i);
                break;
            }
        }
        if (root.activeNotifications[id]) delete root.activeNotifications[id];
        root.updateHotkeyTargetCacheFile();
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: notificationModel.count > 0
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.namespace: "quickshell-notifications"
            WlrLayershell.keyboardFocus: WlrLayershell.None
            anchors { top: true; right: true }
            margins { top: 50; right: 15 }
            implicitWidth: 440
            implicitHeight: notificationModel.count > 0 ? 120 + (12 * (notificationModel.count - 1)) : 0
            color: "transparent"

            Item {
                id: stackContainer
                width: 440
                anchors.top: parent.top
                anchors.left: parent.left

                Repeater {
                    model: notificationModel
                    delegate: Rectangle {
                        id: card
                        required property int index
                        required property int notifId
                        required property string appName
                        required property string summary
                        required property string body
                        required property string iconPath
                        required property string borderColor
                        required property bool forceDismiss
                        required property bool isExternalClose
                        required property bool isManualDismissing

                        width: 400
                        height: 120
                        radius: 10
                        color: "#000000"
                        border.width: 5
                        border.color: borderColor
                        clip: true

                        y: (notificationModel.count - 1 - index) * 12
                        z: 100 - index

                        property real xOffset: 450
                        transform: Translate { x: card.xOffset }
                        property real lifetimeRemaining: 5000
                        property real timePromotedToTop: 0

                        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        Behavior on border.color { ColorAnimation { duration: 80 } }

                        Component.onCompleted: {
                            entranceAnimation.start();
                        }

                        NumberAnimation {
                            id: entranceAnimation
                            target: card
                            property: "xOffset"
                            to: 0
                            duration: 250
                            easing.type: Easing.OutQuad
                        }

                        Timer {
                            interval: 100
                            running: card.state !== "slideOut"
                            repeat: true
                            onTriggered: {
                                if (forceDismiss) {
                                    notificationModel.setProperty(index, "isExternalClose", true);
                                    card.state = "slideOut";
                                    return;
                                }
                                if (index === 0) {
                                    if (card.timePromotedToTop === 0) card.timePromotedToTop = Date.now();
                                    if (!isManualDismissing) {
                                        let currentLifetime = card.lifetimeRemaining - 100;
                                        card.lifetimeRemaining = currentLifetime;
                                        let timeSpentOnTop = Date.now() - card.timePromotedToTop;
                                        if (currentLifetime <= 0 && timeSpentOnTop >= 2000) card.state = "slideOut";
                                    }
                                } else {
                                    if (!isManualDismissing && card.lifetimeRemaining > 0) {
                                        card.lifetimeRemaining -= 100;
                                    }
                                }
                            }
                        }

                        states: [
                            State {
                                name: "slideOut"
                                PropertyChanges { target: card; xOffset: 450 }
                            }
                        ]
                        transitions: [
                            Transition {
                                from: ""
                                to: "slideOut"
                                SequentialAnimation {
                                    NumberAnimation { target: card; property: "xOffset"; duration: 100; easing.type: Easing.InQuad }
                                    ScriptAction { script: root.removeNotificationCardInstance(notifId, isExternalClose) }
                                }
                            }
                        ]

                        Item {
                            width: 400
                            height: 120
                            anchors.left: parent.left
                            anchors.top: parent.top

                            Rectangle {
                                id: iconContainer
                                width: 110
                                height: 110
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.margins: 5
                                visible: iconPath !== ""
                                color: "transparent"
                                Image { anchors.fill: parent; source: iconPath; fillMode: Image.PreserveAspectFit; asynchronous: true; cache: true }
                            }

                            ColumnLayout {
                                anchors.left: iconContainer.visible ? iconContainer.right : parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                anchors.topMargin: 10
                                anchors.bottomMargin: 10
                                spacing: 4

                                Text { text: summary; font.bold: true; font.family: "Iosevka Term"; font.pixelSize: 20; color: "#f7f716"; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: body; font.family: "Iosevka Term"; font.pixelSize: 18; color: "#f7f716"; elide: Text.ElideRight; wrapMode: Text.Wrap; maximumLineCount: 2; Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }
        }
    }
}
