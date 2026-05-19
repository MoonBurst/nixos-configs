import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io

Scope {
    id: root

    property var knownIds: ({})

    // Core Array preserves raw C++ memory reference instances cleanly
    property var rawNotifCache: []

    // Cache to keep track of what the active top card's ID is
    property int currentTopCardId: -1

    ListModel {
        id: notifModel
    }

    NotificationServer {
        id: notificationServer

        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true

        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true

        persistenceSupported: true
        keepOnReload: true

        onNotification: (n) => root.handleNotification(n)
    }

    // Process engine to handle hotkey window activation commands over Sway IPC
    Process {
        id: swayActivator
    }

    // Dedicated process thread broadcasts standard D-Bus signatures
    // to instantly force apps to mark messages as read when actioned or closed
    Process {
        id: dbusReadSignaler
    }

    // MASTER DECK QUEUE TIMER: Handles urgent infinite sticking overrides
    Timer {
        id: topCardQueueTimer
        interval: 2000 // Each visible card stays on top of the deck for exactly 2 seconds

        // Timer will automatically pause execution loops if the active top card
        // is marked as urgent. This leaves critical notices stuck indefinitely until manually actioned.
        running: notifModel.count > 0 && !notifModel.get(notifModel.count - 1).removing && !notifModel.get(notifModel.count - 1).isUrgent
        repeat: false

        onTriggered: {
            if (notifModel.count > 0) {
                let oldestIndex = notifModel.count - 1;
                let oldestCard = notifModel.get(oldestIndex);
                if (oldestCard && !oldestCard.isUrgent) {
                    // Pass a native system timeout code (Reason 1 = Expired) if the card leaves on its own
                    root.executeDbusDismissalSignal(oldestCard.notifId, 1);
                    root.animateRemove(oldestCard.notifId);
                }
            }
        }
    }

    // Explicitly watch row updates to ensure smooth handoffs without breaking compiler properties
    Component.onCompleted: {
        notifModel.countChanged.connect(root.checkTopCardShift)
    }

    function checkTopCardShift() {
        if (notifModel.count > 0) {
            let oldestIndex = notifModel.count - 1;
            let oldestCard = notifModel.get(oldestIndex);

            if (oldestCard) {
                // If the top card's ID has changed, a brand new card has taken the top spot.
                if (oldestCard.notifId !== root.currentTopCardId) {
                    root.currentTopCardId = oldestCard.notifId;

                    // Only restart the queue countdown timer if the new top card is a standard message
                    if (!oldestCard.isUrgent) {
                        topCardQueueTimer.restart();
                    } else {
                        topCardQueueTimer.stop(); // Force-kill timer tracking for infinite urgent persistence
                    }
                }
            }
        } else {
            root.currentTopCardId = -1;
            topCardQueueTimer.stop();
        }
    }

    // Asynchronous Handshake: Fires a low-level D-Bus event to guarantee
    // chat programs register the notice as read/dismissed by the active desk session
    function executeDbusDismissalSignal(notifId, reasonCode) {
        try {
            dbusReadSignaler.running = false;
            dbusReadSignaler.command = [
                "dbus-send", "--session", "--type=signal",
                "/org/freedesktop/Notifications",
                "org.freedesktop.Notifications.NotificationClosed",
                "uint32:" + notifId, "uint32:" + reasonCode
            ];
            dbusReadSignaler.running = true;
        } catch (e) {
            console.log("D-Bus status tracking update failed:", e);
        }
    }

    // UNIFIED INTERNAL WORKER ROUTER: Executed both by keyboard shortcuts and direct screen clicks
    function executeActionOnTarget(targetId, actionId) {
        try {
            let nObj = null;
            let appNameString = "";

            // Find the active app metadata matching the clicked target row
            for (let i = 0; i < notifModel.count; ++i) {
                if (notifModel.get(i).notifId === targetId) {
                    appNameString = notifModel.get(i).appName;
                    // Mark that the user interacted with this card
                    notifModel.setProperty(i, "actioned", true);
                    break;
                }
            }

            // Extract the unmutated C++ raw pointer cache entry out of secure memory space
            for (let k = 0; k < root.rawNotifCache.length; ++k) {
                if (Number(root.rawNotifCache[k].id) === targetId) {
                    nObj = root.rawNotifCache[k];
                    break;
                }
            }

            // Fire application's deep-link actions natively off the preserved pointer
            if (nObj && nObj.actions && nObj.actions.count > 0) {
                let actionTriggered = false;
                for (let j = 0; j < nObj.actions.count; ++j) {
                    let act = nObj.actions.get(j);
                    if (act && act.identifier === actionId) {
                        act.trigger();
                        actionTriggered = true;
                        break;
                    }
                }

                if (!actionTriggered && actionId === "default") {
                    for (let m = 0; m < nObj.actions.count; m++) {
                        let defaultAct = nObj.actions.get(m);
                        if (defaultAct && (defaultAct.identifier === "default" || defaultAct.text === "View" || defaultAct.text === "")) {
                            defaultAct.trigger();
                            actionTriggered = true;
                            break;
                        }
                    }
                    if (!actionTriggered) {
                        let fallbackAct = nObj.actions.get(0);
                        if (fallbackAct) fallbackAct.trigger();
                    }
                }
            }

            // Forcefully tell the client application it was handled explicitly by user request (Reason Code 2)
            root.executeDbusDismissalSignal(targetId, 2);

            // Raise window container focus via Sway IPC
            if (appNameString && appNameString.length > 0) {
                let appClean = appNameString.toLowerCase().trim();
                if (appClean.includes("brave")) appClean = "brave-browser";
                else if (appClean.includes("matrix") || appClean.includes("element")) appClean = "element";
                else if (appClean.includes("vesktop")) appClean = "vesktop";

                swayActivator.running = false;
                swayActivator.command = [
                    "swaymsg",
                    `[app_id="(?i)^${appClean}$"] focus || [class="organize(?i)^${appClean}$"] focus || [title="(?i)${appClean}"] focus`
                ];
                swayActivator.running = true;
            }

            // Dismiss the notification item visually
            root.dismissNotification(targetId);

        } catch (err) {
            console.log("Core action router failed processing execution sequence:", err);
        }
    }

    // KEYBIND ROUTING ENGINE: Listens for external hotkey requests via "quickshell ipc call"
    IpcHandler {
        id: shellIpc
        target: "global_notif"

        function jumpToLatest() {
            if (notifModel.count === 0) return;
            let topIndex = notifModel.count - 1;
            root.executeActionOnTarget(notifModel.get(topIndex).notifId, "default");
        }

        function dismissLatest() {
            if (notifModel.count > 0) {
                let topIndex = notifModel.count - 1;
                let targetId = notifModel.get(topIndex).notifId;

                notifModel.setProperty(topIndex, "actioned", true);

                root.executeDbusDismissalSignal(targetId, 2);
                root.dismissNotification(targetId);
            }
        }
    }

    Component {
        id: removalTimerComponent
        Timer {
            property int targetId: -1
            interval: 240
            running: true
            repeat: false
            onTriggered: {
                for (let j = 0; j < notifModel.count; ++j) {
                    if (notifModel.get(j).notifId === targetId) {
                        notifModel.remove(j)
                        delete knownIds[targetId]
                        break
                    }
                }

                for (let k = 0; k < root.rawNotifCache.length; ++k) {
                    if (Number(root.rawNotifCache[k].id) === targetId) {
                        root.rawNotifCache.splice(k, 1);
                        break;
                    }
                }
                destroy()
            }
        }
    }

    function handleNotification(n) {
        if (knownIds[n.id]) {
            return
        }

        knownIds[n.id] = true;
        root.rawNotifCache.push(n);

        let iconSource = n.image ? n.image : (n.appIcon ? n.appIcon : "")
        let actionList = []

        if (n.actions && n.actions.count > 0) {
            for (let i = 0; i < n.actions.count; ++i) {
                let actObj = n.actions[i]
                if (actObj) {
                    actionList.push({
                        text: actObj.text || "View",
                        identifier: actObj.identifier || ""
                    })
                }
            }
        }

        let checkUrgent = (n.urgency === 2 || (n.hints && n.hints.urgency === 2));

        notifModel.insert(0, {
            notifId: Number(n.id),
                          summary: String(n.summary || ""),
                          body: String(n.body || ""),
                          appName: String(n.appName || ""),
                          icon: String(iconSource || ""),
                          actions: actionList,
                          removing: false,
                          freshArrival: true,
                          isUrgent: checkUrgent,
                          actioned: false
        })

        Qt.callLater(function() {
            if (notifModel.count > 0) {
                notifModel.setProperty(0, "freshArrival", false);
            }
        });

        root.checkTopCardShift();
    }

    function animateRemove(id) {
        for (let i = 0; i < notifModel.count; ++i) {
            let item = notifModel.get(i)

            if (item.notifId === id) {
                notifModel.setProperty(i, "removing", true)
                removalTimerComponent.createObject(root, { "targetId": id })
                return
            }
        }
    }

    function dismissNotification(id) {
        root.animateRemove(id)
    }

    PanelWindow {
        id: overlayWindow
        visible: notifModel.count > 0

        implicitWidth: 600
        implicitHeight: 600
        color: "transparent"

        screen: Quickshell.screens.find(s => s.name === "DP-2") || Quickshell.screens

        anchors {
            top: true
            right: true
        }

        margins {
            top: 24
            right: 24
        }

        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.namespace: "notification-overlay"
        WlrLayershell.keyboardFocus: WlrLayershell.None
        exclusionMode: PanelWindow.ExclusionMode.None

        Item {
            id: notificationContainer
            anchors.fill: parent

            Repeater {
                model: notifModel

                delegate: Rectangle {
                    id: card

                    required property int notifId
                    required property string summary
                    required property string body
                    required property string appName
                    required property string icon
                    required property var actions
                    required property bool removing
                    required property bool freshArrival
                    required property bool isUrgent
                    required property bool actioned
                    required property int index

                    // ###CARD SIZE HERE### (WIDTH AND HEIGHT)
                    // The width is locked to 480px, and height is hard-locked to exactly 140px.
                    // This completely removes dynamic sizing so all card nodes are identical.
                    width: 480
                    height: 140
                    radius: 18

                    color: Quickshell.env("STYLIX_BASE00") || "#1a1a1a"
                    border.width: 5

                    // FIXED STATE DETECTION: The border will reliably evaluate the user 'actioned' flag,
                    // remaining blue until intentionally ejected, where it instantly turns red.
                    border.color: (isUrgent || actioned)
                    ? (Quickshell.env("STYLIX_BASE08") || "#FF0000")
                    : (Quickshell.env("STYLIX_BASE03") || "#003399")

                    clip: true

                    property int deckPosition: (notifModel.count - 1) - index

                    y: deckPosition === 0 ? 100 : (100 + (deckPosition * -(height * 0.1)))
                    x: removing ? 650 : (freshArrival ? 600 : 0)

                    z: -deckPosition
                    scale: 1.0

                    Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        enabled: card.deckPosition === 0
                        onClicked: {
                            root.executeActionOnTarget(card.notifId, "default");
                        }
                    }

                    // FIXED CONTENT FLOW CONTAINER: Uses explicit top/bottom anchors instead of dynamic column layouts.
                    // This ensures button elements stay nested cleanly without shifting the card content upward or cropping borders out.
                    Item {
                        id: innerCanvasContainer
                        anchors.fill: parent
                        anchors.margins: 16

                        RowLayout {
                            id: contentRow
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 16

                            Rectangle {
                                id: iconContainer
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 100
                                radius: 50
                                color: Quickshell.env("STYLIX_BASE00") || "#1a1a1a"
                                border.width: 1
                                border.color: (card.isUrgent || card.actioned)
                                ? (Quickshell.env("STYLIX_BASE08") || "#FF0000")
                                : (Quickshell.env("STYLIX_BASE03") || "#003399")
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: card.icon
                                    fillMode: Image.PreserveAspectCrop
                                    visible: card.icon !== ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: card.icon === ""
                                    text: (card.appName.length > 0) ? card.appName.toUpperCase() : "?"
                                    font.pixelSize: 24
                                    font.bold: true
                                    color: Quickshell.env("STYLIX_BASE05") || "#F7F700"
                                }
                            }

                            ColumnLayout {
                                id: textContainer
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: card.summary
                                    color: Quickshell.env("STYLIX_BASE05") || "#F7F700"
                                    font.pixelSize: 24
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: card.body
                                    color: Quickshell.env("STYLIX_BASE05") || "#F7F700"
                                    font.pixelSize: 20
                                    wrapMode: Text.Wrap

                                    // ###CARD SIZE HERE### (TEXT LINES TRUNCATION)
                                    // Statically locked to 2 lines maximum so large notifications fit seamlessly inside the 140px template.
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    textFormat: Text.StyledText
                                }
                            }
                        }

                        // FIXED ACTIONS ANCHOR: Rendered overlay lines buttons cleanly along the bottom edge,
                        // completely independent of text body length to ensure borders are never cropped out.
                        RowLayout {
                            id: actionsLayout
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.leftMargin: 116
                            spacing: 12
                            visible: card.deckPosition === 0 && card.actions.length > 0

                            Repeater {
                                model: card.actions
                                delegate: Button {
                                    id: inlineButton
                                    required property var modelData

                                    visible: modelData.identifier !== "default" && modelData.text !== "View" && modelData.text !== ""
                                    text: modelData.text

                                    background: Rectangle {
                                        implicitWidth: Math.max(90, inlineButtonText.implicitWidth + 24)
                                        implicitHeight: 32
                                        radius: 8
                                        color: inlineButton.hovered ? (Quickshell.env("STYLIX_BASE02") || "#2d2d2d") : (Quickshell.env("STYLIX_BASE01") || "#0F0F0F")
                                        border.width: 2
                                        border.color: (card.isUrgent || card.actioned) ? (Quickshell.env("STYLIX_BASE08") || "#FF0000") : (Quickshell.env("STYLIX_BASE03") || "#003399")
                                    }

                                    contentItem: Text {
                                        id: inlineButtonText
                                        text: inlineButton.text
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: Quickshell.env("STYLIX_BASE05") || "#F7F700"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    onClicked: {
                                        root.executeActionOnTarget(card.notifId, modelData.identifier);
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
