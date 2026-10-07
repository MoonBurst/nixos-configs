import QtQuick
import Quickshell
import Quickshell.Io
import "../../../common" as Common

Item {
    id: engine

    property var remindersList: []
    property int selectedIndex: 0

    Component.onCompleted: {
        listProc.running = true;
    }

    // Fetches initial reminders list from Lua backend
    Process {
        id: listProc
        command: Common.LuaRunner.cmd("modules/overlays/reminders/backend/ReminderEngine.lua", "list")
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    engine.remindersList = JSON.parse(text.trim() || "[]");
                } catch(e) {}
            }
        }
    }

    // Periodically checks due reminders via Lua
    Timer {
        id: checkTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!checkProc.running) {
                checkProc.running = true;
            }
        }
    }

    Process {
        id: checkProc
        command: Common.LuaRunner.cmd("modules/overlays/reminders/backend/ReminderEngine.lua", "check")
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    engine.remindersList = JSON.parse(text.trim() || "[]");
                } catch(e) {}
            }
        }
    }

    Process {
        id: addProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    engine.remindersList = JSON.parse(text.trim() || "[]");
                } catch(e) {}
            }
        }
    }

    function addReminder(text, whenExpr) {
        if (!text || text.trim() === "" || !whenExpr || whenExpr.trim() === "") return;
        addProc.command = Common.LuaRunner.cmd(
            "modules/overlays/reminders/backend/ReminderEngine.lua",
            "add",
            text.trim(),
            whenExpr.trim()
        );
        addProc.running = false;
        addProc.running = true;
    }

    Process {
        id: deleteProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    engine.remindersList = JSON.parse(text.trim() || "[]");
                } catch(e) {}
            }
        }
    }

    function removeReminder(id) {
        deleteProc.command = Common.LuaRunner.cmd(
            "modules/overlays/reminders/backend/ReminderEngine.lua",
            "delete",
            String(id)
        );
        deleteProc.running = false;
        deleteProc.running = true;
    }

    function formatRemaining(targetEpoch) {
        var diff = targetEpoch - Math.floor(Date.now() / 1000);
        if (diff <= 0) return "Due now";
        var d = Math.floor(diff / 86400);
        var h = Math.floor((diff % 86400) / 3600);
        var m = Math.floor((diff % 3600) / 60);
        var s = diff % 60;
        if (d > 0) return d + "d " + h + "h " + m + "m";
        if (h > 0) return h + "h " + m + "m " + s + "s";
        if (m > 0) return m + "m " + s + "s";
        return s + "s";
    }
}
