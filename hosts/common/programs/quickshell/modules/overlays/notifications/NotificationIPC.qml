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
        let entry = rootItem.activeNotifications[0];
        if (entry && entry.card) return entry;
        return null;
    }

    function getOldest() {
        if (rootItem.activeNotifications.length === 0) return null;
        let entry = rootItem.activeNotifications[rootItem.activeNotifications.length - 1];
        if (entry && entry.card) return entry;
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

        if (card.startExitAnimation) {
            card.startExitAnimation();
        } else if (card.innerCard) {
            card.innerCard.startExitAnimation();
        }
    }

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
        if (!notification) return;
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
        if (!card) {
            console.log("Missing valid layout card references");
            return;
        }

        let summaryStr = notification ? (notification.summary || "") : "";
        let bodyStr = notification ? (notification.body || "") : "";
        let appNameStr = notification ? (notification.appName || "") : "";
        let desktopHint = (notification && notification.hints) ? (notification.hints["desktop-entry"] || "") : "";

        if (summaryStr === "" && rootItem && rootItem.activeNotifications) {
            let cachedEntry = rootItem.activeNotifications.find(entry => entry.card === card);
            if (cachedEntry) {
                summaryStr = cachedEntry.summary || "";
                bodyStr = cachedEntry.body || "";
                appNameStr = cachedEntry.appName || "";
                desktopHint = cachedEntry.desktopEntry || "";
            }
        }

        console.log("Activating notification summary string:", summaryStr);
        console.log("Application owner identifier:", appNameStr);

        highlight(card);

        /*
         * FIXED: Restored index brackets array lookup validation rules.
         * Extracts action parameters cleanly without breaking the structural C++ mapping layer bindings.
         */
        if (notification && notification.actions && notification.actions.length > 0) {
            let action = notification.actions[0];
            if (action && action.invoke) {
                console.log("Invoking native action:", action.text);
                action.invoke();
            }
        }

        let desktop = notification && notification.hints ? notification.hints["desktop-entry"] : desktopHint;
        let fullTextLower = (summaryStr + " " + bodyStr + " " + appNameStr + " " + (desktop || "")).toLowerCase();
        console.log("Normalized full scanning token string text payload:", fullTextLower);

        if (fullTextLower.includes("vesktop") || fullTextLower.includes("discord") || fullTextLower.includes("#")) {
            console.log("Routing focus straight to Vesktop window canvas via swaymsg");
            Quickshell.execDetached(["swaymsg", "[app_id=\"vesktop\"] focus"]);
            return;
        }

        if (fullTextLower.includes("horizon-electron") || fullTextLower.includes("horizon")) {
            console.log("Routing focus straight to Horizon workspace container via swaymsg");
            Quickshell.execDetached(["swaymsg", "[app_id=\"horizon-electron\"] focus"]);
            return;
        }

        console.log("No activation route available or action already handled focus.");
    }

    function jumpToLatest() {
        console.log("jumpToLatest called");
        let entry = getOldest();
        if (!entry || !entry.card) return;

        ipc.activate(entry.card, entry.card.notification);
        ipc.dismiss(entry.card);
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
