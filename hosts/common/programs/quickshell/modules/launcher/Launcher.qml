import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../" // Import root folder so Theme is visible

PanelWindow {
    id: launcherWindow

    // Controlled via shell.qml toggle logic
    visible: false

    // Attach to the exact screen target matching your status bar
    screen: Quickshell.screens.find(s => s.name === "DP-1") || Quickshell.screens

    // Explicit dimensions for your application layout
    implicitWidth: 450
    implicitHeight: 550

    // Correct Quickshell window positioning syntax
    anchors.top: false
    anchors.bottom: false
    anchors.left: false
    anchors.right: false

    // Safely sets Wayland overlay behavior via attached properties
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: visible ? WlrLayershell.Exclusive : WlrLayershell.None

    Rectangle {
        anchors.fill: parent
        color: Theme.colorBaseBg
        radius: Theme.capsuleRadius
        border.width: Theme.capsuleBorderWidth
        border.color: "#003399" // Matches your blue status bar accents

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            // Search input field
            TextField {
                id: searchInput
                width: parent.width
                placeholderText: "Type to search apps..."
                focus: launcherWindow.visible

                font.family: "monospace"
                font.pixelSize: 14
                color: Theme.colorNormalText
                placeholderTextColor: Theme.colorOutline

                background: Rectangle {
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.colorOutline
                    radius: 6
                }

                onTextChanged: {
                    appsList.model = DesktopEntries.entries.filter(entry =>
                    entry.name.toLowerCase().includes(searchInput.text.toLowerCase())
                    )
                    // Reset selection to the top item whenever search query changes
                    appsList.currentIndex = 0
                }

                // Close window on Escape key press
                Keys.onEscapePressed: launcherWindow.visible = false

                // Intercept arrow keys and enter key to control list navigation
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down) {
                        appsList.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        appsList.decrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                        if (appsList.currentItem) {
                            appsList.currentItem.entryData.launch();
                            launcherWindow.visible = false;
                            searchInput.text = "";
                        }
                        event.accepted = true;
                    }
                }
            }

            // Results Container
            ScrollView {
                width: parent.width
                height: parent.height - searchInput.height - 35
                clip: true

                ListView {
                    id: appsList
                    width: parent.width
                    spacing: 6
                    currentIndex: 0
                    // Ensures the selected item scrolls into view automatically
                    highlightMoveDuration: 150

                    // Load initial listing state
                    Component.onCompleted: {
                        model = DesktopEntries.entries
                    }

                    delegate: AppRow {
                        entryData: modelData

                        onClicked: {
                            modelData.launch()
                            launcherWindow.visible = false // Hide window on launch
                            searchInput.text = "" // Clear query buffer
                        }
                    }
                }
            }
        }
    }
}
