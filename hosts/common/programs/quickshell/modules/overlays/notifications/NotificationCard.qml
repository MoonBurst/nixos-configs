import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: cardWindow

    // Pin the window container bounds
    anchors.top: true
    anchors.right: true
    anchors.left: false
    anchors.bottom: true

    required property var notification
    required property var rulesLoader
    required property var rootItem
    required property var controller

    property real targetY: rootItem.overlaysHeightBaseline
    property int stackIndex: 0
    property int currentQueueIndex: 0

    property bool entryPhaseCompleted: false
    property bool isManualDismiss: false

    property bool isCriticalCard: rulesLoader.getIsUrgent(notification)

    property color normalBorderColor: isCriticalCard
    ? shell.theme.base08
    : rulesLoader.getBorderColor(notification, shell.theme, shell.theme.base05)

    property int entryInitialHeightY: 250 // Lower default spawn point
    property int hiddenX: rootItem.cardWidth + 100
    property int shownX: 0

    screen: Quickshell.screens.find(s => s.name === "DP-2")

    // FIX 1: Lowercase implicitWidth handles the layer shell dimension bindings properly
    implicitWidth: rootItem.cardWidth + 100
    color: "transparent"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    WlrLayershell.layer: cardWindow.stackIndex > 0
    ? WlrLayer.Overlay
    : WlrLayer.Top

    WlrLayershell.exclusiveZone: 0
    WlrLayershell.margins.top: 0
    WlrLayershell.margins.right: shell.theme.globalPadding

    mask: Region {
        x: 0
        y: 0
        width: 300
        height: 1000
    }

    Component.onCompleted: {
        // Set the initial hidden spawning coordinates
        popupCardBody.x = cardWindow.hiddenX;
        popupCardBody.y = cardWindow.entryInitialHeightY;

        // Trigger the self-contained state engine transition
        Qt.callLater(function () {
            popupCardBody.state = "SHOWN";
        });
    }

    // 10% step calculation = 90% overlap clearance deck layout
    function positionNotificationsDeck() {
        let currentY = rootItem.overlaysHeightBaseline;
        let cardsList = (typeof activeCards !== "undefined") ? activeCards : rootItem.activeCards;
        if (!cardsList) return;

        for (let i = 0; i < cardsList.length; i++) {
            let card = cardsList[i];
            card.currentQueueIndex = i;
            card.stackIndex = i;

            // Offset the baseline position down slightly
            card.targetY = currentY + 125;
            card.animateToStackPosition();

            currentY += (rootItem.cardHeight * 0.10);
        }
    }

    function animateToStackPosition() {
        if (!entryPhaseCompleted) return;

        // When targetY changes, popupCardBody.y updates automatically via its state expression
        if (popupCardBody.state === "SHOWN") {
            popupCardBody.y = targetY;
        }
    }

    function startExitAnimation() {
        holdCountdownTimer.stop();
        popupCardBody.state = "DISMISSED";
    }

    Timer {
        id: holdCountdownTimer
        interval: rootItem.holdDurationMs
        repeat: false
        running: cardWindow.entryPhaseCompleted
        && cardWindow.stackIndex === 0
        && !cardWindow.isCriticalCard

        onTriggered: {
            controller.dismiss(cardWindow)
        }
    }

    Rectangle {
        z: cardWindow.stackIndex
        id: popupCardBody
        width: rootItem.cardWidth
        height: rootItem.cardHeight
        radius: 10
        color: shell.theme.base00
        border.width: rootItem.cardBorderWidth
        border.color: cardWindow.isManualDismiss
        ? shell.theme.base08
        : normalBorderColor
        clip: true
        opacity: 1.0
        // INTERNAL SELF-CONTAINED FLIGHT TRACK ENGINE
        states: [
            State {
                name: "SHOWN"
                PropertyChanges { target: popupCardBody; x: cardWindow.shownX; y: cardWindow.targetY }
            },
            State {
                name: "DISMISSED"
                PropertyChanges { target: popupCardBody; y: cardWindow.targetY + 500 } // Drop straight down to exit
            }
        ]

        transitions: [
            Transition {
                from: ""
                to: "SHOWN"
                SequentialAnimation {
                    // Stage 1: Slide horizontally in from right
                    NumberAnimation { property: "x"; duration: 350; easing.type: Easing.OutQuad }
                    // Stage 2: Drop onto resting deck line height floor
                    NumberAnimation { property: "y"; duration: 300; easing.type: Easing.OutCubic }
                    ScriptAction {
                        script: {
                            cardWindow.entryPhaseCompleted = true;
                            cardWindow.positionNotificationsDeck();
                        }
                    }
                }
            },
            Transition {
                from: "SHOWN"
                to: "DISMISSED"
                NumberAnimation { property: "y"; duration: 300; easing.type: Easing.OutCubic }
                ScriptAction {
                    script: cardWindow.destroy();
                }
            },
            // Handles fluid vertical re-stacking movements when targetY updates
            Transition {
                from: "SHOWN"
                to: "SHOWN"
                NumberAnimation { property: "y"; duration: 250; easing.type: Easing.OutCubic }
            }
        ]

        MouseArea {
            anchors.fill: parent
            onClicked: {
                controller.activate(cardWindow, notification);
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            Column {
                width: parent.width
                height: parent.height
                spacing: 4

                Text {
                    id: summaryText
                    text: notification.summary || ""
                    width: parent.width
                    color: cardWindow.isCriticalCard ? shell.theme.base08 : shell.theme.base05
                    font.bold: true
                    font.pixelSize: rootItem.textSummarySize
                    font.family: shell.theme.fontFamily
                    elide: Text.ElideRight
                }

                Text {
                    text: notification.body || ""
                    width: parent.width
                    color: cardWindow.isCriticalCard ? shell.theme.base08 : shell.theme.base05
                    font.pixelSize: rootItem.textBodySize
                    font.family: shell.theme.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                }
            }
        }
    }
}
