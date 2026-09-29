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

    Timer {
        id: unhighlightTimer
        interval: 350
        repeat: false
        property var targetCard: null
        onTriggered: {
            if (targetCard) targetCard.isManualDismiss = false;
        }
    }

    Timer {
        id: dismissDelayTimer
        interval: 400
        repeat: false
        property var targetCard: null
        onTriggered: {
            if (targetCard) ipc.dismiss(targetCard);
        }
    }

    Timer {
        id: actionInvokeTimer
        interval: 120
        repeat: false
        property var targetAction: null
        onTriggered: {
            try {
                if (targetAction && typeof targetAction.invoke === "function") {
                    targetAction.invoke();
                }
            } catch (e) {}
        }
    }

    function getNewest() {
        if (!notifModel || notifModel.count === 0) return null;
        return notifModel.get(notifModel.count - 1);
    }

    function highlight(card) {
        if (!card) return;
        card.isManualDismiss = true;
        unhighlightTimer.targetCard = card;
        unhighlightTimer.restart();
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
            Quickshell.execDetached(["pw-play", trackPath]);
        }
    }

    readonly property var speechKeywordFilter: [
        "Apogee", "Cageheart", "Luster Dawn", "Solar Sonata", "Vikhlop", "Gadren", "Parker", "urgent"
    ]

    function shouldSpeak(appName, summary, body) {
        if (ipc.speechKeywordFilter.length === 0) return true;
        let haystack = (appName + " " + summary + " " + body).toLowerCase();
        for (let i = 0; i < ipc.speechKeywordFilter.length; i++) {
            if (haystack.includes(ipc.speechKeywordFilter[i].toLowerCase())) return true;
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

    function resolveSenderName(summary, body) {
        let textToSearch = (summary + " " + body).toLowerCase();
        for (let i = 0; i < ipc.speechKeywordFilter.length; i++) {
            let key = ipc.speechKeywordFilter[i];
            if (key.toLowerCase() === "urgent") continue;
            if (textToSearch.includes(key.toLowerCase())) return key;
        }
        if (body) {
            let colonIdx = body.indexOf(":");
            if (colonIdx > 0 && colonIdx < 30) {
                let candidate = body.substring(0, colonIdx).trim();
                if (!candidate.includes("http") && !candidate.includes("/")) return candidate;
            }
        }
        let name = summary ? summary.trim() : "";
        name = name.replace(/\s*\([^)]*\)/g, "");
        name = name.replace(/\s*\[[^\]]*\]/g, "");
        name = name.replace(/\s+in\s+.*$/i, "");
        if (name.indexOf(">") !== -1) name = name.split(">").pop();
        if (name.indexOf(":") !== -1) name = name.split(":").pop();
        return name.trim();
    }

    readonly property int dedupWindowMs: 3000
    property string lastSpokenKey: ""
    property double lastSpokenTime: 0

    function speakNotification(notification) {
        if (!notification) return;
        if (typeof shell !== 'undefined' && shell && shell.settingsManager && !shell.settingsManager.enableTts) return;

        let appName = (notification.appName || notification.desktopEntry || "").toLowerCase();
        let rawSummary = notification.summary || "";
        let body = (notification.body || "").trim();

        if (ipc.isClipboardOrMicNotification(appName, rawSummary, body)) return;
        if (!ipc.shouldSpeak(appName, rawSummary, body)) return;

        let dedupKey = appName + "|" + rawSummary + "|" + body;
        let now = Date.now();
        if (dedupKey === ipc.lastSpokenKey && (now - ipc.lastSpokenTime) < ipc.dedupWindowMs) return;

        let name = ipc.resolveSenderName(rawSummary, body);
        let speechText = name.length > 0 ? ("Message from " + name)
            : (rawSummary.toLowerCase().includes("urgent") || body.toLowerCase().includes("urgent") ? "Urgent notification" : "New notification");

        ipc.lastSpokenKey = dedupKey;
        ipc.lastSpokenTime = now;
        Quickshell.execDetached(["sage-tts", speechText]);
    }

    // SANITIZATION HELPER: Prevents arbitrary Sway command injection from untrusted notification D-Bus metadata
    function sanitizeForSway(str) {
        if (!str) return "";
        return str.replace(/[^a-zA-Z0-9_\-\.]/g, "");
    }

    function activate(card, summary, body, appName, directNotificationObject) {
        let liveNotif = card ? (card.originalNotification || card.notification) : directNotificationObject;
        if (card) highlight(card);

        let desktopHint = (liveNotif && liveNotif.hints) ? (liveNotif.hints["desktop-entry"] || "") : "";
        let rawTarget = appName || desktopHint || "";
        let cleanBase = rawTarget.replace(/-electron/g, "").replace(/-desktop/g, "").replace("vesktop", "discord");

        let safe1 = sanitizeForSway(rawTarget);
        let safe2 = sanitizeForSway(cleanBase);

        if (safe1.length > 0 || safe2.length > 0) {
            let criteria = [];
            if (safe1.length > 0) criteria.push('[app_id="' + safe1 + '"] focus', '[class="' + safe1 + '"] focus');
            if (safe2.length > 0 && safe2 !== safe1) criteria.push('[app_id="' + safe2 + '"] focus', '[class="' + safe2 + '"] focus');
            Quickshell.execDetached(["swaymsg", criteria.join(", ")]);
        }

        if (liveNotif && liveNotif.actions && liveNotif.actions.length > 0) {
            let targetAction = liveNotif.actions.find(a => a.identifier === "default") || liveNotif.actions[0];
            if (targetAction && typeof targetAction.invoke === "function") {
                actionInvokeTimer.targetAction = targetAction;
                actionInvokeTimer.restart();
            }
        }
    }

    function jumpToLatestInternal() {
        let entry = getNewest();
        if (!entry || !entry.cardRef) return;
        ipc.activate(entry.cardRef, entry.summary, entry.body, entry.appName);
        dismissDelayTimer.targetCard = entry.cardRef;
        dismissDelayTimer.restart();
    }

    IpcHandler {
        target: "global_notif"
        function dismissLatest(): void { ipc.dismissLatest(); }
        function jumpToLatest(): void { ipc.jumpToLatestInternal(); }
        function toggleHistory(): void { rootItem.showHistoryMode = !rootItem.showHistoryMode; }
    }
}
