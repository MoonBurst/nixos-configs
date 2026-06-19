import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string currentQuery: ""
    property string pendingQuery: ""

    property var allApps: []
    property var knownExecs: ({})
    property var pendingApps: []

    property alias filteredApps: filteredAppsModel

    ListModel {
        id: filteredAppsModel
    }

    Timer {
        id: filterTimer

        interval: 40
        repeat: false

        onTriggered: {
            refreshFilter(pendingQuery)
        }
    }

    function loadApps() {
        allApps = []
        pendingApps = []
        knownExecs = ({})

        filteredAppsModel.clear()

        appLoader.running = true
    }

    function queueFilter(query) {
        pendingQuery = query || ""
        filterTimer.restart()
    }

    function refreshFilter(query) {
        currentQuery = query || ""

        const q = currentQuery.toLowerCase().trim()
        const showAll = q.length === 0

        filteredAppsModel.clear()

        for (let i = 0, c = allApps.length; i < c; ++i) {
            const app = allApps[i]

            if (
                showAll ||
                app.searchName.includes(q) ||
                app.searchExec.includes(q)
            ) {
                filteredAppsModel.append(app)
            }
        }
    }

    function launch(command) {
        if (!command) {
            return
        }

        // Run via a detached subshell so programs survive when Quickshell reloads
        launcher.command = [
            "sh",
            "-c",
            "nohup setsid " + command + " >/dev/null 2>&1 &"
        ]

        launcher.running = true
    }

    function addApp(name, exec, icon) {
        if (!name || !exec) {
            return
        }

        const key = exec.toLowerCase()

        if (knownExecs[key]) {
            return
        }

        knownExecs[key] = true

        // If the desktop entry points to the mismatching icon string, translate it to what's on disk
        let finalIcon = (icon === "horizon-electron") ? "fchat-horizon" : icon

        if (finalIcon.startsWith("/")) {
            finalIcon = "file://" + finalIcon
        }

        pendingApps.push({
            name,
            exec,
            icon: finalIcon,
            searchName: name.toLowerCase(),
                         searchExec: exec.toLowerCase()
        })
    }

    function flushApps() {
        allApps = pendingApps
        refreshFilter("")
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
