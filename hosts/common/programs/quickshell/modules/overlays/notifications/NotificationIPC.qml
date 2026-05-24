import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: ipc
    visible: false

    required property Item rootItem

    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================
    function getNewest() {
        if (rootItem.activeNotifications.length === 0) return null;
        // Index 0 holds the most recently received entry
        let entry = rootItem.activeNotifications[0];
        if (entry && entry.card && entry.notification) {
            return entry;
        }
        return null;
    }

    function getOldest() {
        if (rootItem.activeNotifications.length === 0) return null;
        // FIXED: The last index explicitly holds the oldest card (the forefront card)
        let entry = rootItem.activeNotifications[rootItem.activeNotifications.length - 1];
        if (entry && entry.card && entry.notification) {
            return entry;
        }
        return null;
    }

    // ============================================================================
    // VISUAL FEEDBACK
    // ============================================================================
    function highlight(card) {
        if (!card)
            return;
        card.isManualDismiss = true;
        let timer = Qt.createQmlObject(
            'import QtQuick; Timer { interval: 350; repeat: false; }',
            card
        );
        timer.triggered.connect(function () {
            card.isManualDismiss = false;
            timer.destroy();
        });
        timer.start();
    }

    // ============================================================================
    // DISMISS ACTIONS
    // ============================================================================
    function dismiss(card) {
        if (!card)
            return;
        card.isManualDismiss = true;
        rootItem.closeNotificationTrack(card);

        // FIXED: Checks if card is wrapped inside a window container before animating out
        if (card.startExitAnimation) {
            card.startExitAnimation();
        } else if (card.innerCard) {
            card.innerCard.startExitAnimation();
        }
    }


    /*
     * FIXED: Changed away from dismissing index 0.
     * Always targets and dismisses the oldest card at the forefront of your stack.
     */
    function dismissLatest() {
        let entry = getOldest();
        if (!entry)
            return;
        dismiss(entry.card);
    }

    // ============================================================================
    // DYNAMIC AUDIO ROUTER ENGINE
    // ============================================================================
    function playNotificationSound(notification) {
        let summaryLower = (notification.summary || "").toLowerCase();
        let bodyLower = (notification.body || "").toLowerCase();
        let baseResource = shell.projectRootPath + "/resources/";
        let trackPath = "";

        if (summaryLower.includes("luster dawn") || bodyLower.includes("luster dawn")) {
            trackPath = baseResource + "luster_dawn/luster_dawn.flac";
        } else if (summaryLower.includes("olivia") || bodyLower.includes("olivia")) {
            trackPath = baseResource + "olivia/olivia.flac";
        } else if (summaryLower.includes("cageheart") || bodyLower.includes("cageheart")) {
            trackPath = baseResource + "cageheart/cageheart.flac";
        } else if (summaryLower.includes("solar sonata") || bodyLower.includes("solar_sonata")) {
            trackPath = baseResource + "solar_sonata/solar_sonata.flac";
        }

        if (trackPath.length > 0) {
            console.log("Playing notification audio cue:", trackPath);
            Quickshell.execDetached(["mpv", "--no-video", "--volume=80", trackPath]);
        }
    }

    // ============================================================================
    // ACTIVATE INTERFACE
    // ============================================================================
    function activate(card, notification) {
        console.log("ACTIVATE ENTERED");
        if (!card || !notification) {
            console.log("Missing card or notification");
            return;
        }
        console.log("Activating notification:", notification.summary);
        console.log("Application:", notification.appName);

        highlight(card);

        if (notification.actions && notification.actions.length > 0) {
            let action = notification.actions[0];
            console.log("Attempting invoke:", action.text);
            if (action && action.invoke) {
                action.invoke();
                return;
            }
        }

        let desktop = notification.hints ? notification.hints["desktop-entry"] : null;
        console.log("Desktop entry:", desktop);

        if (desktop === "vesktop") {
            console.log("Focusing Vesktop");
            Quickshell.execDetached(["swaymsg", "[app_id=\"vesktop\"] focus"]);
            return;
        }

        if (desktop === "horizon-electron") {
            console.log("Focusing Horizon");
            Quickshell.execDetached(["swaymsg", "[app_id=\"horizon-electron\"] focus"]);
            return;
        }
        console.log("No activation route available.");
    }

    /*
     * FIXED: Rewired to activate the oldest forefront notification card
     * immediately upon receiving the shortcut trigger command.
     */
    function jumpToLatest() {
        console.log("jumpToLatest called");
        let entry = getOldest();
        if (!entry)
            return;
        activate(entry.card, entry.notification);
    }

    // ============================================================================
    // IPC HANDLER REGISTRATION LAYER
    // ============================================================================
    IpcHandler {
        target: "global_notif"

        function dismissLatest() {
            ipc.dismissLatest();
        }

        function jumpToLatest() {
            ipc.jumpToLatest();
        }
    }
}
