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

    // Holds the local file path of the cached avatar once extracted
    property string cachedAvatarPath: ""

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

    // Helper to sanitize and de-duplicate long raw URLs inside popup cards
    function getCleanBodyText(rawBody) {
        if (!rawBody) return "";
        var cleanBody = rawBody.trim();

        var regex = /(https?:\/\/[^\s<]+)/g;
        var match = cleanBody.match(regex);
        var url = match ? match[0] : "";

        // If the body is exactly a URL, replace it with a clean placeholder
        if (cleanBody === url) {
            return "🔗 Shared Link";
        }

        return rawBody;
    }

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
        interval: rootItem ? rootItem.holdDurationMs : 5000
        repeat: false
        running: cardWindow.entryPhaseCompleted
        && cardWindow.stackIndex === 0
        && !cardWindow.isCriticalCard

        onTriggered: {
            // Only trigger the exit animation, do not clear data yet
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
                    if (status === Image.Ready) {
                        // Asynchronously grab and cache temporary D-Bus avatars to local persistent storage
                        if (source.toString().includes("image://qsimage")) {
                            notificationIcon.grabToImage(function(result) {
                                var safeName = encodeURIComponent(notification.summary || "user").replace(/%/g, "_");
                                var localPath = "/tmp/qs_avatar_" + safeName + ".png";
                                if (result.saveToFile(localPath)) {
                                    cardWindow.cachedAvatarPath = "file://" + localPath;
                                }
                            });
                        }
                    } else if (status === Image.Error) {
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
                    // Sanitizes raw URLs into neat placeholders on active popup cards
                    text: notification ? cardWindow.getCleanBodyText(notification.body) : ""
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
                // Entrance slide duration set to 150ms for instantaneous popup appearance
                NumberAnimation { property: "x"; duration: 150; easing.type: Easing.OutCubic }
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
                // Exit slide duration set to 120ms for snappy dismissal
                NumberAnimation { property: "x"; duration: 120; easing.type: Easing.InQuad }
                ScriptAction {
                    script: {
                        // Remove from active model and write to history ONLY after
                        // the card is fully animated off-screen to prevent visual blinking.
                        if (rootItem) {
                            rootItem.closeNotificationTrack(cardWindow);
                        }
                        Qt.callLater(cardWindow.destroy);
                    }
                }
            }
        }
    ]

    Behavior on y {
        SequentialAnimation {
            // Restacking delays (Pause: 50ms, Duration: 150ms) so card-shifts occur instantly
            PauseAnimation { duration: 50 }
            NumberAnimation {
                duration: 150;
                easing.type: Easing.OutCubic
            }
        }
    }
}
