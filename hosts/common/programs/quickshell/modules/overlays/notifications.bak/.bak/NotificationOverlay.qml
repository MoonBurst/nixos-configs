import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "." as Local

Item {
    id: root
    anchors.fill: parent

    // ============================================================================
    // 🎛️ GLOBAL CONFIGURATION
    // These are the main values you'll tweak for layout and sizing.
    // ============================================================================

    // Main resting Y position of the newest notification
    property int overlaysHeightBaseline: 200

    // Notification card dimensions
    property int cardWidth: 400
    property int cardHeight: 150

    // Border thickness
    property int cardBorderWidth: 3

    // Text sizing
    property int textSummarySize: 20
    property int textBodySize: 20

    // ============================================================================
    // 🧠 CORE STATE STORAGE
    // Stores active notifications and shared shell references.
    // ============================================================================

    property var theme: null

    // Array containing every active notification window
    property var notifications: []

    // ============================================================================
    // 📜 RULES ENGINE
    // Handles:
    // - urgency detection
    // - custom sounds
    // - border colors
    // - custom icons
    // ============================================================================

    Local.NotificationRules {
        id: rulesLoader
    }

    // ============================================================================
    // 📥 NEW NOTIFICATION INGESTION
    // Called externally whenever a notification arrives.
    // ============================================================================

    function handleNotification(notification) {

        console.log(
            "handleNotification called:",
            notification && notification.summary,
            notification && notification.body
        );

        // If notification already exists, update it
        let existing = root.notifications.find(
            n => n.notification
            && n.notification.id === notification.id
        );

        if (existing) {

            existing.update(notification);

        } else {

            // Create a new floating notification window
            let newNotification =
            notificationComponent.createObject(
                root,
                {
                    notification: notification
                }
            );

            // Add newest notification to FRONT of array
            // This helps keep newer cards visually underneath
            root.notifications.unshift(newNotification);

            // Recalculate stack positions
            positionNotifications();

            // Trigger rules/sounds/etc
            rulesLoader
            .handleIncomingNotificationCues(
                notification
            );
        }
    }

    // ============================================================================
    // 🃏 STACK POSITIONING ENGINE
    // Controls:
    // - vertical stacking
    // - overlap depth
    // - z layering
    // ============================================================================

    function positionNotifications() {

        let totalCount = root.notifications.length;

        for (var i = 0; i < totalCount; i++) {

            let item = root.notifications[i];

            if (!item)
                continue;

            // Newest card = index 0
            let distanceFromNewest = i;

            // Stack cards upward with overlap
            item.targetY =
            150 + (distanceFromNewest * 18);

            // Older cards get higher z
            // Newer cards stay underneath
            item.layerZ = i;

            item.stackIndex = i;

            // Animate card toward stack target
            item.animateToStackPosition();

            // Force compositor restack
            // Helps wlroots place older cards above
            item.visible = false;
            item.visible = true;
        }
    }

    // ============================================================================
    // ❌ NOTIFICATION DISMISSAL
    // Handles:
    // - manual dismiss
    // - timeout dismiss
    // - stack reordering
    // ============================================================================

    function closeNotification(
        itemInstance,
        isManualClick
    ) {

        if (!itemInstance)
            return;

        let index =
        root.notifications.indexOf(
            itemInstance
        );

        if (index !== -1) {

            // Marks border red on manual dismiss
            itemInstance.isManualDismiss =
            isManualClick;

            // Starts exit animation
            root.notifications[index]
            .startExitAnimation();

            // Remove from stack
            root.notifications.splice(index, 1);

            // Recalculate stack
            positionNotifications();
        }
    }

    // ============================================================================
    // 🐋 NOTIFICATION WINDOW TEMPLATE
    // Every notification becomes one floating PanelWindow.
    // ============================================================================

    Component {

        id: notificationComponent

        PanelWindow {

            id: cardWindow

            // Raw notification object
            required property var notification

            // ============================================================================
            // 📦 STACK / STATE VARIABLES
            // ============================================================================

            // Current target Y position
            property real targetY:
            root.overlaysHeightBaseline

            // Stack ordering index
            property int stackIndex: 0

            // Visual z depth
            property int layerZ: 1000

            // True if manually dismissed
            property bool isManualDismiss: false

            // True after entry animation completes
            property bool entryPhaseCompleted: false

            // ============================================================================
            // 🚨 RULE-DERIVED STATE
            // ============================================================================

            // Urgent notifications stay longer
            property bool isCriticalCard:
            rulesLoader.getIsUrgent(notification)

            // Direct image attachment
            property var notificationImageSource:
            notification.image
            ? notification.image
            : null

            // Rule-generated icon fallback
            property string fallbackIconSource:
            rulesLoader.getCustomIcon(
                notification,
                "image://icon/"
                + (
                    notification.appIcon
                    || "fallback"
                )
            )

            // Border coloring logic
            property color normalBorderColor:
            isCriticalCard
            ? shell.theme.base08
            : rulesLoader.getBorderColor(
                notification,
                shell.theme,
                shell.theme.base05
            )

            // ============================================================================
            // 🎬 ANIMATION VARIABLES
            // ============================================================================

            // Starting Y during entry animation
            property int entryInitialHeightY: 0

            // Offscreen X position
            property int hiddenX:
            root.cardWidth + 50

            // ============================================================================
            // 🖥️ WINDOW TARGET SCREEN
            // ============================================================================

            screen:
            Quickshell.screens.find(
                s => s.name === "DP-2"
            )

            anchors.top: true
            anchors.right: true
            anchors.left: false
            anchors.bottom: false

            // ============================================================================
            // 📐 WINDOW DIMENSIONS
            // ============================================================================

            implicitWidth:
            root.cardWidth + 50

            implicitHeight:
            root.cardHeight + 1080

             color: "transparent"

            // ============================================================================
            // 🌊 WAYLAND LAYER-SHELL SETTINGS
            // ============================================================================

            WlrLayershell.layer:
            WlrLayer.Overlay

            WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None

            // ============================================================================
            // 🎭 CLICK-THROUGH MASK
            // Only card body receives clicks.
            // Everything else passes through.
            // ============================================================================

            mask: Region {
                item: popupCardBody
            }

            // ============================================================================
            // 📍 WINDOW POSITIONING
            // ============================================================================

            // Vertical offset
            WlrLayershell.margins.top:
            cardWindow.targetY

            // Right edge spacing
            WlrLayershell.margins.right:
            shell.theme.globalPadding

            // ============================================================================
            // 🧲 STACK POSITION ANIMATION
            // Smoothly moves cards during reordering.
            // ============================================================================

            function animateToStackPosition() {

                windowMovementAnimation.stop();

                windowMovementAnimation.to =
                targetY;

                windowMovementAnimation.start();
            }

            // ============================================================================
            // 🚪 EXIT ANIMATION
            // ============================================================================

            function startExitAnimation() {

                animHook.stopTimer();

                exitAnimation.start();
            }

            // ============================================================================
            // ↕️ STACK MOVEMENT ANIMATION
            // ============================================================================

            NumberAnimation {

                id: windowMovementAnimation

                target: cardWindow

                property: "targetY"

                duration: 300

                easing.type: Easing.OutQuad
            }

            // ============================================================================
            // ➡️ EXIT MOTION
            // Slides card back to the right.
            // ============================================================================

            ParallelAnimation {

                id: exitAnimation

                NumberAnimation {
                    target: popupCardBody
                    property: "x"
                    to: cardWindow.hiddenX
                    duration: 220
                    easing.type: Easing.InQuad
                }

                NumberAnimation {
                    target: popupCardBody
                    property: "opacity"
                    to: 0
                    duration: 150
                }

                onFinished:
                cardWindow.destroy()
            }

            // ============================================================================
            // ⏲️ AUTO-DISMISS TIMER
            // Only newest non-urgent card auto-dismisses.
            // ============================================================================

            Timer {

                id: localizedDismissTimer

                interval: 2000

                repeat: false

                running:
                !cardWindow.isCriticalCard
                && cardWindow.stackIndex === 0
                && cardWindow.entryPhaseCompleted

                onTriggered:
                root.closeNotification(
                    cardWindow,
                    false
                )
            }

            // ============================================================================
            // 🖼️ ICON DETECTION
            // ============================================================================

            function hasIcon(n) {

                if (!n)
                    return false;

                if (n.image)
                    return true;

                if (n.icon
                    && n.icon.trim() !== "")
                    return true;

                if (
                    n.hints
                    && (
                        n.hints["image-path"]
                        || n.hints["image_path"]
                    )
                )
                    return true;

                    if (
                        rulesLoader.findActiveProfile(n)
                        !== null
                    )
                        return true;

                        return false;
            }

            // ============================================================================
            // 🧭 ICON SOURCE RESOLUTION
            // Determines what image gets displayed.
            // ============================================================================

            function getIconSource(n) {

                if (!n)
                    return "";

                if (n.image)
                    return n.image;

                let characterPortrait =
                rulesLoader.getCustomIcon(
                    n,
                    ""
                );

                if (characterPortrait !== "")
                    return characterPortrait;

                if (
                    n.hints
                    && n.hints["image-path"]
                )
                    return n.hints["image-path"]
                    .startsWith("/")
                    ? "file://"
                    + n.hints["image-path"]
                    : n.hints["image-path"];

                    if (
                        n.hints
                        && n.hints["image_path"]
                    )
                        return n.hints["image_path"]
                        .startsWith("/")
                        ? "file://"
                        + n.hints["image_path"]
                        : n.hints["image_path"];

                        if (
                            n.icon
                            && n.icon.trim() !== ""
                            && !n.icon.startsWith("/")
                            && !n.icon.startsWith("file://")
                            && !n.icon.startsWith("image://")
                        ) {
                            return "file://"
                            + rulesLoader.resourcePath
                            + "/fallback.png";
                        }

                        if (
                            n.icon
                            && n.icon.trim() !== ""
                        ) {
                            return (
                                n.icon.startsWith("/")
                                || n.icon.startsWith("file://")
                            )
                            ? (
                                n.icon.startsWith("/")
                                ? "file://" + n.icon
                                : n.icon
                            )
                            : "image://icon/" + n.icon;
                        }

                        return "file://"
                        + rulesLoader.resourcePath
                        + "/fallback.png";
            }

            // ============================================================================
            // 🎴 ACTUAL VISIBLE CARD
            // ============================================================================

            Rectangle {

                id: popupCardBody

                width: root.cardWidth
                height: root.cardHeight

                radius: 10

                color: shell.theme.base00

                border.width:
                root.cardBorderWidth

                border.color:
                isManualDismiss
                ? shell.theme.base08
                : normalBorderColor

                clip: true

                opacity: 0

                // Starts offscreen right
                x: cardWindow.hiddenX

                // Visual layering
                z: cardWindow.layerZ

                // ============================================================================
                // 🎞️ EXTERNAL ANIMATION ENGINE
                // ============================================================================

                Local.NotificationAnimation {

                    id: animHook

                    targetItem: popupCardBody

                    index: cardWindow.stackIndex

                    totalCount:
                    root.notifications.length

                    isUrgentCard:
                    cardWindow.isCriticalCard

                    onEntryAnimationFinished: {

                        cardWindow.entryPhaseCompleted = true;

                        root.positionNotifications();
                    }
                }

                // ============================================================================
                // 🚀 ENTRY ANIMATION START
                // ============================================================================

                Component.onCompleted: {

                    Qt.callLater(function() {

                        animHook.playEntryAnimation(
                            cardWindow.entryInitialHeightY
                        )
                    })
                }

                // ============================================================================
                // 📦 CARD CONTENT LAYOUT
                // ============================================================================

                Row {

                    anchors.fill: parent
                    anchors.margins: 10

                    spacing: 12

                    // ============================================================================
                    // 🖼️ ICON
                    // ============================================================================

                    Image {

                        id: notificationIcon

                        width: 100
                        height: 100

                        anchors.verticalCenter:
                        parent.verticalCenter

                        fillMode:
                        Image.PreserveAspectFit

                        source:
                        cardWindow.getIconSource(
                            notification
                        )

                        visible:
                        cardWindow.hasIcon(
                            notification
                        )
                    }

                    // ============================================================================
                    // 📝 TEXT CONTENT
                    // ============================================================================

                    Column {

                        width:
                        notificationIcon.visible
                        ? parent.width - 112
                        : parent.width

                        height: parent.height

                        spacing: 4

                        // ============================================================================
                        // 📰 SUMMARY TITLE
                        // ============================================================================

                        Text {

                            id: summary

                            width: parent.width

                            text:
                            notification.summary
                            || ""

                            color:
                            shell.theme.base05

                            font.bold: true

                            font.pixelSize:
                            root.textSummarySize

                            font.family:
                            shell.theme.fontFamily

                            elide: Text.ElideRight
                        }

                        // ============================================================================
                        // 📄 BODY TEXT
                        // ============================================================================

                        Text {

                            id: body

                            width: parent.width

                            height:
                            parent.height
                            - summary.height
                            - 4

                            text:
                            notification.body
                            || ""

                            color:
                            shell.theme.base05

                            font.pixelSize:
                            root.textBodySize

                            font.family:
                            shell.theme.fontFamily

                            wrapMode:
                            Text.WordWrap

                            elide:
                            Text.ElideRight
                        }
                    }
                }

                // ============================================================================
                // 🖱️ CLICK HANDLER
                // Manual dismiss interaction.
                // ============================================================================

                MouseArea {

                    anchors.fill: parent

                    onClicked:
                    root.closeNotification(
                        cardWindow,
                        true
                    )
                }
            }

            // ============================================================================
            // 🔄 UPDATE EXISTING NOTIFICATION
            // ============================================================================

            function update(newNotification) {

                notification = newNotification;

                summary.text =
                newNotification.summary;

                body.text =
                newNotification.body;

                notificationIcon.source =
                cardWindow.getIconSource(
                    newNotification
                );

                animHook.restartTimer();
            }
        }
    }
}
