import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "../../../" // Points back cleanly to your local root Theme.qml configuration

Rectangle {
    id: overlayRoot
    anchors.fill: parent

    // ============================================================================
    // #### MODULE LOGIC: THEME COLOR LOOKUPS MAPPED TO LOCAL STYLIX FIELDS ####
    // ============================================================================
    // Reads directly from your local profile instead of relying on a micro-managing parent function
    color: (typeof Theme !== 'undefined' && Theme.base00 !== undefined) ? Theme.base00 : "black"
    opacity: 0.92

    // State parameters mapping visibility signals to the root panel windows
    signal requestClose()

    // ============================================================================
    // #### MODULE LOGIC: FOCUS AND KEYBOARD CAPTURE HANDLING ####
    // ============================================================================
    // Forces the text field to automatically grab input focus as soon as the menu opens
    Component.onCompleted: {
        console.log("🚀 LauncherOverlay loaded into window scene memory.");
        appSearchInput.forceActiveFocus();
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            console.log("📥 Escape key intercepted. Closing launcher overlay...");
            overlayRoot.requestClose();
            event.accepted = true;
        }
    }

    // ============================================================================
    // #### MODULE LOGIC: APP LAUNCHER SEARCH BAR INTERFACE ROW ####
    // ============================================================================
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.6, 650)
        spacing: 20

        Rectangle {
            id: searchBarContainer
            Layout.fillWidth: true
            height: 55
            radius: 8

            // Decoupled color values linked straight to your theme variables
            color: (typeof Theme !== 'undefined' && Theme.base01 !== undefined) ? Theme.base01 : "#1a1a1a"
            border.width: 2
            border.color: (typeof Theme !== 'undefined' && Theme.base0D !== undefined) ? Theme.base0D : "yellow"

            TextField {
                id: appSearchInput
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15

                placeholderText: "Search apps, run calculations, query definitions..."
                placeholderTextColor: "#666666"

                font.family: "monospace"
                font.pixelSize: 18

                color: (typeof Theme !== 'undefined' && Theme.base05 !== undefined) ? Theme.base05 : "white"
                background: null

                onTextChanged: {
                    if (launcherControlLoader.item) {
                        launcherControlLoader.item.filterApps(text);
                    }
                }

                onAccepted: {
                    console.log("⚡ Executing search submission value string: " + text);
                    if (launcherControlLoader.item) {
                        launcherControlLoader.item.runMath(text);
                    }
                }
            }
        }

        // ============================================================================
        // #### MODULE LOGIC: RESULTS MATRIX VIEW BOX ####
        // ============================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 300
            radius: 8
            color: (typeof Theme !== 'undefined' && Theme.base01 !== undefined) ? Theme.base01 : "#1a1a1a"
            border.width: 1
            border.color: (typeof Theme !== 'undefined' && Theme.base02 !== undefined) ? Theme.base02 : "#333333"

            Text {
                anchors.centerIn: parent
                text: "Application Search Grid Settle Layer Area"
                font.family: "monospace"
                font.pixelSize: 16
                color: (typeof Theme !== 'undefined' && Theme.base04 !== undefined) ? Theme.base04 : "#888888"
            }
        }
    }
}
