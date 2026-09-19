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
    // AUDIO & TTS
    // ============================================================================
    function playNotificationSound(notification) {
        if (!notification) return;

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

    readonly property var genericSpeechAppNames: ["notify-send", "notification", "notify"]

    readonly property var chatAppNames: [
        "vesktop", "discord", "element", "cinny", "matrix",
        "telegram", "signal", "slack", "fluffychat", "nheko",
        "thunderbird", "gmail", "kmail", "mail"
    ]

    readonly property var speechKeywordFilter: [
        "Apogee",
        "Cageheart",
        "Luster Dawn",
        "Solar Sonata",
        "Vikhlop",
        "Gadren",
        "Parker",
        "urgent"
    ]

    function shouldSpeak(appName, summary, body) {
        if (ipc.speechKeywordFilter.length === 0) return true;

        let haystack = (appName + " " + summary + " " + body).toLowerCase();
        for (let i = 0; i < ipc.speechKeywordFilter.length; i++) {
            if (haystack.includes(ipc.speechKeywordFilter[i].toLowerCase())) {
                return true;
            }
        }
        return false;
    }

    function isClipboardOrMicNotification(appName, summary, body) {
        let appNameLower = (appName || "").toLowerCase();
        let summaryLower = (summary || "").toLowerCase();
        let bodyLower = (body || "").toLowerCase();

        let isMicNotif = appNameLower.includes("microphone") || appNameLower.includes("mic") ||
        summaryLower.includes("microphone") || summaryLower.includes("mic") ||
        bodyLower.includes("microphone") || bodyLower.includes("mic");

        let isClipboardNotif = appNameLower.includes("greenclip") || appNameLower.includes("copyq") ||
        appNameLower.includes("clipboard") || appNameLower.includes("clip") ||
        summaryLower.includes("copied to clipboard") || bodyLower.includes("copied to clipboard") ||
        summaryLower.includes("clipboard manager");

        return isMicNotif || isClipboardNotif;
    }

    // Strips room/server/channel names from usernames
    function extractSenderName(rawSummary) {
        if (!rawSummary) return "";
        let sender = rawSummary.trim();

        // 1. Remove parenthesized channels/servers: "User (#general)" -> "User"
        sender = sender.replace(/\s*\([^)]*\)/g, "");

        // 2. Remove bracketed tags: "User [#general]" -> "User"
        sender = sender.replace(/\s*\[[^\]]*\]/g, "");

        // 3. Remove "in RoomName": "User in General Chat" -> "User"
        sender = sender.replace(/\s+in\s+.*$/i, "");

        // 4. Remove Channel prefix if formatted like "#general > User" or "Server > User"
        if (sender.indexOf(">") !== -1) {
            let parts = sender.split(">");
            sender = parts[parts.length - 1];
        }

        // 5. Remove Channel prefix if formatted like "#channel: User"
        if (sender.indexOf(":") !== -1 && sender.startsWith("#")) {
            let parts = sender.split(":");
            sender = parts[parts.length - 1];
        }

        return sender.trim();
    }

    readonly property int dedupWindowMs: 3000
    property string lastSpokenKey: ""
    property double lastSpokenTime: 0

    readonly property int maxSpeechLength: 75

    readonly property var urlRegex: /(https?:\/\/[^\s<]+)/gi

    function cleanSpeechText(text) {
        let cleaned = text.replace(/<[^>]*>/g, "");
        cleaned = cleaned.replace(ipc.urlRegex, "Sent a link");

        cleaned = cleaned.replace(/(\*\*|__)(.*?)\1/g, "$2");
        cleaned = cleaned.replace(/(\*|_)(.*?)\1/g, "$2");
        cleaned = cleaned.replace(/~~(.*?)~~/g, "$1");
        cleaned = cleaned.replace(/`([^`]+)`/g, "$1");
        cleaned = cleaned.replace(/^#{1,6}\s*/gm, "");

        cleaned = cleaned.replace(/\s+/g, " ").trim();

        if (cleaned.length > ipc.maxSpeechLength) {
            cleaned = cleaned.substring(0, ipc.maxSpeechLength).trim() + "...";
        }

        return cleaned;
    }

    function speakNotification(notification) {
        if (!notification) return;

        let appName = (notification.appName || notification.desktopEntry || "").toLowerCase();
        let rawSummary = notification.summary || "";
        let body = notification.body || "";

        if (ipc.isClipboardOrMicNotification(appName, rawSummary, body)) {
            return;
        }

        if (!ipc.shouldSpeak(appName, rawSummary, body)) {
            return;
        }

        let dedupKey = appName + "|" + rawSummary + "|" + body;
        let now = Date.now();
        if (dedupKey === ipc.lastSpokenKey && (now - ipc.lastSpokenTime) < ipc.dedupWindowMs) {
            return;
        }

        let speechText = "";
        let isChat = false;

        for (let i = 0; i < ipc.chatAppNames.length; i++) {
            if (appName.includes(ipc.chatAppNames[i])) {
                isChat = true;
                break;
            }
        }

        // Clean sender name (stripping room/channel tags)
        let senderName = ipc.extractSenderName(rawSummary);

        if (isChat && senderName.length > 0 && body.length > 0) {
            speechText = "Message from " + senderName + ": " + body;
        } else if (isChat && senderName.length > 0) {
            speechText = "Message from " + senderName;
        } else {
            let appPrefix = ipc.genericSpeechAppNames.includes(appName) ? "" : (appName ? notification.appName + ": " : "");
            speechText = appPrefix + rawSummary + (body ? ". " + body : "");
        }

        speechText = ipc.cleanSpeechText(speechText);

        if (speechText.length > 0) {
            ipc.lastSpokenKey = dedupKey;
            ipc.lastSpokenTime = now;
            Quickshell.execDetached(["sage-tts", speechText]);
        }
    }

    // ============================================================================
    // ACTIVATE INTERFACE (UNIVERSAL APPLICATION JUMP ENGINE)
    // ============================================================================
    function activate(card, summary, body, appName, directNotificationObject) {
        if (shell.debug) console.log("ACTIVATE ENTERED");

        let summaryStr = summary || "";
        let bodyStr = body || "";
        let appNameStr = appName || "";

        let liveNotif = null;
        if (card) {
            liveNotif = card.originalNotification || card.notification;
            highlight(card);
        } else if (directNotificationObject) {
            liveNotif = directNotificationObject;
        }

        let desktopHint = (liveNotif && liveNotif.hints) ? (liveNotif.hints["desktop-entry"] || "") : "";

        if (appNameStr.length > 0 || desktopHint.length > 0) {
            let primaryTarget = appNameStr || desktopHint;
            let secondaryTarget = desktopHint || appNameStr;
            let baseNameClean = primaryTarget.replace(/-electron/g, "").replace(/-desktop/g, "").replace("vesktop", "discord");

            if (shell.debug) console.log("Dynamic target resolution rule processing for app: " + primaryTarget);

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
