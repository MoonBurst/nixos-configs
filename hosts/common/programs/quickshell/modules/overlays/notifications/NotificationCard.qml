import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland

Item {
    id: cardWindow

    required property var notification
    required property var rulesLoader
    required property var rootItem
    required property var controller

    // CRITICAL FIX: Explicitly expose the tracking variable property handle line.
    // This allows NotificationOverlay to pin the live un-garbage-collected C++
    // object context straight to this visual element layer instance structure.
    property var originalNotification: null

    property real targetY: rootItem ? rootItem.overlaysHeightBaseline : 250
    property int stackIndex: 0

    property bool entryPhaseCompleted: false
    property bool isManualDismiss: false

    property bool isCriticalCard: rulesLoader ? rulesLoader.getIsUrgent(notification) : false

    property color normalBorderColor: isCriticalCard
    ? shell.theme.base08
    : (rulesLoader ? rulesLoader.getBorderColor(notification, shell.theme, shell.theme.base05) : shell.theme.base05)

    width: rootItem ? rootItem.cardWidth : 400
    height: rootItem ? rootItem.cardHeight : 140

    x: hiddenX
    y: targetY

    property int hiddenX: width + 50
    property int shownX: 0

    z: cardWindow.state === "DISMISSED"
    ? 1000
    : (cardWindow.stackIndex === 0 ? 999 : (100 - cardWindow.stackIndex))

    function animateToStackPosition() {
        // Automatically handled by the Behavior animation on the y property below
    }

    function startExitAnimation() {
        holdCountdownTimer.stop();
        cardWindow.state = "DISMISSED";
    }

    Component.onCompleted: {
        cardWindow.state = "SHOWN";
    }

    Timer {
        id: holdCountdownTimer
        interval: rootItem ? rootItem.holdDurationMs : 500
        repeat: false
        running: cardWindow.entryPhaseCompleted
        && cardWindow.stackIndex === 0
        && !cardWindow.isCriticalCard

        onTriggered: {
            if (rootItem) {
                rootItem.closeNotificationTrack(cardWindow);
            }
            cardWindow.startExitAnimation();
        }
    }

    Rectangle {
        id: popupCardBody
        anchors.fill: parent
        radius: 10
        color: shell.theme.base00
        border.width: rootItem ? rootItem.cardBorderWidth : 3
        border.color: cardWindow.isManualDismiss ? shell.theme.base08 : normalBorderColor
        clip: true

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (controller) {
                    controller.activate(cardWindow, notification);
                }
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            Image {
                id: notificationIcon
                width: visible ? 100 : 0
                height: 100
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                smooth: true
                source: rulesLoader ? rulesLoader.getCustomIcon(notification) : ""
                visible: source !== undefined && source !== null && source !== "" && status !== Image.Error

                onStatusChanged: {
                    if (status === Image.Error) {
                        visible = false;
                    }
                }
            }

            Column {
                width: parent.width - notificationIcon.width - (notificationIcon.visible ? parent.spacing : 0)
                height: parent.height
                spacing: 4

                Text {
                    id: summaryText
                    text: notification ? (notification.summary || "") : ""
                    width: parent.width
                    color: cardWindow.isCriticalCard ? shell.theme.base08 : shell.theme.base05
                    font.bold: true
                    font.pixelSize: rootItem ? rootItem.textSummarySize : 20
                    font.family: shell.theme.fontFamily
                    elide: Text.ElideRight
                }

                Text {
                    text: notification ? (notification.body || "") : ""
                    width: parent.width
                    color: cardWindow.isCriticalCard ? shell.theme.base08 : shell.theme.base05
                    font.pixelSize: rootItem ? rootItem.textBodySize : 20
                    font.family: shell.theme.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    textFormat: Text.RichText
                }
            }
        }
    }

    states: [
        State {
            name: "SHOWN"
            PropertyChanges { target: cardWindow; x: cardWindow.shownX }
        },
        State {
            name: "DISMISSED"
            PropertyChanges { target: cardWindow; x: cardWindow.hiddenX }
        }
    ]

    transitions: [
        Transition {
            from: ""
            to: "SHOWN"
            SequentialAnimation {
                NumberAnimation { property: "x"; duration: 350; easing.type: Easing.OutCubic }
                ScriptAction {
                    script: {
                        cardWindow.entryPhaseCompleted = true;
                    }
                }
            }
        },
        Transition {
            from: "SHOWN"
            to: "DISMISSED"
            SequentialAnimation {
                NumberAnimation { property: "x"; duration: 250; easing.type: Easing.InQuad }
                ScriptAction {
                    script: {
                        Qt.callLater(cardWindow.destroy);
                    }
                }
            }
        }
    ]

    Behavior on y {
        SequentialAnimation {
            PauseAnimation { duration: 250 }
            NumberAnimation {
                duration: 300;
                easing.type: Easing.OutCubic
            }
        }
    }
}
