import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: appLauncherRoot

    property var masterAppsList: []
    property var targetModel: null

    function loadApps(model) {
        if (!model) {
            console.log("AppLauncher: loadApps called with null model!")
            return;
        }
        targetModel = model;
        masterAppsList = []
        appsIndexer.running = true
    }

    function filter(searchTerm) {
        if (!targetModel) return;

        targetModel.clear();
        let query = (searchTerm || "").trim().toLowerCase();

        for (let i = 0; i < masterAppsList.length; ++i) {
            let app = masterAppsList[i];
            let haystack = (app.labelName + " " + app.desktopPath).toLowerCase();

            if (query.length === 0 || haystack.includes(query)) {
                targetModel.append(app);
            }
        }
    }

    Process {
        id: appsIndexer

        command: [
            "sh",
            "-c",
            `
            find \\
            /run/current-system/sw/share/applications \\
            ~/.local/share/applications \\
            -name '*.desktop' 2>/dev/null |

            while read -r f; do

                name=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
                exec_cmd=$(grep -m1 '^Exec=' "$f" | cut -d= -f2-)
                icon=$(grep -m1 '^Icon=' "$f" | cut -d= -f2-)
                terminal=$(grep -m1 '^Terminal=' "$f" | cut -d= -f2-)

                exec_cmd=$(printf '%s\\n' "$exec_cmd" | \\
                sed -E 's/[[:space:]]+%[fFuUdDnNickvm]//g')

                exec_cmd=$(echo "$exec_cmd" | sed 's/^ *//;s/ *$//')

                [ -z "$name" ] && continue
                [ -z "$exec_cmd" ] && continue

                [ -z "$icon" ] && icon="application-x-executable"

                echo "$name|$exec_cmd|$icon|$f|$terminal"

                done | sort -u
                `
        ]

        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return

                    let lines = data.split("\\n")
                    for (let line of lines) {
                        line = line.trim()
                        if (!line) continue

                            let parts = line.split("|")
                            if (parts.length < 5) continue

                                appLauncherRoot.masterAppsList.push({
                                    labelName: parts[0],
                                    execCmd: parts[1],
                                    iconName: parts[2],
                                    desktopPath: parts[3],
                                    runInTerminal: parts[4] === "true",
                                    isClipboard: false,
                                    isImageClip: false,
                                    imagePath: "",
                                    clipId: ""
                                })
                    }
            }
        }

        onExited: {
            appLauncherRoot.filter("")
        }
    }
}
