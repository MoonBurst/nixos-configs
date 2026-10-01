import QtQuick
import Quickshell
import Quickshell.Io
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
        command: [
            "python3", "-c",
            "import os, glob, sys\n" +
            "seen = set()\n" +
            "dirs = []\n" +
            "xdg_data = os.environ.get('XDG_DATA_HOME', os.path.expanduser('~/.local/share'))\n" +
            "dirs.append(xdg_data)\n" +
            "if os.environ.get('XDG_DATA_DIRS'):\n" +
            "    dirs.extend(os.environ['XDG_DATA_DIRS'].split(':'))\n" +
            "u = os.environ.get('USER', '')\n" +
            "dirs.extend([\n" +
            "    os.path.expanduser('~/.local/share'),\n" +
            "    os.path.expanduser('~/.nix-profile/share'),\n" +
            "    f'/etc/profiles/per-user/{u}/share',\n" +
            "    '/run/current-system/sw/share',\n" +
            "    '/nix/var/nix/profiles/default/share',\n" +
            "    '/usr/local/share',\n" +
            "    '/usr/share',\n" +
            "    '/var/lib/flatpak/exports/share',\n" +
            "    os.path.expanduser('~/.local/share/flatpak/exports/share'),\n" +
            "    os.path.expanduser('~/.local/share/applications'),\n" +
            "    os.path.expanduser('~/Desktop'),\n" +
            "    '/var/lib/snapd/desktop'\n" +
            "])\n" +
            "# Scan all applications directories\n" +
            "checked = set()\n" +
            "for d in dirs:\n" +
            "    if not d: continue\n" +
            "    p = os.path.abspath(os.path.expanduser(d))\n" +
            "    if p in checked or not os.path.isdir(p): continue\n" +
            "    checked.add(p)\n" +
            "    app_dir = p if p.endswith('applications') else os.path.join(p, 'applications')\n" +
            "    if not os.path.isdir(app_dir): continue\n" +
            "    for root, _, files in os.walk(app_dir):\n" +
            "        for f in files:\n" +
            "            if not f.endswith('.desktop'): continue\n" +
            "            fp = os.path.join(root, f)\n" +
            "            name, exec_cmd, icon = '', '', 'application-x-executable'\n" +
            "            nodisp = False\n" +
            "            try:\n" +
            "                with open(fp, 'r', encoding='utf-8', errors='ignore') as df:\n" +
            "                    in_entry = False\n" +
            "                    for line in df:\n" +
            "                        line = line.strip()\n" +
            "                        if line == '[Desktop Entry]': in_entry = True\n" +
            "                        elif line.startswith('[') and in_entry: break\n" +
            "                        if not in_entry: continue\n" +
            "                        if line.startswith('Name=') and not name: name = line[5:].strip()\n" +
            "                        elif line.startswith('Exec=') and not exec_cmd: exec_cmd = line[5:].split('%')[0].strip()\n" +
            "                        elif line.startswith('Icon=') and icon == 'application-x-executable': icon = line[5:].strip()\n" +
            "                        elif line.lower() == 'nodisplay=true': nodisp = True\n" +
            "                if nodisp and 'steam' not in exec_cmd.lower(): continue\n" +
            "                if name and exec_cmd and exec_cmd.lower() not in seen:\n" +
            "                    seen.add(exec_cmd.lower())\n" +
            "                    print(f'{name}|{exec_cmd}|{icon}')\n" +
            "            except Exception: pass\n" +
            "# Also index executables in PATH\n" +
            "for p in os.environ.get('PATH', '').split(':'):\n" +
            "    if os.path.isdir(p):\n" +
            "        try:\n" +
            "            for entry in os.scandir(p):\n" +
            "                if entry.name not in seen and entry.is_file() and os.access(entry.path, os.X_OK):\n" +
            "                    seen.add(entry.name)\n" +
            "                    print(f'{entry.name}|{entry.name}|application-x-executable')\n" +
            "        except Exception: pass\n"
        ]
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

            if (score > 0) matches.push({ app: app, score: score });
        }
        matches.sort((a, b) => b.score - a.score);
        for (let j = 0; j < matches.length; ++j) fModel.append(matches[j].app);
    }

    readonly property Process launcherProc: Process {}

    function launch(command) {
        if (!command) return;
        launcherProc.running = false;
        launcherProc.command = [
            "sh", "-c",
            'if command -v systemd-run >/dev/null 2>&1; then\n' +
            '    systemd-run --user --scope --slice=app.slice sh -c "$1" >/dev/null 2>&1 &\n' +
            'elif command -v swaymsg >/dev/null 2>&1; then\n' +
            '    swaymsg exec -- "$1" >/dev/null 2>&1\n' +
            'else\n' +
            '    ( nohup setsid -f sh -c "$1" >/dev/null 2>&1 & )\n' +
            'fi',
            "launcher-exec", command
        ];
        launcherProc.running = true;
    }
}
