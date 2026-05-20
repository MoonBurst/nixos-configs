import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    Layout.fillWidth: true
    Layout.fillHeight: true

    // High-frequency tick counter that manually signals QML to re-sort the layout
    property int layoutTick: 0

    // Connect to valid signals that exist natively on ObjectModel instances
    Connections {
        target: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
        ? Hyprland.focusedMonitor.activeWorkspace.toplevels
        : null

        // This fires natively whenever objects or windows shift roles inside the collection
        function onValuesChanged() {
            root.layoutTick++;
        }
    }

    // Intercept broad compositor window changes to catch same-workspace tiling shifts
    Connections {
        target: Hyprland
        function onEvent(name, data) {
            // These catch keyboard focus swaps, tiling moves, and mouse drag updates
            if (name === "activewindow" || name === "movewindow" || name === "layoutchanged") {
                // Force Hyprland to update its underlying C++ object tracking properties
                Hyprland.refreshToplevels();
                root.layoutTick++;
            }
        }
    }

    // THE REACTIVE DATA ARRAY
    readonly property var sortedToplevels: {
        // Explicitly binding this trigger forces QML to re-run the sort algorithm on every layout tick
        let _forcedUpdate = root.layoutTick;

        if (!Hyprland.focusedMonitor || !Hyprland.focusedMonitor.activeWorkspace) {
            return [];
        }

        let model = Hyprland.focusedMonitor.activeWorkspace.toplevels;
        if (!model || !model.values || model.values.length === 0) {
            return [];
        }

        // Unpack into a raw, sortable JavaScript array slice
        let list = [...model.values];

        return list.sort((a, b) => {
            // FIX: Pull directly from the live Wayland client geometry mapping tree
            let ax = (a.wayland && a.wayland.x !== undefined) ? a.wayland.x : 0;
            let bx = (b.wayland && b.wayland.x !== undefined) ? b.wayland.x : 0;

            // If coordinates match, fallback cleanly to unique hex addresses
            if (ax === bx) {
                return a.address.localeCompare(b.address);
            }
            return ax - bx;
        });
    }

    // CALCULATED RENDER DIMENSIONS
    readonly property int totalSpacing: Math.max(0, (sortedToplevels.length - 1) * 6)
    readonly property int calculatedTabWidth: sortedToplevels.length > 0
    ? Math.floor((root.width - totalSpacing) / sortedToplevels.length)
    : 0

    Repeater {
        model: root.sortedToplevels

        delegate: Rectangle {
            id: windowTab

            width: root.calculatedTabWidth
            height: root.parent ? root.parent.height : 30
            y: 0

            // ANIMATION SLIDE: Smoothly shifts the horizontal layout position back and forth
            x: index * (root.calculatedTabWidth + 6)
            Behavior on x {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }

            radius: (typeof Theme !== "undefined") ? Theme.capsuleRadius : 6
            color: (typeof Theme !== "undefined") ? Theme.colorBaseBg : "#000000"
            border.width: (typeof Theme !== "undefined") ? Theme.capsuleBorderWidth : 2

            // Dynamic yellow highlight mapping updates instantly on active states
            border.color: modelData.activated ? "#ffff00" : "#555555"

            Text {
                anchors.centerIn: parent
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight

                text: modelData.title !== "" ? modelData.title : "Window"

                color: modelData.activated
                ? "#ffff00"
                : ((typeof Theme !== "undefined") ? Theme.colorNormalText : "#ffffff")

                font.family: "monospace"
                font.pixelSize: 13
                font.bold: modelData.activated
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("focuswindow address:" + modelData.address)
            }
        }
    }
}
