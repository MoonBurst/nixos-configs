import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import "." as Local

PanelWindow {
    id: cardWindow

    // Injected property signatures pushed down from our root tracking container loop
    required property var notificationOverlayRef
    required property var notification

    // ============================================================================
    // 🎛️ SELF-CONTAINED GEOMETRY & TRANSITION VARIABLE MATRIX
    // ============================================================================
    property real targetY: 400
    property int stackIndex: 0
    property int layerZ: 1000
    property bool isManualDismiss: false
    property bool entryPhaseCompleted: false

    // Target metrics pull cleanly using your unified tracking container hooks
    property bool isCriticalCard: notificationOverlayRef.rulesLoader.getIsUrgent(notification)
    property var notificationImageSource: notification.image ? notification.image : null
    property string fallbackIconSource: notificationOverlayRef.rulesLoader.getCustomIcon(notification, "image://icon/" + (notification.appIcon || "fallback"))
    property color normalBorderColor: isCriticalCard ? shell.theme.base08 : notificationOverlayRef.rulesLoader.getBorderColor(notification, shell.theme, shell.theme.base05)

    // Layout configuration size tokens matching your shared configuration zone
    property int entryInitialHeightY: 400
    property int visualCardBodyWidth: notificationOverlayRef.cardWidth
    property int cardHeight: notificationOverlayRef.cardHeight
    property int hiddenX: visualCardBodyWidth + 50  // Starting distance off-screen horizon
    property int shownX: 0                          // Final horizontal stopping alignment point

    // ============================================================================
    // SURFACE CONFIGURATION PROPERTIES
    // ============================================================================
    screen: Quickshell.screens.find(s => s.name === "DP-2")

    anchors.top: true
    anchors.right: true
    anchors.left: false
    anchors.bottom: false

    // Open up bounds wide enough to fit your horizontal entrances safely
    implicitWidth: visualCardBodyWidth + 50
    implicitHeight: cardHeight + 40
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ============================================================================
    // 🎭 PERFECT CLICK-THROUGH MASK REGION
    // ============================================================================
    mask: Region {
        item: popupCardBody
    }

    // Safely binds vertical shuffles inside the LayerShell property margins map array
    Binding {
        target: cardWindow.WlrLayershell.margins
        property: "top"
        value: cardWindow.targetY
    }

    Binding {
        target: cardWindow.WlrLayershell.margins
        property: "right"
        value: shell.theme.globalPadding
    }

    function animateToStackPosition() {
        if (entryPhaseCompleted) {
            windowMovementAnimation.stop();
            windowMovementAnimation.to = targetY;
            windowMovementAnimation.start();
        }
    }

    function startExitAnimation() {
        animHook.stopTimer(); // Ensure animation states do not trail on destruction
        exitAnimation.start();
    }

    // Linear vertical queue position shuffler animation
    NumberAnimation {
        id: windowMovementAnimation
        target: cardWindow
        property: "targetY"
        duration: 300
        easing.type: Easing.OutQuad
    }

    // Entrance and exit velocity timelines handler
    ParallelAnimation {
        id: exitAnimation
        NumberAnimation { target: popupCardBody; property: "x"; to: cardWindow.hiddenX; duration: 220; easing.type: Easing.InQuad }
        NumberAnimation { target: popupCardBody; property: "opacity"; to: 0; duration: 150 }
        onFinished: cardWindow.destroy()
    }

    Timer {
        id: localizedDismissTimer
        interval: 2000
        repeat: false
        running: !cardWindow.isCriticalCard && cardWindow.stackIndex === 0 && cardWindow.entryPhaseCompleted
        onTriggered: notificationOverlayRef.closeNotification(cardWindow, false)
    }

    function hasIcon(n) {
        if (!n) return false;
        if (n.image || (n.icon && n.icon.trim() !== "")) return true;
        if (n.hints && (n.hints["image-path"] || n.hints["image_path"])) return true;
        return false;
    }

    function getIconSource(n) {
        if (!n) return "";
        if (n.image) return n.image;

        let characterPortrait = notificationOverlayRef.rulesLoader.getCustomIcon(n, "");
        if (characterPortrait !== "") return characterPortrait;

        if (n.hints && n.hints["image-path"]) return n.hints["image-path"].startsWith("/") ? "file://" + n.hints["image-path"] : n.hints["image-path"];
            if (n.hints && n.hints["image_path"]) return n.hints["image_path"].startsWith("/") ? "file://" + n.hints["image_path"] : n.hints["image_path"];
                if (n.icon && n.icon.trim() !== "") {
                    return (n.icon.startsWith("/") || n.icon.startsWith("file://")) ? (n.icon.startsWith("/") ? "file://" + n.icon : n.icon) : "image://icon/" + n.icon;
                }
                return "image://icon/dialog-information";
    }

    // ============================================================================
    // MAIN CARD VISIBLE RECTANGLE CONTAINER LAYER
    // ============================================================================
    Rectangle {
        id: popupCardBody
        width: cardWindow.visualCardBodyWidth
        height: cardWindow.cardHeight
        radius: 10
        color: shell.theme.base00
        border.width: notificationOverlayRef.cardBorderWidth
        border.color: isManualDismiss ? shell.theme.base08 : normalBorderColor
        clip: true

        opacity: 0
        x: cardWindow.hiddenX

        Local.NotificationAnimation {
            id: animHook
            targetItem: popupCardBody
            index: cardWindow.stackIndex
            totalCount: notificationOverlayRef.notifications.length
            isUrgentCard: cardWindow.isCriticalCard

            // FIXED: Removed the non-existent "shownX" property assignment to completely clear the compilation error!

            onEntryAnimationFinished: {
                cardWindow.entryPhaseCompleted = true;
                notificationOverlayRef.repositionNotifications();
            }
        }

        Component.onCompleted: {
            Qt.callLater(function() { animHook.playEntryAnimation(cardWindow.entryInitialHeightY) })
        }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            Image {
                id: notificationIcon
                width: 100
                height: 100
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                source: cardWindow.getIconSource(notification)
                visible: cardWindow.hasIcon(notification)
            }

            Column {
                width: notificationIcon.visible ? parent.width - 112 : parent.width
                height: parent.height
                spacing: 4

                Text {
                    id: summary
                    width: parent.width
                    text: notification.summary || ""
                    color: shell.theme.base05
                    font.bold: true
                    font.pixelSize: notificationOverlayRef.textSummarySize
                    font.family: shell.theme.fontFamily
                    elide: Text.ElideRight
                }

                Text {
                    id: body
                    width: parent.width
                    height: parent.height - summary.height - 4
                    text: notification.body || ""
                    color: shell.theme.base05
                    font.pixelSize: notificationOverlayRef.textBodySize
                    font.family: shell.theme.fontFamily
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: notificationOverlayRef.closeNotification(cardWindow, true)
        }
    }

    function update(newNotification) {
        notification = newNotification;
        summary.text = newNotification.summary;
        body.text = newNotification.body;
        notificationIcon.source = cardWindow.getIconSource(newNotification);
        animHook.restartTimer();
    }
}
