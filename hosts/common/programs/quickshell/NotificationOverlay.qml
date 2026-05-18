import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io
import Quickshell.Widgets

Scope {
    id: root

    // Dictionary tracking active native notification object handles to dismiss or query them later
    property var activeNotifications: ({})


    // Main data structure holding the active notification instances currently displayed on screen
    ListModel {
        id: notificationModel
    }


    // Safe Garbage Collector: Periodically scrubs truly dead alerts when no animations are active
    Timer {
        id: garbageCollectorClock
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            // Iterates backwards to safely remove data entries without breaking running loops
            for (let i = notificationModel.count - 1; i >= 0; i--) {
                let item = notificationModel.get(i);
                if (item && item.isDead) {
                    notificationModel.remove(i);
                }
            }
        }
    }


    // Shell process tasked with searching local system paths for matching icons when an app gives a generic string name
    Process {
        id: globalIconFinder
        property int targetIndex: -1
        property string searchInput: ""

        command: ["sh", "-c", "find -L /run/current-system/sw/share/icons ~/.icons ~/.local/share/icons -name \"*" + searchInput + "*.png\" -o -name \"*" + searchInput + "*.svg\" | head -n 1"]

        onSearchInputChanged: {
            if (searchInput !== "") {
                globalIconFinder.running = true;
            }
        }

        stdout: SplitParser {
            onRead: (line) => {
                if (line && line.trim() !== "" && globalIconFinder.targetIndex >= 0 && globalIconFinder.targetIndex < notificationModel.count) {
                    notificationModel.setProperty(globalIconFinder.targetIndex, "iconPath", "file://" + line.trim());
                }
            }
        }
    }


    // Background listener socket connecting to a Linux named pipe (/tmp/qs_notification_pipe)
    // Listens for external keyboard shortcut calls or scripts to run actions via shell echoes
    Process {
        id: pipeListener
        command: ["sh", "-c", "mkdir -p /tmp && rm -f /tmp/qs_notification_pipe && mkfifo /tmp/qs_notification_pipe && while true; do if read -r line < /tmp/qs_notification_pipe; then printf '%s\\n' \"$line\"; fi; done"]
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


    // Helper function calculating how many living alerts are remaining on the panel layout
    function getLivingCount(): int {
        let living = 0;
        for (let i = 0; i < notificationModel.count; i++) {
            if (!notificationModel.get(i).isDead) living++;
        }
        return living;
    }


    /**
     * Function: displayDismissalMessageAndClear
     * Purpose: Triggered when receiving the "dismiss" command via the pipe.
     * It transforms the oldest displayed notification card text into an alert banner,
     * changes the border color to flashing red, and sets up a quick 100ms timer
     * to transition the item out cleanly.
     */
    function displayDismissalMessageAndClear(): void {
        if (notificationModel.count === 0) return;

        let oldestIndex = 0;
        let targetId = notificationModel.get(oldestIndex).notifId;

        // Visual modification alerting the user that a dismissal sequence is occurring
        notificationModel.setProperty(oldestIndex, "summary", "System Alert");
        notificationModel.setProperty(oldestIndex, "body", "Dismissing notification...");
        notificationModel.setProperty(oldestIndex, "borderColor", "#ff0000");
        notificationModel.setProperty(oldestIndex, "isManualDismissing", true);

        let timer = Qt.createQmlObject('import QtQuick; Timer { interval: 100; running: true; repeat: false; }', root);
        timer.triggered.connect(() => {
            for (let i = 0; i < notificationModel.count; i++) {
                if (notificationModel.get(i).notifId === targetId) {
                    notificationModel.setProperty(i, "forceDismiss", true);
                    break;
                }
            }
            timer.destroy();
        });
    }


    /**
     * Function: updateHotkeyTargetCacheFile
     * Purpose: Writes the raw ID of the absolute latest notification to a static file in /tmp.
     * This acts as an API endpoint for external system hotkeys, allowing background scripts
     * to know exactly which ID to query when interacting with notifications via a pipe.
     */
    function updateHotkeyTargetCacheFile(): void {
        let currentTargetId = 0;
        if (notificationModel.count > 0) {
            currentTargetId = notificationModel.get(notificationModel.count - 1).notifId;
        }
        let proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["sh", "-c", "echo ' + currentTargetId + ' > /tmp/qs_latest_id"]; running: true; }', root);
        proc.exited.connect(() => { proc.destroy(); });
    }


    /**
     * Function: triggerLatestNotificationAction
     * Purpose: Triggered when receiving the "action" command via the pipe.
     * Grabs the most recent notification, resolves its native object instance,
     * and triggers its action button loop array. If no actions exist, it closes it.
     */
    function triggerLatestNotificationAction(): void {
        if (notificationModel.count > 0) {
            let latestIndex = notificationModel.count - 1;
            let item = notificationModel.get(latestIndex);
            let nativeNotif = root.activeNotifications[item.notifId];

            if (nativeNotif && typeof nativeNotif.dismiss === "function") {
                let actionsList = nativeNotif.actions;
                if (actionsList && actionsList.length > 0) actionsList.trigger();
                else nativeNotif.dismiss();
            }
            notificationModel.setProperty(latestIndex, "forceDismiss", true);
        }
    }


    /**
     * Function: handleNotification
     * Purpose: The entry point for incoming system notifications.
     * Manages custom text checks, app title rules, theme matching, playbacks,
     * and constructs the tracking properties saved to the ListModel.
     */
    function handleNotification(n: Notification): void {
        let cleanSummary = (n.summary || "").trim().toLowerCase();
        if (cleanSummary.includes("!!action")) {
            root.triggerLatestNotificationAction();
            n.dismiss(NotificationDismissReason.Dismissed);
            return;
        }

        // Checks for screenshot tools like Satty; if active, groups text instead of making a new card
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

        // Custom config list linking app keywords to custom border frames and sound files
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

        // Checks the notification hints array to see if the sending app passed a raw inline byte image buffer
        let hasRawHint = false;
        if (n.hints) {
            let keys = Object.getOwnPropertyNames(n.hints);
            for (let k = 0; k < keys.length; k++) {
                let currentKey = keys[k];
                if (currentKey === "image-data" || currentKey === "image_data" || currentKey === "icon_data") {
                    hasRawHint = true;
                    break;
                }
            }
        }

        // Resolves the asset location based on path prefix validations
        if (matchedName !== "") {
            chosenIcon = baseDir + matchedName + "/" + matchedName + ".png";
        } else if (n.icon && n.icon !== "") {
            if (n.icon.startsWith("/") || n.icon.startsWith("file://")) {
                chosenIcon = n.icon.startsWith("/") ? "file://" + n.icon : n.icon;
            } else {
                chosenIcon = "image://theme/" + n.icon;
            }
        }

        let targetIndex = notificationModel.count;
        root.activeNotifications[n.id] = n;

        // Adds the notification into the display model tracking map
        notificationModel.append({
            "notifId": n.id,
            "appName": n.appName,
            "summary": n.summary,
            "body": n.body,
            "iconPath": chosenIcon,
            "borderColor": frameColor,
            "hasRawHint": hasRawHint,
            "forceDismiss": false,
            "isExternalClose": false,
            "isManualDismissing": false,
            "isDead": false
        });

        // Triggers the background path loop search if no specific asset was found
        if (!hasRawHint && chosenIcon === baseDir + "fallback.png" && n.icon && n.icon !== "" && !n.icon.startsWith("/") && !n.icon.startsWith("file://")) {
            globalIconFinder.targetIndex = targetIndex;
            globalIconFinder.searchInput = n.icon.toLowerCase();
        }

        root.updateHotkeyTargetCacheFile();
    }


    /**
     * Function: removeNotificationCardInstance
     * Purpose: Performs cleanup for closed notifications.
     * Flag-deletes references to maintain 100% stable context metrics for running animations.
     */
    function removeNotificationCardInstance(id, isExternalClose) {
        for (let i = 0; i < notificationModel.count; i++) {
            let item = notificationModel.get(i);
            if (item.notifId === id) {
                if (!isExternalClose) {
                    let nativeNotif = root.activeNotifications[id];
                    if (nativeNotif && typeof nativeNotif.dismiss === "function") {
                        try {
                            nativeNotif.dismiss();
                        } catch(e) {}
                    }
                }
                // Flags the card as dead instead of popping it instantly out of existence
                notificationModel.setProperty(i, "isDead", true);
                break;
            }
        }
        if (root.activeNotifications[id]) delete root.activeNotifications[id];
        root.updateHotkeyTargetCacheFile();
    }


    // Multi-screen window instantiation logic
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            visible: modelData.name === "DP-1" && root.getLivingCount() > 0

            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.namespace: "quickshell-notifications"
            WlrLayershell.keyboardFocus: WlrLayershell.None

            anchors { top: true; right: true }
            margins { top: 50; right: 15 }

            // Fixed width mapping matches your card layouts
            implicitWidth: 440

            // THE FIX: Giving the window a fixed vertical ceiling stops clipping boundaries.
            // Because the window color is completely transparent, an oversized ceiling is invisible.
            implicitHeight: 600
            color: "transparent"

            Item {
                id: stackContainer
                width: 440

                // Pushes the entire container area down by 15 pixels inside the window canvas scope.
                // This grants newly spawned entry elements immediate vertical padding to draw borders.
                anchors.top: parent.top
                anchors.topMargin: 15
                anchors.left: parent.left


                Repeater {
                    model: notificationModel

                    delegate: Rectangle {
                        id: card

                        property bool isHovered: false

                        // Completely suppresses visibility if marked dead, but leaves the context structure intact
                        visible: !model.isDead
                        width: model.isDead ? 0 : 400
                        height: model.isDead ? 0 : 120
                        radius: 10
                        color: "#000000"
                        border.width: model.isDead ? 0 : 5
                        border.color: model && model.borderColor ? model.borderColor : "#0000ff"
                        clip: true

                        // Stacking calculations safely adjust to living counts to prevent jumping layouts
                        y: card.state === "slideOut" ? y : ((notificationModel.count - 1 - index) * 12)
                        z: 100 - index

                        property real xOffset: 450
                        transform: Translate { x: card.xOffset }
                        property real lifetimeRemaining: 5000
                        property real timePromotedToTop: 0

                        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        Behavior on border.color { ColorAnimation { duration: 80 } }

                        NumberAnimation {
                            id: entranceAnimation
                            target: card
                            property: "xOffset"
                            to: 0
                            duration: 250
                            easing.type: Easing.OutQuad
                        }

                        Component.onCompleted: {
                            entranceAnimation.start();
                        }

                        Timer {
                            interval: 100
                            running: !model.isDead && card.state !== "slideOut"
                            repeat: true
                            onTriggered: {
                                if (!model || model.isDead) return;

                                if (model.forceDismiss) {
                                    notificationModel.setProperty(index, "isExternalClose", true);
                                    card.state = "slideOut";
                                    return;
                                }

                                if (card.isHovered) return;

                                if (index === 0) {
                                    if (card.timePromotedToTop === 0) card.timePromotedToTop = Date.now();
                                    if (!model.isManualDismissing) {
                                        let currentLifetime = card.lifetimeRemaining - 100;
                                        card.lifetimeRemaining = currentLifetime;
                                        let timeSpentOnTop = Date.now() - card.timePromotedToTop;
                                        if (currentLifetime <= 0 && timeSpentOnTop >= 2000) card.state = "slideOut";
                                    }
                                } else {
                                    if (!model.isManualDismissing && card.lifetimeRemaining > 0) {
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
                                    NumberAnimation { target: card; property: "xOffset"; duration: 150; easing.type: Easing.InQuad }
                                    ScriptAction {
                                        script: {
                                            root.removeNotificationCardInstance(model.notifId, model.isExternalClose);
                                        }
                                    }
                                }
                            }
                        ]

                        Item {
                            width: 400
                            height: 120
                            anchors.left: parent.left
                            anchors.top: parent.top
                            visible: !model.isDead

                            Rectangle {
                                id: iconContainer
                                width: 110
                                height: 110
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.margins: 5
                                color: "transparent"
                                visible: !model.isDead && (model.iconPath !== "" || model.hasRawHint)

                                IconImage {
                                    id: cardIconImage
                                    anchors.fill: parent
                                    source: model.hasRawHint ? "image://notification/" + model.notifId : model.iconPath
                                    mipmap: true
                                    asynchronous: true
                                }
                            }

                            ColumnLayout {
                                anchors.left: iconContainer.visible ? iconContainer.right : parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                anchors.topMargin: 10
                                spacing: 4

                                Text { text: model.summary; font.bold: true; font.family: "Iosevka Term"; font.pixelSize: 30; color: "#f7f716"; elide: Text.ElideRight; Layout.fillWidth: true }
                                 Text { text: model.body; font.family: "Iosevka Term"; font.pixelSize: 24; color: "#f7f716"; elide: Text.ElideRight; wrapMode: Text.Wrap; maximumLineCount: 2; Layout.fillWidth: true }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: !model.isDead
                            onEntered: card.isHovered = true
                            onExited: card.isHovered = false
                        }
                    }
                }
            }
        }
    }
}
