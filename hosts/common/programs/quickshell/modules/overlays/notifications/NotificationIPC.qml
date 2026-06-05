import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: ipc
    visible: false

    required property Item rootItem
    property var notifModel: null
    property var serverInstance: null

    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================
    function getNewest() {
        if (!notifModel || notifModel.count === 0) return null;
        return notifModel.get(0);
    }

    function getOldest() {
        if (!notifModel || notifModel.count === 0) return null;
        return notifModel.get(notifModel.count - 1);
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
        let entry = getNewest();
        if (!entry) return;

        let visualCard = entry.cardRef || entry;
        dismiss(visualCard);
    }

    // ============================================================================
    // AUDIO
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
    // ACTIVATE INTERFACE (UNIVERSAL APPLICATION JUMP ENGINE)
    // ============================================================================
    function activate(card, summary, body, appName) {
        console.log("ACTIVATE ENTERED");
        if (!card) {
            console.log("Missing valid layout card references");
            return;
        }

        let summaryStr = summary || "";
        let bodyStr = body || "";
        let appNameStr = appName || "";

        // Resolve original notification object properties to scrape desktop hints
        let liveNotif = card.originalNotification || card.notification;
        let desktopHint = (liveNotif && liveNotif.hints) ? (liveNotif.hints["desktop-entry"] || "") : "";

        highlight(card);

        // 1. DYNAMIC GLOBAL WINDOW STEERING LAYER
        if (appNameStr.length > 0 || desktopHint.length > 0) {
            let primaryTarget = appNameStr || desktopHint;
            let secondaryTarget = desktopHint || appNameStr;
            let baseNameClean = primaryTarget.replace(/-electron|-client/gi, "");

            console.log("Dynamic target resolution rule processing for app: " + primaryTarget);

            // FIX: Loop through targets to guarantee 'focus parent; focus child' appends to EVERY option cleanly
            let targets = [primaryTarget, secondaryTarget, baseNameClean];
            let commandParts = [];

            for (let i = 0; i < targets.length; i++) {
                let tgt = targets[i];
                if (tgt && tgt.length > 0) {
                    commandParts.push('[app_id="' + tgt + '"] focus; focus parent; focus child');
                    commandParts.push('[class="' + tgt + '"] focus; focus parent; focus child');
                }
            }

            let swayCommand = commandParts.join("; ");
            console.log("Dispatching dynamic Sway selector command: swaymsg " + swayCommand);
            Quickshell.execDetached(["swaymsg", swayCommand]);
        }

        // 2. UNIFIED D-BUS INVOCATION HANDSHAKE FLOW
        if (liveNotif && liveNotif.actions && liveNotif.actions.length > 0) {
            let targetAction = null;

            for (let i = 0; i < liveNotif.actions.length; i++) {
                if (liveNotif.actions[i].identifier === "default") {
                    targetAction = liveNotif.actions[i];
                    break;
                }
            }

            if (!targetAction && liveNotif.actions.length > 0) {
                let firstActionIndex = 0;
                targetAction = liveNotif.actions[firstActionIndex];
            }

            if (targetAction && typeof targetAction.invoke === "function") {
                console.log("SUCCESS: Scheduling native C++ action loop invocation over D-Bus -> " + targetAction.identifier);

                let dbusTimer = Qt.createQmlObject(
                    'import QtQuick; Timer { interval: 120; repeat: false; }',
                    ipc
                );
                dbusTimer.triggered.connect(function() {
                    targetAction.invoke();
                    dbusTimer.destroy();
                });
                dbusTimer.start();
                return;
            }
        }

        console.log("Warning: Window focus complete, but no valid target action was available to execute.");
    }

    function jumpToLatestInternal() {
        console.log("jumpToLatest called");

        let entry = getNewest();
        if (!entry) {
            console.log("No active notifications tracked inside ListModel memory profile.");
            return;
        }

        let visualCard = entry.cardRef;
        let textSummary = entry.summary;
        let textBody = entry.body;
        let textAppName = entry.appName;

        if (!visualCard) {
            console.log("Unable to trace active visual pointer component item target");
            return;
        }

        ipc.activate(visualCard, textSummary, textBody, textAppName);

        let delayedDismissTimer = Qt.createQmlObject(
            'import QtQuick; Timer { interval: 400; repeat: false; }',
            ipc
        );
        delayedDismissTimer.triggered.connect(function() {
            console.log("Executing delayed notification card visual clearance routine...");
            ipc.dismiss(visualCard);
            delayedDismissTimer.destroy();
        });
        delayedDismissTimer.start();
    }

    // ============================================================================
    // IPC HANDLER REGISTRATION LAYER
    // ============================================================================
    IpcHandler {
        target: "global_notif"

        function dismissLatest(): void {
            ipc.dismissLatest();
        }

        function jumpToLatest(): void {
            ipc.jumpToLatestInternal();
        }
    }
}
