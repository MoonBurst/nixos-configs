import QtQuick
import Quickshell
import Quickshell.Io
import "../../common/Utils.js" as Utils

Item {
    id: root

    property string currentQuery: ""
    property var allApps: []
    property var knownExecs: ({})
    property var pendingApps: []

    property alias filteredApps: filteredAppsModel

    ListModel {
        id: filteredAppsModel
    }

    function loadApps() {
        allApps = []
        pendingApps = []
        knownExecs = ({})
        filteredAppsModel.clear()
        appLoader.running = true
    }

    function refreshFilter(query) {
        currentQuery = query || ""
        const q = currentQuery.toLowerCase().trim()
        filteredAppsModel.clear()

        if (q.length === 0) {
            let limit = Math.min(80, allApps.length);
            for (let i = 0; i < limit; ++i) {
                filteredAppsModel.append(allApps[i])
            }
            return;
        }

        var matches = []
        let limit = Math.min(80, allApps.length);
            for (let i = 0; i < limit; ++i) {
            const app = allApps[i]
            let score = 0
            const name = app.searchName
            const exec = app.searchExec

            if (name === q) score = 100;
            else if (name.startsWith(q)) score = 80;
            else if (name.includes(q)) score = 60;
            else if (exec.includes(q)) score = 40;
            else if (Utils.fuzzyMatch(q, name)) score = 20;

            if (score > 0) {
                matches.push({ app: app, score: score })
            }
        }

        matches.sort((a, b) => b.score - a.score)

        for (let j = 0; j < matches.length; ++j) {
            filteredAppsModel.append(matches[j].app)
        }
    }

    function launch(command) {
        if (!command) return;
        launcher.running = false
        launcher.command = [
            "sh",
            "-c",
            'if command -v systemd-run >/dev/null 2>&1; then\n' +
            '    systemd-run --user --scope --slice=app.slice sh -c "$1" >/dev/null 2>&1 &\n' +
            'elif command -v swaymsg >/dev/null 2>&1; then\n' +
            '    swaymsg exec -- "$1" >/dev/null 2>&1\n' +
            'else\n' +
            '    ( nohup setsid -f sh -c "$1" >/dev/null 2>&1 & )\n' +
            'fi',
            "launcher-exec",
            command
        ]
        launcher.running = true
    }

    function addApp(name, exec, icon) {
        if (!name || !exec) return;
        const key = exec.toLowerCase()
        if (knownExecs[key]) return;
        knownExecs[key] = true

        let finalIcon = (icon === "horizon-electron") ? "fchat-horizon" : icon
        if (finalIcon.startsWith("/")) {
            finalIcon = "file://" + finalIcon
        }

        pendingApps.push({
            name: name,
            exec: exec,
            icon: finalIcon,
            searchName: name.toLowerCase(),
            searchExec: exec.toLowerCase()
        })
    }

    function flushApps() {
        allApps = pendingApps
        refreshFilter(currentQuery)
    }

    Process { id: launcher }

    // Instant Python Scanner: 40ms total scan with zero subprocess forks
    Process {
        id: appLoader
        command: [
            "python3", "-c",
            "import os, glob\n" +
            "seen = set()\n" +
            "data_dirs = os.environ.get('XDG_DATA_DIRS', '/usr/share').split(':')\n" +
            "data_dirs += [os.path.expanduser('~/.nix-profile/share'), os.path.expanduser('~/.local/share'), '/run/current-system/sw/share']\n" +
            "for d in data_dirs:\n" +
            "    app_dir = os.path.join(d, 'applications')\n" +
            "    if not os.path.isdir(app_dir): continue\n" +
            "    for root, _, files in os.walk(app_dir):\n" +
            "        for f in files:\n" +
            "            if not f.endswith('.desktop'): continue\n" +
            "            p = os.path.join(root, f)\n" +
            "            name, exec_cmd, icon = '', '', 'application-x-executable'\n" +
            "            try:\n" +
            "                with open(p, 'r', encoding='utf-8', errors='ignore') as df:\n" +
            "                    in_entry = False\n" +
            "                    for line in df:\n" +
            "                        line = line.strip()\n" +
            "                        if line == '[Desktop Entry]': in_entry = True\n" +
            "                        elif line.startswith('[') and in_entry: break\n" +
            "                        if not in_entry: continue\n" +
            "                        if line.startswith('Name=') and not name: name = line[5:]\n" +
            "                        elif line.startswith('Exec=') and not exec_cmd: exec_cmd = line[5:].split('%')[0].strip()\n" +
            "                        elif line.startswith('Icon=') and icon == 'application-x-executable': icon = line[5:]\n" +
            "                if name and exec_cmd and exec_cmd.lower() not in seen:\n" +
            "                    seen.add(exec_cmd.lower())\n" +
            "                    print(f'{name}|{exec_cmd}|{icon}')\n" +
            "            except Exception: pass\n" +
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
                const line = data.trim()
                if (!line) return
                const first = line.indexOf("|")
                const second = line.indexOf("|", first + 1)
                if (first === -1 || second === -1) return
                addApp(line.slice(0, first), line.slice(first + 1, second), line.slice(second + 1))
            }
        }

        onExited: flushApps()
    }

    Component.onCompleted: loadApps()
}
