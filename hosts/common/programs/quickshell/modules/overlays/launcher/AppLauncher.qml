import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string currentQuery: ""

    property alias apps: appsModel
    property alias filteredApps: filteredAppsModel

    ListModel {
        id: appsModel
    }

    ListModel {
        id: filteredAppsModel
    }

    function loadApps() {
        appsModel.clear()
        filteredAppsModel.clear()

        appLoader.running = true
    }

    function refreshFilter(query) {
        currentQuery = query || ""

        const q =
        currentQuery
        .toLowerCase()
        .trim()

        filteredAppsModel.clear()

        for (let i = 0; i < appsModel.count; ++i) {
            const app = appsModel.get(i)

            const name =
            (app.name || "")
            .toLowerCase()

            const exec =
            (app.exec || "")
            .toLowerCase()

            if (
                q.length === 0 ||
                name.includes(q) ||
                exec.includes(q)
            ) {
                filteredAppsModel.append({
                    name: app.name,
                    exec: app.exec,
                    icon: app.icon
                })
            }
        }
    }

    function launch(command) {
        if (!command || command.length === 0) {
            return
        }

        let cleaned = command

        cleaned = cleaned.replace(
            /%[fFuUdDnNickvm]/g,
            ""
        )

        cleaned = cleaned
        .replace(/\s+/g, " ")
        .trim()

        launcher.command = [
            "sh",
            "-c",
            cleaned
        ]

        launcher.running = true
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
            find \
            /run/current-system/sw/share/applications \
            $HOME/.local/share/applications \
            /usr/share/applications \
            -name '*.desktop' 2>/dev/null |

            while read -r file; do

                name=$(grep -m1 '^Name=' "$file" | cut -d= -f2-)

                exec_cmd=$(grep -m1 '^Exec=' "$file" | cut -d= -f2-)

                icon=$(grep -m1 '^Icon=' "$file" | cut -d= -f2-)

                exec_cmd=$(printf '%s\n' "$exec_cmd" \
                | sed -E 's/[[:space:]]+%[fFuUdDnNickvm]//g')

                exec_cmd=$(echo "$exec_cmd" \
                | sed 's/^ *//;s/ *$//')

                [ -z "$name" ] && continue
                [ -z "$exec_cmd" ] && continue

                [ -z "$icon" ] && \
                icon='application-x-executable'

                echo "$name|$exec_cmd|$icon"

                done | sort -u
                `
        ]

        stdout: SplitParser {
            onRead: data => {
                const lines =
                data.split("\n")

                for (
                    let i = 0;
                i < lines.length;
                ++i
                ) {
                    const line =
                    lines[i].trim()

                    if (!line.length) {
                        continue
                    }

                    const parts =
                    line.split("|")

                    if (parts.length < 3) {
                        continue
                    }

                    appsModel.append({
                        name: parts[0],
                        exec: parts[1],
                        icon: parts[2]
                    })
                }
            }
        }

        onExited: {
            refreshFilter("")
        }
    }

    Component.onCompleted: {
        loadApps()
    }
}
