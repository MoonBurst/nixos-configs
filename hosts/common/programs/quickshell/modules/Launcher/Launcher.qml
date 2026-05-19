pragma ComponentBehavior: Bound
import qs.Library
import qs.Utils
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "root:Utils/fuzzy.js" as FuzzySort
import qs.Launcher.Components
import Qt.labs.folderlistmodel

Scope {
    id: root

    // Mirrored from Search component (safe when LazyLoader is inactive)
    property string searchText: ""
    property bool searchEmpty: true

    // Mode detection based on first character
    property string mode: {
        if (searchEmpty)
            return "app";
        switch (searchText[0]) {
        case ":":
            return "wallpaper";
        case "#":
            return "calc";
        case ">":
            return "shell";
        case "?":
            return "search";
        default:
            return "app";
        }
    }
    property string query: mode === "app" ? searchText : searchText.substring(1)

    // Wallpaper folder model
    FolderListModel {
        id: wallModel
        folder: Qt.resolvedUrl("/home/pseudonym/walls/")
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG"]
        showDirs: false
    }

    // Shell command opens in a new kitty instance
    Process {
        id: shellProc
        command: ["kitty", "--hold", "bash", "-c", root.query]
    }

    // Clipboard copy via wl-copy
    Process {
        id: clipProc
    }

    // Firefox process for Google search
    Process {
        id: firefoxProc
        command: ["firefox", "--new-window", "https://www.google.com/search?q=" + encodeURIComponent(root.query)]
    }

    function closeLauncher(list: var): void {
        list.scale = 0;
        StateManager.showLauncher = false;
        StateManager.launcher = false;
        searchText = "";
        searchEmpty = true;
    }

    function executeCurrentMode(index: int, list: var): void {
        const item = launcherModel.values[index];
        switch (root.mode) {
        case "wallpaper":
            {
                if (item && item.filePath) {
                    // FolderListModel returns file:// URLs; Colors.schemeImage expects a plain path
                    Colors.schemeImage = item.filePath.toString().replace("file://", "");
                }
                closeLauncher(list);
                break;
            }
        case "calc":
            {
                if (item && item.result !== undefined) {
                    clipProc.command = ["wl-copy", item.result.toString()];
                    clipProc.running = true;
                }
                closeLauncher(list);
                break;
            }
        case "shell":
            shellProc.running = true;
            closeLauncher(list);
            break;
        case "search":
            if (root.query.length > 0) {
                firefoxProc.startDetached();
            }
            closeLauncher(list);
            break;
        default:
            {
                item.execute();
                closeLauncher(list);
                break;
            }
        }
    }

    ScriptModel {
        id: launcherModel
        objectProp: "name"
        values: {
            if (root.searchEmpty)
                return DesktopEntries.applications.values;
            switch (root.mode) {
            case "wallpaper":
                {
                    var walls = [];
                    var q = root.query.toLowerCase();
                    for (var i = 0; i < wallModel.count; i++) {
                        var fn = wallModel.get(i, "fileName");
                        var fp = wallModel.get(i, "filePath");
                        if (q.length === 0 || fn.toLowerCase().includes(q)) {
                            walls.push({
                                name: fn,
                                fileName: fn,
                                filePath: fp
                            });
                        }
                    }
                    return walls;
                }
            case "calc":
                {
                    if (root.query.length === 0)
                        return [
                            {
                                name: "Type a math expression...",
                                icon: "calculate"
                            }
                        ];
                    try {
                        var result = Function('"use strict"; return (' + root.query + ')')();
                        return [
                            {
                                name: "= " + result,
                                icon: "calculate",
                                result: result
                            }
                        ];
                    } catch (e) {
                        return [
                            {
                                name: "Invalid expression",
                                icon: "calculate"
                            }
                        ];
                    }
                }
            case "shell":
                {
                    if (root.query.length === 0)
                        return [
                            {
                                name: "Type a command...",
                                icon: "terminal"
                            }
                        ];
                    return [
                        {
                            name: "Run: " + root.query,
                            icon: "terminal"
                        }
                    ];
                }
            case "search":
                {
                    if (root.query.length === 0)
                        return [
                            {
                                name: "Type a search query...",
                                icon: "search"
                            }
                        ];
                    return [
                        {
                            name: "Google: " + root.query,
                            icon: "search"
                        }
                    ];
                }
            default:
                return FuzzySort.go(root.searchText, DesktopEntries.applications.values, {
                    all: true,
                    keys: ["name", "genericName"]
                }).map(a => a.obj);
            }
        }
    }

    Connections {
        target: StateManager
        function onLauncherChanged(): void {
            if (StateManager.launcher == true) {
                StateManager.showLauncher = true;
                loader.active = true;
            } else {
                StateManager.showLauncher = false;
                closeTimer.running = true;
            }
        }
        function onShowLauncherChanged(): void {
            if (StateManager.showLauncher == true) {
                console.log("The launcher is open.");
            } else {
                closeTimer.running = true;
            }
        }
    }
    Timer {
        id: closeTimer
        interval: 350
        running: false
        repeat: false
        onTriggered: {
            loader.active = false;
        }
    }
    LazyLoader {
        id: loader
        PanelWindow {
            implicitWidth: 256
            implicitHeight: 256
            anchors.top: true
            // anchors.left: true
            // margins.left: 6
            margins.top: StateManager.dashboard ? 232 : 6
            exclusiveZone: 0
            focusable: true
            color: 'transparent'
            Search {
                id: search
                scale: 0
                mode: root.mode
                property var current
                onContentChanged: {
                    root.searchText = content;
                    root.searchEmpty = empty;
                    delegatedList.forceLayout();
                }
                Keys.onUpPressed: {
                    delegatedList.decrementCurrentIndex();
                    current = delegatedList.currentIndex;
                }
                Keys.onDownPressed: {
                    delegatedList.incrementCurrentIndex();
                    current = delegatedList.currentIndex;
                }
                Keys.onReturnPressed: {
                    root.executeCurrentMode(delegatedList.currentIndex, delegatedList);
                }
                Keys.onEscapePressed: {
                    StateManager.launcher = false;
                }
            }
            DelegatedList {
                id: delegatedList
                z: -1
                scale: 0
                model: launcherModel
                Component.onCompleted: {
                    scale = 1;
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 350
                        easing.bezierCurve: Config.easing.standard
                    }
                }
            }
        }
    }
}
