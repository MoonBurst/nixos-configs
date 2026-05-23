import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: ipc
    visible: false

    required property Item rootItem
    // =========================
    // HELPERS
    // =========================
    function getNewest() {
        for (let i = 0; i < rootItem.activeNotifications.length; i++) {
            let entry = rootItem.activeNotifications[i];
            if (
                entry
                && entry.card
                && entry.notification
            ) {
                return entry;
            }
        }
        return null;
    }

    function getOldest() {
        for (
            let i = rootItem.activeNotifications.length - 1;
        i >= 0;
        i--
        ) {
            let entry = rootItem.activeNotifications[i];
            if (
                entry
                && entry.card
                && entry.notification
            ) {
                return entry;
            }
        }
        return null;
    }


    // =========================
    // VISUAL FEEDBACK
    // =========================
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


    // =========================
    // DISMISS
    // =========================
    function dismiss(card) {
        if (!card)
            return;
        card.isManualDismiss = true;
        rootItem.closeNotificationTrack(card);
        card.startExitAnimation();
    }


    function dismissLatest() {
        let entry = getNewest();
        if (!entry)
            return;
        dismiss(entry.card);
    }


    // =========================
    // ACTIVATE
    // =========================
    function activate(card, notification) {
        console.log("ACTIVATE ENTERED");
        if (!card || !notification) {
            console.log(
                "Missing card or notification"
            );
            return;
        }
        console.log(
            "Activating notification:",
            notification.summary
        );
        console.log(
            "Application:",
            notification.appName
        );
        highlight(card);
        // Attempt invoke()
        if (
            notification.actions
            && notification.actions.length > 0
        ) {
            let action = notification.actions[0];
            console.log(
                "Attempting invoke:",
                action.text
            );
            if (action && action.invoke) {
                action.invoke();
                return;
            }
        }
        // Desktop entry fallback
        let desktop =
        notification.hints
        ? notification.hints["desktop-entry"]
        : null;
        console.log(
            "Desktop entry:",
            desktop
        );


        // =========================
        // VESKTOP
        // =========================
        if (desktop === "vesktop") {
            console.log(
                "Focusing Vesktop"
            );
            Quickshell.execDetached([
                "swaymsg",
                "[app_id=\"vesktop\"] focus"
            ]);
            return;
        }



        // =========================
        // HORIZON
        // =========================
        if (desktop === "horizon-electron") {
            console.log(
                "Focusing Horizon"
            );
            Quickshell.execDetached([
                "swaymsg",
                "[app_id=\"horizon-electron\"] focus"
            ]);
            return;
        }
        console.log(
            "No activation route available."
        );
    }

    function jumpToLatest() {
        console.log(
            "jumpToLatest called"
        );
        let entry = getNewest();
        if (!entry)
            return;
        activate(
            entry.card,
            entry.notification
        );
    }

    // =========================
    // IPC
    // =========================
    IpcHandler {
        target: "global_notif"
        function dismissLatest(): void {
            ipc.dismissLatest();
        }
        function jumpToLatest(): void {
            ipc.jumpToLatest();
        }
    }
}
