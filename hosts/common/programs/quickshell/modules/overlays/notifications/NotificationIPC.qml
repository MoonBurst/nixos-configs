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

    function getNewest() {
        if (!notifModel || notifModel.count === 0) return null;
        return notifModel.get(notifModel.count - 1);
    }

    function highlight(card) {
        if (!card) return;
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

    function dismiss(card) {
        if (!card) return;
        card.isManualDismiss = true;

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

    // Audio cue playback
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
            Quickshell.execDetached(["mpv", "--no-video", "--volume=80", trackPath]);
        }
    }

    // Key user whitelist
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

    // Resolves ONLY the person's name (strips room/channel/server tags)
    function resolveSenderName(summary, body) {
        let textToSearch = (summary + " " + body).toLowerCase();

        // 1. Direct match against known key user profiles
        for (let i = 0; i < ipc.speechKeywordFilter.length; i++) {
            let key = ipc.speechKeywordFilter[i];
            if (key.toLowerCase() === "urgent") continue;
            if (textToSearch.includes(key.toLowerCase())) {
                return key; // Returns clean proper name ("Solar Sonata", "Luster Dawn", etc.)
            }
        }

        // 2. If Discord puts "Sender: message" in the body
        if (body) {
            let colonIdx = body.indexOf(":");
            if (colonIdx > 0 && colonIdx < 30) {
                let candidate = body.substring(0, colonIdx).trim();
                if (!candidate.includes("http") && !candidate.includes("/")) {
                    return candidate;
                }
            }
        }

        // 3. Fallback: Strip room/server parentheses from summary
        let name = summary ? summary.trim() : "";
        name = name.replace(/\s*\([^)]*\)/g, ""); // Remove (ServerName) or (#channel)
        name = name.replace(/\s*\[[^\]]*\]/g, ""); // Remove [tags]
        name = name.replace(/\s+in\s+.*$/i, "");   // Remove "in ServerName"
        if (name.indexOf(">") !== -1) {
            let parts = name.split(">");
            name = parts[parts.length - 1];
        }
        if (name.indexOf(":") !== -1) {
            let parts = name.split(":");
            name = parts[parts.length - 1];
        }
        return name.trim();
    }

    readonly property int dedupWindowMs: 3000
    property string lastSpokenKey: ""
    property double lastSpokenTime: 0

    function speakNotification(notification) {
        if (!notification) return;

        let appName = (notification.appName || notification.desktopEntry || "").toLowerCase();
        let rawSummary = notification.summary || "";
        let body = (notification.body || "").trim();

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

        let name = ipc.resolveSenderName(rawSummary, body);
        let speechText = "";

        if (name.length > 0) {
            // Strictly says "Message from <Name>" (no message body, no room name)
            speechText = "Message from " + name;
        } else if (rawSummary.toLowerCase().includes("urgent") || body.toLowerCase().includes("urgent")) {
            speechText = "Urgent notification";
        } else {
            speechText = "New notification";
        }

        if (speechText.length > 0) {
            ipc.lastSpokenKey = dedupKey;
            ipc.lastSpokenTime = now;
            Quickshell.execDetached(["sage-tts", speechText]);
        }
    }

    function activate(card, summary, body, appName, directNotificationObject) {
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
                targetAction = liveNotif.actions[0];
            }

            if (targetAction && typeof targetAction.invoke === "function") {
                let dbusTimer = Qt.createQmlObject(
                    'import QtQuick; Timer { interval: 120; repeat: false; }',
                    ipc
                );
                dbusTimer.triggered.connect(function() {
                    try {
                        if (targetAction && typeof targetAction.invoke === "function") {
                            targetAction.invoke();
                        }
                    } catch (e) {}
                    dbusTimer.destroy();
                });
                dbusTimer.start();
                return;
            }
        }
    }

    function jumpToLatestInternal() {
        let entry = getNewest();
        if (!entry) return;

        let visualCard = entry.cardRef;
        let textSummary = entry.summary;
        let textBody = entry.body;
        let textAppName = entry.appName;

        if (!visualCard) return;

        ipc.activate(visualCard, textSummary, textBody, textAppName);

        let delayedDismissTimer = Qt.createQmlObject(
            'import QtQuick; Timer { interval: 400; repeat: false; }',
            ipc
        );
        delayedDismissTimer.triggered.connect(function() {
            ipc.dismiss(visualCard);
            delayedDismissTimer.destroy();
        });
        delayedDismissTimer.start();
    }

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
