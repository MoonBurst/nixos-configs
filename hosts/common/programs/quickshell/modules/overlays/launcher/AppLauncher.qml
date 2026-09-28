import QtQuick
import Quickshell
import Quickshell.Io

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

    function fuzzyMatch(needle, haystack) {
        var nlen = needle.length;
        var hlen = haystack.length;
        if (nlen > hlen) return false;
        if (nlen === hlen) return needle === haystack;
        var nIdx = 0;
        var hIdx = 0;
        while (nIdx < nlen && hIdx < hlen) {
            if (needle.charCodeAt(nIdx) === haystack.charCodeAt(hIdx)) {
                nIdx++;
            }
            hIdx++;
        }
        return nIdx === nlen;
    }

    function refreshFilter(query) {
        currentQuery = query || ""
        const q = currentQuery.toLowerCase().trim()
        filteredAppsModel.clear()

        if (q.length === 0) {
            for (let i = 0, c = allApps.length; i < c; ++i) {
                filteredAppsModel.append(allApps[i])
            }
            return;
        }

        var matches = []
        for (let i = 0, c = allApps.length; i < c; ++i) {
            const app = allApps[i]
            let score = 0
            const name = app.searchName
            const exec = app.searchExec

            if (name === q) score = 100;
            else if (name.startsWith(q)) score = 80;
            else if (name.includes(q)) score = 60;
            else if (exec.includes(q)) score = 40;
            else if (root.fuzzyMatch(q, name)) score = 20;

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

    Process {
        id: launcher
    }

    Process {
        id: appLoader

        command: [
            "sh",
            "-c",
            `
            (
                {
                    echo "$XDG_DATA_DIRS" | tr ':' '\\n'
                    echo "$HOME/.nix-profile/share"
                    echo "$HOME/.local/share/state/nix/profile/share"
                    echo "/etc/profiles/per-user/$USER/share"
                    echo "/run/current-system/sw/share"
                    echo "$HOME/.local/share"
                    echo "/usr/share"
                } | while read -r dir; do
                [ -n "$dir" ] && [ -d "$dir/applications" ] || continue
                find -L "$dir/applications" -type f -name '*.desktop' 2>/dev/null
                done |

                sort -u |

                while read -r file; do
                    awk -F= '
                    /^Name=/ && !name {
                        name = substr($0, 6)
                    }

                    /^Exec=/ && !exec {
                        exec = substr($0, 6)

                        gsub(/[[:space:]]*%[fFuUdDnNickvm]/, "", exec)
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", exec)
                    }

                    /^Icon=/ && !icon {
                        icon = substr($0, 6)
                    }

                    END {
                        if (name && exec) {
                            if (!icon)
                                icon = "application-x-executable"

                                printf "%s|%s|%s\\n",
                                name,
                                exec,
                                icon
                        }
                    }
                    ' "$file"
                    done

                    echo "__BINARIES__"

                    echo "$PATH" | tr ':' '\\n' | while read -r dir; do
                    [ -d "$dir" ] || continue

                    find -L "$dir" \
                    -maxdepth 1 \
                    -executable 2>/dev/null
                    done |

                    sort -u |

                    while read -r file; do
                        [ -d "$file" ] && continue

                        bin=$(basename "$file")

                        printf "%s|%s|application-x-executable\\n" \
                        "$bin" \
                        "$bin"
                        done
            )
            `
        ]

        stdout: SplitParser {
            onRead: data => {
                const lines = data.split("\n")

                for (let i = 0, c = lines.length; i < c; ++i) {
                    const line = lines[i].trim()

                    if (!line || line === "__BINARIES__") {
                        continue
                    }

                    const first = line.indexOf("|")
                    const second = line.indexOf("|", first + 1)

                    if (first === -1 || second === -1) {
                        continue
                    }

                    addApp(
                        line.slice(0, first),
                        line.slice(first + 1, second),
                        line.slice(second + 1)
                    )
                }
            }
        }

        onExited: {
            flushApps()
        }
    }

    Component.onCompleted: {
        loadApps()
    }
}
