import QtQuick
import QtQuick.Controls 2

Item {
    id: animationRoot

    // ============================================================================
    // ⚙️ CUSTOMIZABLE CONFIGURATION ZONE (EDIT THESE VALUES)
    // ============================================================================

    property int distanceFromTopBeforeStopping: 300
    property int distanceFromRightBeforeStopping: 30
    property int cardOverhangStep: 15
    property int holdDurationMs: 2000
    property int slideInDurationMs: 250

    // ============================================================================
    // 🧠 CORE ENGINE LAYERS (DO NOT TOUCH)
    // ============================================================================
    property int index: 0
    property int totalCount: 0
    property Item targetItem: null
    property bool entranceFinished: false

    // TAG: Stores whether this specific notification card has an urgent priority flag
    property bool isUrgentCard: false

    signal timeoutTriggered(var itemInstance)

    Binding {
        target: animationRoot.targetItem
        property: "y"
        value: animationRoot.entranceFinished
        ? (animationRoot.distanceFromTopBeforeStopping + ((totalCount - 1 - index) * animationRoot.cardOverhangStep))
        : animationRoot.distanceFromTopBeforeStopping

        Behavior on value {
            SpringAnimation {
                spring: 2.8; damping: 0.75; mass: 1.0
            }
        }
    }

    onIndexChanged: {
        // Only kickstart the dismissal timer if the card is at the top AND is NOT marked urgent
        if (index === 0 && entranceFinished && !isUrgentCard) {
            autoDismissTimer.start();
        }
    }

    Timer {
        id: autoDismissTimer
        interval: animationRoot.holdDurationMs
        running: false
        repeat: false
        onTriggered: {
            animationRoot.timeoutTriggered(animationRoot.targetItem);
        }
    }

    function stopTimer() { autoDismissTimer.stop(); }

    function restartTimer() {
        if (index === 0 && !isUrgentCard) {
            autoDismissTimer.restart();
        }
    }

    Component.onCompleted: {
        if (!targetItem) return;
        targetItem.z = totalCount - index;
        targetItem.x = targetItem.parent.width + 50;
        targetItem.y = animationRoot.distanceFromTopBeforeStopping;
        targetItem.opacity = 0;
        entranceChoreography.start();
    }

    SequentialAnimation {
        id: entranceChoreography
        ParallelAnimation {
            NumberAnimation {
                target: animationRoot.targetItem; property: "x"
                to: animationRoot.targetItem.parent.width - animationRoot.targetItem.width - animationRoot.distanceFromRightBeforeStopping
                duration: animationRoot.slideInDurationMs; easing.type: Easing.OutQuad
            }
            NumberAnimation { target: animationRoot.targetItem; property: "opacity"; to: 1; duration: 150 }
        }
        ScriptAction {
            script: {
                animationRoot.entranceFinished = true;
                // Only automatically trigger the auto-dismiss timer on entrance if it's NOT urgent
                if (animationRoot.index === 0 && !animationRoot.isUrgentCard) {
                    autoDismissTimer.start();
                }
            }
        }
    }
}
