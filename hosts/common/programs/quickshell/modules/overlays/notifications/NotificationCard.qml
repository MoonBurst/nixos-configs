// NotificationCard.qml
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

    property var originalNotification: null
    property string cachedAvatarPath: ""
    property real targetY: rootItem ? rootItem.overlaysHeightBaseline : 250
    property int stackIndex: 0
    property bool entryPhaseCompleted: false
    property bool isManualDismiss: false
    property bool isCriticalCard: rulesLoader ? rulesLoader.getIsUrgent(notification) : false

    // Filter out the generic "default" / "View" action so only real buttons show
    readonly property var explicitActions: {
        if (!notification || !notification.actions) return [];
        var acts = [];
        for (var i = 0; i < notification.actions.length; i++) {
            var act = notification.actions[i];
            if (act && act.identifier !== "default" && act.identifier !== "") {
                acts.push(act);
            }
        }
        return acts;
    }

    readonly property bool hasActions: explicitActions.length > 0

    property color normalBorderColor: isCriticalCard
        ? shell.theme.base08
        : (rulesLoader ? rulesLoader.getBorderColor(notification, shell.theme, shell.theme.base05) : shell.theme.base05)

    width: rootItem ? rootItem.cardWidth : 420
    // Only expand height if real action buttons (like Approve/Deny) exist
    height: hasActions ? (rootItem ? rootItem.cardHeight + 45 : 185) : (rootItem ? rootItem.cardHeight : 140)
    x: hiddenX
    y: targetY

    property int hiddenX: width + 50
    property int shownX: 0

    z: cardWindow.state === "DISMISSED"
        ? 1000
        : (cardWindow.stackIndex === 0 ? 999 : (100 - cardWindow.stackIndex))

    function getCleanBodyText(rawBody) {
        if (!rawBody) return "";
        var cleanBody = rawBody.trim();
        var regex = /(https?:\/\/[^\s<]+)/g;
        var match = cleanBody.match(regex);
        var url = match ? match[0] : "";
        if (cleanBody === url) {
            return "🔗 Shared Link";
        }
        return rawBody;
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
            && !cardWindow.hasActions
        onTriggered: {
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
                width: visible ? 80 : 0
                height: 80
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                smooth: true
                source: (cardWindow.cachedAvatarPath !== "")
                    ? cardWindow.cachedAvatarPath
                    : (rulesLoader ? rulesLoader.getCustomIcon(notification) : "")
                visible: source !== undefined && source !== null && source !== "" && status !== Image.Error
            }

            Column {
                width: parent.width - notificationIcon.width - (notificationIcon.visible ? parent.spacing : 0)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    id: summaryText
                    text: notification ? (notification.summary || "") : ""
                    width: parent.width
                    color: cardWindow.isCriticalCard ? shell.theme.base08 : shell.theme.base05
                    font.bold: true
                    font.pixelSize: rootItem ? rootItem.textSummarySize : 18
                    font.family: shell.theme.fontFamily
                    elide: Text.ElideRight
                }

                Text {
                    text: notification ? cardWindow.getCleanBodyText(notification.body) : ""
                    width: parent.width
                    color: cardWindow.isCriticalCard ? shell.theme.base08 : shell.theme.base05
                    font.pixelSize: rootItem ? rootItem.textBodySize - 2 : 14
                    font.family: shell.theme.fontFamily
                    wrapMode: Text.WordWrap
                    maximumLineCount: cardWindow.hasActions ? 2 : 3
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }

                // Interactive Action Buttons (ONLY shown for explicit actions like Approve / Deny)
                Row {
                    spacing: 10
                    visible: cardWindow.hasActions
                    z: 100

                    Repeater {
                        model: cardWindow.explicitActions
                        delegate: Rectangle {
                            id: actBtn
                            readonly property bool isDeny: modelData.identifier.toLowerCase().indexOf("deny") !== -1
                            width: actText.implicitWidth + 24
                            height: 32
                            radius: 6
                            color: actMouse.containsMouse 
                                ? (isDeny ? "#FF0000" : "#04f100") 
                                : "#1e1e2e"
                            border.width: 1.5
                            border.color: isDeny ? "#FF5555" : "#04f100"

                            Text {
                                id: actText
                                anchors.centerIn: parent
                                text: modelData.text || modelData.identifier
                                font.family: shell.theme ? shell.theme.fontFamily : "monospace"
                                font.pixelSize: 13
                                font.bold: true
                                color: actMouse.containsMouse ? "#000000" : (isDeny ? "#FF5555" : "#04f100")
                            }

                            MouseArea {
                                id: actMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData && typeof modelData.invoke === "function") {
                                        modelData.invoke();
                                    }
                                    cardWindow.startExitAnimation();
                                }
                            }
                        }
                    }
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
                NumberAnimation { property: "x"; duration: 120; easing.type: Easing.InQuad }
                ScriptAction {
                    script: {
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
            PauseAnimation { duration: 50 }
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }
}
