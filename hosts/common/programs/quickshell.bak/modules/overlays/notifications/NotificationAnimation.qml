import QtQuick

Item {
    id: root

    visible: false

    // ============================================================================
    // TARGET PIPELINES
    // ============================================================================
    property var targetItem

    property int entryDuration: 350
    property int stackDuration: 300
    property int exitDuration: 350

    property real hiddenX: 700
    property real shownX: 0

    // ============================================================================
    // ENTRY MOTION (SMOOTH OUT TRIPS WITH OUT_QUAD)
    // ============================================================================
    function playEntryAnimation(targetY) {
        if (!targetItem) return

            targetItem.opacity = 1
            targetItem.x = hiddenX
            targetItem.y = targetY + 40

            entryAnimation.targetY = targetY
            entryAnimation.start()
    }

    SequentialAnimation {
        id: entryAnimation
        property real targetY: 0

        ParallelAnimation {
            NumberAnimation {
                target: root.targetItem
                property: "x"
                to: root.shownX
                duration: root.entryDuration
                easing.type: Easing.OutQuad
            }
        }

        NumberAnimation {
            target: root.targetItem
            property: "y"
            to: entryAnimation.targetY
            duration: root.stackDuration
            easing.type: Easing.OutCubic
        }
    }

    // ============================================================================
    // EXIT MOTION
    // ============================================================================
    function playExitAnimation(callback) {
        if (!targetItem) return

            exitAnimation.callback = callback
            exitAnimation.start()
    }

    SequentialAnimation {
        id: exitAnimation
        property var callback

        ParallelAnimation {
            NumberAnimation {
                target: root.targetItem
                property: "x"
                to: root.hiddenX + 200
                duration: root.exitDuration
                easing.type: Easing.InQuad
            }
        }

        onFinished: {
            if (callback) callback()
        }
    }
}
