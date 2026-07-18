// SlantedTooltip.qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../style"

PanelWindow {
    id: tooltipWindow

    required property Item moduleItem
    required property var barWindow

    // Activation states (bind tooltipActive to hover trackers)
    property bool tooltipActive: false
    property bool pin: false

    // Geometry customizers
    property int tooltipHeight: 420
    property int collapsedCoreWidth: 130 // Starting flat-width
    property int expandedCoreWidth: 430  // Final flat-width
    property int topOffset: 0
    property int rightOffset: 18

    property string alignSide: "Right"

    // Keyboard Focus Options (WlrLayershell.None, WlrLayershell.Exclusive, etc.)
    property int keyboardFocus: WlrLayershell.None

    // Diagonal slant controls
    property string slantLeft: (moduleItem && typeof moduleItem.slantLeft !== "undefined") ? moduleItem.slantLeft : "Left"
    property string slantRight: (moduleItem && typeof moduleItem.slantRight !== "undefined") ? moduleItem.slantRight : "Left"
    property int slantWidth: (shell && shell.theme) ? (shell.theme.slantWidth || 12) : 12

    default property alias content: textWrapper.children

        WlrLayershell.exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-slanted-tooltip"
        WlrLayershell.keyboardFocus: tooltipWindow.visible ? tooltipWindow.keyboardFocus : WlrLayershell.None
        WlrLayershell.margins {
            top: tooltipWindow.targetTopMargin
            right: tooltipWindow.calculatedRightMargin
            left: tooltipWindow.calculatedLeftMargin
        }

        anchors.top: true
        anchors.left: alignSide === "Left"
        anchors.right: alignSide === "Right"

        screen: tooltipWindow.barWindow ? tooltipWindow.barWindow.screen : null

        // Controls window visibility and handles graceful collapsing transitions before hiding
        visible: (tooltipActive || pin || animContainer.animHeight > 0) && isReady && targetTopMargin > 0

        //  locked size bounds to prevent Wayland-side compositor stretching
        width: tooltipWidth
        height: tooltipHeight
        color: "transparent"

        // Internal shorthand properties
        readonly property bool isReady: moduleItem !== null && barWindow !== null && barWindow.width > 0

        // Calculate proportional slant parameters (guarded against early zero-height evaluations)
        readonly property real tooltipSlantWidth: (moduleItem && moduleItem.height > 0)
        ? (tooltipHeight * (slantWidth / moduleItem.height))
        : 15
        readonly property int tooltipWidth: expandedCoreWidth + tooltipSlantWidth

        // calculate  slant offsets at any given vertical coordinate
        function slantX(y) {
            if (slantLeft === "Right") {
                return (tooltipHeight - y) * (tooltipSlantWidth / tooltipHeight);
            } else if (slantLeft === "Left") {
                return y * (tooltipSlantWidth / tooltipHeight);
            }
            return 0; // "None" (Vertical)
        }

        // Coordinate mapping
        readonly property point mappedBottomRight: isReady
        ? moduleItem.mapToItem(null, moduleItem.width, moduleItem.height)
        : Qt.point(0, 0)

        //  target margin properties (prevents attached property lookup errors in the visibility binding)
        readonly property real targetTopMargin: isReady ? Math.round(mappedBottomRight.y) + topOffset : 0

        //  offsets window alignment based on whether the capsule leans left or right
        readonly property real calculatedRightMargin: (isReady && alignSide === "Right")
        ? Math.round(barWindow.width - mappedBottomRight.x + rightOffset - (slantRight === "Left" ? tooltipSlantWidth : 0))
        : 0

        readonly property real calculatedLeftMargin: (isReady && alignSide === "Left")
        ? Math.round(mappedBottomRight.x - moduleItem.width + rightOffset - (slantLeft === "Right" ? tooltipSlantWidth : 0))
        : 0

        property real animHeight: animContainer.animHeight

        // Layout boundary
        Item {
            id: animContainer
            anchors.left: tooltipWindow.alignSide === "Left" ? parent.left : undefined
            anchors.right: tooltipWindow.alignSide === "Right" ? parent.right : undefined
            anchors.top: parent.top
            width: parent.width
            height: parent.height

            // Control variables for the animation
            property real animHeight: 0
            property real visualCoreWidth: tooltipWindow.collapsedCoreWidth
            property real revealWidth: 0
            property real textOpacity: 0

            property bool isCompleted: false
            readonly property bool shouldExpand: isCompleted && (tooltipWindow.tooltipActive || tooltipWindow.pin)

            state: shouldExpand ? "expanded" : "collapsed"

            states: [
                State {
                    name: "collapsed"
                    PropertyChanges { target: animContainer; animHeight: 0; visualCoreWidth: tooltipWindow.collapsedCoreWidth; revealWidth: 0; textOpacity: 0 }
                },
                State {
                    name: "expanded"
                    PropertyChanges { target: animContainer; animHeight: tooltipWindow.tooltipHeight; visualCoreWidth: tooltipWindow.expandedCoreWidth; revealWidth: tooltipWindow.tooltipWidth; textOpacity: 1 }
                }
            ]

            transitions: [
                Transition {
                    from: "collapsed"; to: "expanded"
                    SequentialAnimation {
                        // Stretch straight down
                        NumberAnimation {
                            target: animContainer
                            property: "animHeight"
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                        // Expand horizontally to the left
                        NumberAnimation {
                            target: animContainer
                            property: "visualCoreWidth"
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                        // Wipe/reveal text horizontally from left to right
                        ParallelAnimation {
                            NumberAnimation {
                                target: animContainer
                                property: "revealWidth"
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: animContainer
                                property: "textOpacity"
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                },
                Transition {
                    from: "expanded"; to: "collapsed"
                    SequentialAnimation {
                        // (Reverse): Wipe text out quickly
                        ParallelAnimation {
                            NumberAnimation {
                                target: animContainer
                                property: "revealWidth"
                                duration: 120
                                easing.type: Easing.InQuad
                            }
                            NumberAnimation {
                                target: animContainer
                                property: "textOpacity"
                                duration: 100
                                easing.type: Easing.InQuad
                            }
                        }
                        // (Reverse): Collapse horizontally
                        NumberAnimation {
                            target: animContainer
                            property: "visualCoreWidth"
                            duration: 180
                            easing.type: Easing.InCubic
                        }
                        // (Reverse): Retract height back into the bar
                        NumberAnimation {
                            target: animContainer
                            property: "animHeight"
                            duration: 200
                            easing.type: Easing.InCubic
                        }
                    }
                }
            ]

            Component.onCompleted: {
                isCompleted = true; // Unlocks the transition to play
            }

            // SlantedBox handles height, core width, and slant mapping
            SlantedBox {
                id: tooltipBg
                anchors.left: tooltipWindow.alignSide === "Left" ? parent.left : undefined
                anchors.right: tooltipWindow.alignSide === "Right" ? parent.right : undefined
                anchors.top: parent.top
                height: animContainer.animHeight // animates height to grow/expand
                slantWidth: Math.round(height * (tooltipWindow.slantWidth / (tooltipWindow.moduleItem && tooltipWindow.moduleItem.height > 0 ? tooltipWindow.moduleItem.height : 40)))
                width: Math.round(animContainer.visualCoreWidth + slantWidth)

                slantLeft: tooltipWindow.slantLeft
                slantRight: tooltipWindow.slantRight
            }

            // Left-to-Right text reveal
            Item {
                id: textClippingMask
                anchors.left: parent.left
                anchors.top: parent.top
                width: animContainer.revealWidth // Animates 0 -> tooltipWidth
                height: tooltipWindow.tooltipHeight
                clip: true

                Item {
                    id: textWrapper
                    width: tooltipWindow.tooltipWidth
                    height: tooltipWindow.tooltipHeight
                    anchors.left: parent.left
                    opacity: animContainer.textOpacity

                }
            }
        }
}
