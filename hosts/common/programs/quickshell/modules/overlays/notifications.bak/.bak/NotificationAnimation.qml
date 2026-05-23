import QtQuick

Item {
    id: root

    // ============================================================================
    // 📡 SIGNALS
    // ============================================================================

    signal entryAnimationFinished()
    signal timeoutTriggered(var itemRef)

    // ============================================================================
    // 🔗 TARGETS
    // ============================================================================

    property var targetItem: null

    property int index: 0
    property int totalCount: 0

    property bool isUrgentCard: false

    // ============================================================================
    // 🎛️ CONFIG
    // ============================================================================

    // horizontal slide speed
    property int entryDuration: 380

    // offscreen spawn point
    property int startX: 520

    // resting visible position
    property int shownX: 0

    // ============================================================================
    // 🚀 ENTRY
    // ============================================================================

    function playEntryAnimation() {
        if (!targetItem)
            return;

        targetItem.opacity = 1;

        // spawn offscreen
        targetItem.x = root.startX;

        // ONLY animate X
        // vertical movement handled by compositor
        entryAnimation.start();
    }

    // ============================================================================
    // 🧹 TIMER PLACEHOLDERS
    // ============================================================================

    function stopTimer() {
    }

    function restartTimer() {
    }

    // ============================================================================
    // 🎬 ENTRY ANIMATION
    // ============================================================================

    NumberAnimation {
        id: entryAnimation

        target: root.targetItem
        property: "x"

        from: root.startX
        to: root.shownX

        duration: root.entryDuration

        easing.type: Easing.OutCubic

        onFinished: {
            root.entryAnimationFinished();
        }
    }
}
