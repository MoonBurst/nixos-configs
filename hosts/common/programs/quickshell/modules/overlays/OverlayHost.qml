import QtQuick
import Quickshell
import Quickshell.Io

import "./launcher" as AppLauncherModule
import "./calc" as CalcModule
import "./clipboard" as ClipboardModule
import "./dictionary" as DictionaryModule
import "./unicode" as UnicodeModule
import "./notes" as NotesModule
import "./pass" as PassModule
import "./power" as PowerModule
import "./todo" as TodoModule
import "./gemini" as GeminiModule
import "./settings" as SettingsWindowModule
import "./email" as EmailModule
import "./websearch" as WebSearchModule
import "./notifications" as Notifications
import "./magnify" as Magnify
import "./rng" as RNG
import "./amogus" as AmogusModule

Item {
    id: overlayHost

    required property var shell

    property alias appLauncherWindow: appLauncherWindow
    property alias calcWindow: calcWindow
    property alias clipboardWindow: clipboardWindow
    property alias dictionaryWindow: dictionaryWindow
    property alias unicodeWindow: unicodeWindow
    property alias notesWindow: notesWindow
    property alias passWindow: passWindow
    property alias powerWindow: powerWindow
    property alias todoWindow: todoWindow
    property alias geminiWindow: geminiWindow
    property alias settingsWindow: settingsWindow
    property alias overlayInspectorWindow: overlayInspectorWindow
    property alias emailWindow: emailWindow
    property alias startPageWindow: startPageWindow

    property alias magnifierOverlay: magnifierOverlay
    property alias diceRollerWindowInstance: diceRollerWindowInstance
    property alias amogusWindowInstance: amogusWindowInstance
    property alias notificationOverlay: notificationOverlay

    function closeOtherOverlays(activeWin) {
        var previewTarget = shell.settingsManager ? shell.settingsManager.previewWindow : "";
        var list = [
            appLauncherWindow, calcWindow, clipboardWindow, dictionaryWindow,
            unicodeWindow, notesWindow, passWindow, powerWindow,
            todoWindow, geminiWindow, settingsWindow, emailWindow,
            startPageWindow, diceRollerWindowInstance, amogusWindowInstance
        ];

        for (var i = 0; i < list.length; i++) {
            var w = list[i];
            if (!w || w === activeWin) continue;

            if (previewTarget !== "") {
                if (w === settingsWindow) continue;
                if (w.windowId === previewTarget) continue;
            }

            if (w.visible) {
                if (typeof w.close === "function") w.close();
                else if (typeof w.hideWindow === "function") w.hideWindow();
                else w.visible = false;
            }
        }
    }

    AppLauncherModule.AppLauncherWindow       { id: appLauncherWindow;       shell: overlayHost.shell }
    CalcModule.CalcWindow                     { id: calcWindow;              shell: overlayHost.shell }
    ClipboardModule.ClipboardWindow           { id: clipboardWindow;         shell: overlayHost.shell }
    DictionaryModule.DictionaryWindow         { id: dictionaryWindow;        shell: overlayHost.shell }
    UnicodeModule.UnicodeWindow               { id: unicodeWindow;           shell: overlayHost.shell }
    NotesModule.NotesWindow                   { id: notesWindow;             shell: overlayHost.shell }
    PassModule.PassWindow                     { id: passWindow;              shell: overlayHost.shell }
    PowerModule.PowerWindow                   { id: powerWindow;             shell: overlayHost.shell }
    TodoModule.TodoWindow                     { id: todoWindow;              shell: overlayHost.shell }
    GeminiModule.GeminiWindow                 { id: geminiWindow;            shell: overlayHost.shell }
    SettingsWindowModule.SettingsWindow       { id: settingsWindow;          shell: overlayHost.shell }
    SettingsWindowModule.OverlayInspectorWindow { id: overlayInspectorWindow; shell: overlayHost.shell }
    EmailModule.EmailWindow                   { id: emailWindow;             shell: overlayHost.shell }
    WebSearchModule.StartPageWindow           { id: startPageWindow;         shell: overlayHost.shell }

    Magnify.Magnify { id: magnifierOverlay }
    RNG.DiceRollerWindow { id: diceRollerWindowInstance; shell: overlayHost.shell }
    AmogusModule.AmogusWindow { id: amogusWindowInstance; shell: overlayHost.shell }

    Notifications.NotificationOverlay {
        id: notificationOverlay
        showHistoryMode: overlayHost.shell.showHistoryMode
        notificationsEnabled: overlayHost.shell.notificationsEnabled
        onShowHistoryModeChanged: overlayHost.shell.showHistoryMode = showHistoryMode
        onNotificationsEnabledChanged: overlayHost.shell.notificationsEnabled = notificationsEnabled
    }

    IpcHandler {
        target: "amogus"
        function toggle(): void {
            if (!overlayHost.shell.sessionLock.locked && amogusWindowInstance) amogusWindowInstance.toggleWindow();
        }
    }
    IpcHandler {
        target: "rng"
        function toggle(): void {
            if (!overlayHost.shell.sessionLock.locked && diceRollerWindowInstance) diceRollerWindowInstance.toggleWithTarget();
        }
    }
    IpcHandler {
        target: "magnifier"
        function toggle(): void {
            if (!overlayHost.shell.sessionLock.locked && magnifierOverlay) magnifierOverlay.toggle();
        }
    }
    IpcHandler {
        target: "tooltip"
        function close(): void {
            overlayHost.shell.showHistoryMode = false;
        }
    }
}
