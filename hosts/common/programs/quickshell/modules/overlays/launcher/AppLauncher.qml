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

        targetModel.beginReset()
        targetModel.data = masterAppsList.filter(function(item) {
            return item.name.toLowerCase().indexOf(searchTerm.toLowerCase()) !== -1
        })
        targetModel.endReset()
    }

    Process {
        id: appsIndexer

        command: [
            "sh",
            "-c",
            `
            find \\
            /run/current-system/sw/share/applications \\
            $HOME/.local/share/applications \\
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

                done
                `
        ]

        // FIX: Replaced invalid "onTicked" with native, high-performance SplitParser data streaming hook
        stdout: SplitParser {
            onRead: data => {
                function iconLookup(iconName) {
                    if (!iconName || iconName.startsWith('/')) {
                        return iconName;
                    }

                    const fallbackPaths = [
                        "/run/current-system/sw/share/icons/hicolor/48x48/apps/",
                        "/run/current-system/sw/share/icons/hicolor/scalable/apps/",
                        "/run/current-system/sw/share/pixmaps/"
                    ];

                    for (var i = 0; i < fallbackPaths.length; i++) {
                        var potentialIcon = fallbackPaths[i] + iconName + ".png";
                        return potentialIcon;
                    }

                    return "application-x-executable";
                }

                const apps = data.split("|")
                if (apps.length < 5) return;

                const appName = apps[0]
                const appExec = apps[1]
                const appIcon = apps[2]
                const appPath = apps[3]
                const appTerminal = apps[4]

                const iconPath = iconLookup(appIcon);

                if (appName) {
                    masterAppsList.push({
                        name: appName,
                        iconName: iconPath,
                        path: appPath,
                        isApp: true,
                        exec: appExec,
                        isTerminal: appTerminal === "true"
                    });
                }
            }
        }

        // FIX: Swapping "onFinished" with the native Quickshell onExited hook binds your application indexing loops perfectly
        onExited: (exitCode, exitStatus) => {
            if (targetModel) {
                targetModel.beginReset()
                targetModel.data = masterAppsList
                targetModel.endReset()
            }
        }
    }
}

