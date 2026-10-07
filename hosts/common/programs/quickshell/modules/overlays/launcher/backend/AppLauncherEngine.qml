import QtQuick
import Quickshell
import Quickshell.Io
import "../../../common" as Common
import "../../../common/Utils.js" as Utils

QtObject {
    id: engine

    property string currentQuery: ""
    property var allApps: []
    property var knownExecs: ({})
    property var pendingApps: []
    property var filteredAppsModel: ListModel { id: fModel }

    Component.onCompleted: scan()

    function scan() {
        appLoader.running = false;
        appLoader.running = true;
    }

    readonly property Process appLoader: Process {
        command: Common.LuaRunner.cmd("modules/overlays/launcher/backend/AppLauncherEngine.lua")
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const line = data.trim();
                if (!line) return;
                const p = line.split("|");
                if (p.length >= 2) {
                    const key = p[1].toLowerCase();
                    if (!engine.knownExecs[key]) {
                        engine.knownExecs[key] = true;
                        let icon = p[2] || "application-x-executable";
                        if (icon.startsWith("/")) icon = "file://" + icon;
                        engine.pendingApps.push({
                            name: p[0],
                            exec: p[1],
                            icon: icon,
                            recentRank: parseInt(p[3]) || 0,
                            searchName: p[0].toLowerCase(),
                            searchExec: key
                        });
                    }
                }
            }
        }
        onStarted: { engine.pendingApps = []; engine.knownExecs = ({}); }
        onExited: {
            engine.allApps = engine.pendingApps;
            engine.refreshFilter(engine.currentQuery);
        }
    }

    function recordRecent(cmd) {
        if (!cmd) return;
        Quickshell.execDetached(Common.LuaRunner.cmd("modules/overlays/launcher/backend/AppLauncherEngine.lua", "record", cmd));
    }

    function refreshFilter(query) {
        currentQuery = query || "";
        const q = currentQuery.toLowerCase().trim();
        fModel.clear();

        if (q.length === 0) {
            let limit = Math.min(80, allApps.length);
            for (let i = 0; i < limit; ++i) fModel.append(allApps[i]);
            return;
        }

        var matches = [];
        let limit = Math.min(100, allApps.length);
        for (let i = 0; i < limit; ++i) {
            const app = allApps[i];
            let score = 0;
            const name = app.searchName;
            const exec = app.searchExec;

            if (name === q) score = 100;
            else if (name.startsWith(q)) score = 80;
            else if (name.includes(q)) score = 60;
            else if (exec.includes(q)) score = 40;
            else if (Utils.fuzzyMatch(q, name)) score = 20;

            if (score > 0) {
                if (app.recentRank > 0) score += Math.min(30, Math.round(app.recentRank / 30));
                matches.push({ app: app, score: score });
            }
        }
        matches.sort((a, b) => b.score - a.score);
        for (let j = 0; j < matches.length; ++j) fModel.append(matches[j].app);
    }

    readonly property Process launcherProc: Process {}

    function launch(command) {
        if (!command) return;
        recordRecent(command);
        launcherProc.running = false;
        launcherProc.command = [
            "systemd-run",
            "--user",
            "--collect",
            "--quiet",
            "--slice=app.slice",
            "sh",
            "-c",
            command
        ];
        launcherProc.running = true;
    }
}
