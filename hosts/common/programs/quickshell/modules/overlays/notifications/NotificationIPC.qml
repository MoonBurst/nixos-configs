// modules/overlays/notifications/NotificationIPC.qml
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
    // HELPER FUNCTIONS (Optimal models/bindings extraction)
    // ============================================================================
    function getNewest() {
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

        if (card.startExitAnimation) {
            card.startExitAnimation();
        } else if (card.innerCard) {
            card.innerCard.startExitAnimation();
        }
    }

    function dismissLatest() {
        if (shell.debug) console.log("[IPC DEBUG] dismissLatest triggered. Total active cards in queue:", notifModel.count);

        let entry = getNewest();
        if (!entry) {
            if (shell.debug) console.log("[IPC DEBUG] No active notification cards found to dismiss.");
            return;
        }

        if (shell.debug) console.log("[IPC DEBUG] Manual dismiss targeting oldest (front-most) card -> Index:", (notifModel.count - 1), "Summary:", entry.summary);
        let visualCard = entry.cardRef || entry;
        dismiss(visualCard);
    }

    // ============================================================================
    // AUDIO
    // ============================================================================
    function playNotificationSound(notification) {
        if (!notification) return;

        // Optimized string matching via local cached lookups
        // FIXED: Uses native Quickshell.shellDir to prevent "undefined/resources/" loading warnings
        let summaryLower = (notification.summary || "").toLowerCase();
        let bodyLower = (notification.body || "").toLowerCase();
        let baseResource = Quickshell.shellDir + "/resources/";
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
            if (shell.debug) console.log("Playing notification audio cue:", trackPath);
            Quickshell.execDetached(["mpv", "--no-video", "--volume=80", trackPath]);
        }
    }

    // ============================================================================
    // ACTIVATE INTERFACE (UNIVERSAL APPLICATION JUMP ENGINE)
    // ============================================================================
    // FIXED: Added optional directNotificationObject parameter to handle historical activations natively
    function activate(card, summary, body, appName, directNotificationObject) {
        if (shell.debug) console.log("ACTIVATE ENTERED");

        let summaryStr = summary || "";
        let bodyStr = body || "";
        let appNameStr = appName || "";

        // Resolve original notification object properties to scrape desktop hints
        let liveNotif = null;
        if (card) {
            liveNotif = card.originalNotification || card.notification;
            highlight(card);
        } else if (directNotificationObject) {
            liveNotif = directNotificationObject;
        }

        let desktopHint = (liveNotif && liveNotif.hints) ? (liveNotif.hints["desktop-entry"] || "") : "";

        // 1. DYNAMIC GLOBAL WINDOW STEERING LAYER
        if (appNameStr.length > 0 || desktopHint.length > 0) {
            let primaryTarget = appNameStr || desktopHint;
            let secondaryTarget = desktopHint || appNameStr;
            let baseNameClean = primaryTarget.replace(/-electron/g, "").replace(/-desktop/g, "").replace("vesktop", "discord"); // Fallbacks for common apps

            if (shell.debug) console.log("Dynamic target resolution rule processing for app: " + primaryTarget);

            // Loop through targets to guarantee 'focus parent; focus child' appends to EVERY option cleanly
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
            if (shell.debug) console.log("Dispatching dynamic Sway selector command: swaymsg " + swayCommand);
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
                if (shell.debug) console.log("SUCCESS: Scheduling native C++ action loop invocation over D-Bus -> " + targetAction.identifier);

                let dbusTimer = Qt.createQmlObject(
                    'import QtQuick; Timer { interval: 120; repeat: false; }',
                    ipc
                );
                dbusTimer.triggered.connect(function() {
                    // Safe execution wrap: Prevents TypeErrors if the C++ object gets destroyed during the 120ms focus delay
                    try {
                        if (targetAction && typeof targetAction.invoke === "function") {
                            targetAction.invoke();
                        }
                    } catch (e) {
                        if (shell.debug) console.log("[IPC DEBUG] Delayed D-Bus invocation skipped: targetAction became invalid: " + e);
                    }
                    dbusTimer.destroy();
                });
                dbusTimer.start();
                return;
            }
        }

        if (shell.debug) console.log("Warning: Window focus complete, but no valid target action was available to execute.");
    }

    function jumpToLatestInternal() {
        if (shell.debug) console.log("jumpToLatest called");

        let entry = getNewest();
        if (!entry) {
            if (shell.debug) console.log("No active notifications tracked inside ListModel memory profile.");
            return;
        }

        let visualCard = entry.cardRef;
        let textSummary = entry.summary;
        let textBody = entry.body;
        let textAppName = entry.appName;

        if (!visualCard) {
            if (shell.debug) console.log("Unable to trace active visual pointer component item target");
            return;
        }

        ipc.activate(visualCard, textSummary, textBody, textAppName);

        let delayedDismissTimer = Qt.createQmlObject(
            'import QtQuick; Timer { interval: 400; repeat: false; }',
            ipc
        );
        delayedDismissTimer.triggered.connect(function() {
            if (shell.debug) console.log("Executing delayed notification card visual clearance routine...");
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

        function toggleHistory(): void {
            rootItem.showHistoryMode = !rootItem.showHistoryMode;
        }
    }
}
