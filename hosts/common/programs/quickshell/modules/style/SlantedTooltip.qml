// SlantedTooltip.qml
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: tooltipWindow

    required property Item moduleItem
    property var barWindow: null // Gracefully falls back if null

    // Activation states (bind tooltipActive to hover trackers)
    property bool tooltipActive: false
    property bool pin: false

    // Geometry customizers
    property int tooltipHeight: 420
    property int collapsedCoreWidth: 130 // Starting flat-width (pillar width)
    property int expandedCoreWidth: 430  // Final flat-width
    property int topOffset: 0
    property int rightOffset: 18

    // Alignment and Style Customizers
    property string alignSide: "Right"       // "Left", "Right", or "Center"
    property string backgroundStyle: "Slant" // "Slant" (RAM/Standard) or "Hexagon" (Clock)

    // Keyboard Focus Options
    property int keyboardFocus: WlrLayershell.None

    // Diagonal slant controls
    property string slantLeft: (moduleItem && typeof moduleItem.slantLeft !== "undefined") ? moduleItem.slantLeft : "Left"
    property string slantRight: (moduleItem && typeof moduleItem.slantRight !== "undefined") ? moduleItem.slantRight : "Left"
    property int slantWidth: (shell && shell.theme) ? (shell.theme.slantWidth || 12) : 12

    // Outer triggers for sub-window animations (Clock Grid)
    property bool innerLayoutTrigger: false

    default property alias content: textWrapper.children

        WlrLayershell.exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-slanted-tooltip"
        WlrLayershell.keyboardFocus: tooltipWindow.visible ? tooltipWindow.keyboardFocus : WlrLayershell.None

        // Explicit flat bindings: Keeps coordinates locked to the bar module without flicker
        WlrLayershell.margins.top: tooltipWindow.frozenTopMargin
        WlrLayershell.margins.right: tooltipWindow.frozenRightMargin
        WlrLayershell.margins.left: tooltipWindow.frozenLeftMargin

        anchors.top: true
        anchors.left: alignSide === "Left" || alignSide === "Center"
        anchors.right: alignSide === "Right"

        screen: tooltipWindow.barWindow ? tooltipWindow.barWindow.screen : null

        // Controls window visibility and handles graceful collapsing transitions before hiding
        visible: (tooltipActive || pin || animContainer.animHeight > 0) && isReady && targetTopMargin > 0

        // Fixed deprecations: Setting implicit bounds prevents Wayland stretching
        implicitWidth: tooltipWidth
        implicitHeight: tooltipHeight
        color: "transparent"

        // Decoupled from barWindow so it maps correctly even if barWindow is null
        readonly property bool isReady: moduleItem !== null && moduleItem.width > 0

        // Calculate proportional slant parameters
        readonly property real tooltipSlantWidth: (moduleItem && moduleItem.height > 0)
        ? (tooltipHeight * (slantWidth / moduleItem.height))
        : 15
        readonly property int tooltipWidth: expandedCoreWidth + (backgroundStyle === "Hexagon" ? (slantWidth * 2) : tooltipSlantWidth)

        // calculate slant offsets at any given vertical coordinate
        function slantX(y) {
            if (slantLeft === "Right") {
                return (tooltipHeight - y) * (tooltipSlantWidth / tooltipHeight);
            } else if (slantLeft === "Left") {
                return y * (tooltipSlantWidth / tooltipHeight);
            }
            return 0; // "None" (Vertical)
        }

        // FULLY REACTIVE COORDINATE TRACKER (Supports center & edge tracking)
        readonly property point mappedTarget: {
            if (!isReady) return Qt.point(0, 0);

            var depX = moduleItem.x;
            var depY = moduleItem.y;
            var depW = moduleItem.width;
            var depH = moduleItem.height;
            var depP = moduleItem.parent ? moduleItem.parent.x : 0;

            if (alignSide === "Center") {
                return moduleItem.mapToItem(null, depW / 2, depH);
            } else {
                return moduleItem.mapToItem(null, depW, depH);
            }
        }

        // target margin properties
        readonly property real targetTopMargin: isReady ? Math.round(mappedTarget.y) + topOffset : 0

        // offsets window alignment based on whether the capsule leans left or right
        readonly property real calculatedRightMargin: (isReady && alignSide === "Right")
        ? Math.round(barWindow.width - mappedTarget.x + rightOffset - (slantRight === "Left" ? tooltipSlantWidth : 0))
        : 0

        readonly property real calculatedLeftMargin: {
            if (!isReady) return 0;
            if (alignSide === "Left") {
                return Math.round(mappedTarget.x - moduleItem.width + rightOffset - (slantLeft === "Right" ? tooltipSlantWidth : 0));
            } else if (alignSide === "Center") {
                var targetLeft = Math.round(mappedTarget.x - (tooltipWidth / 2));
                var minimumMargin = (shell && shell.theme) ? (shell.theme.globalPadding || 12) : 12;
                return Math.max(minimumMargin, targetLeft);
            }
            return 0;
        }

        // FROZEN MARGIN BUFFER SYSTEM (Clears Wayland configure-loop flickering)
        property real frozenLeftMargin: 0
        property real frozenRightMargin: 0
        property real frozenTopMargin: 0

        onCalculatedLeftMarginChanged: {
            if (tooltipActive) frozenLeftMargin = calculatedLeftMargin;
        }
        onCalculatedRightMarginChanged: {
            if (tooltipActive) frozenRightMargin = calculatedRightMargin;
        }
        onTargetTopMarginChanged: {
            if (tooltipActive) frozenTopMargin = targetTopMargin;
        }
        onTooltipActiveChanged: {
            if (tooltipActive) {
                frozenLeftMargin = calculatedLeftMargin;
                frozenRightMargin = calculatedRightMargin;
                frozenTopMargin = targetTopMargin;
            }
        }

        property real animHeight: animContainer.animHeight

        // Layout boundary
        Item {
            id: animContainer
            anchors.left: tooltipWindow.alignSide === "Left" ? parent.left : undefined
            anchors.right: tooltipWindow.alignSide === "Right" ? parent.right : undefined
            anchors.horizontalCenter: tooltipWindow.alignSide === "Center" ? parent.horizontalCenter : undefined
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
                        // Stage 1: Drop straight down (pillar)
                        NumberAnimation {
                            target: animContainer
                            property: "animHeight"
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                        // Stage 2: Spread horizontally outward to sides
                        NumberAnimation {
                            target: animContainer
                            property: "visualCoreWidth"
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                        // Complete background & trigger inner column layout sweep (Clock Grid)
                        PropertyAction {
                            target: tooltipWindow
                            property: "innerLayoutTrigger"
                            value: true
                        }
                        // Stage 3: Reveal inner text (Parallel mask wipe & opacity fade)
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
                        // Turn off inner triggers instantly
                        PropertyAction {
                            target: tooltipWindow
                            property: "innerLayoutTrigger"
                            value: false
                        }
                        // Stage 1 (Reverse): Wipe out text
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
                        // Stage 2 (Reverse): Collapse horizontally
                        NumberAnimation {
                            target: animContainer
                            property: "visualCoreWidth"
                            duration: 180
                            easing.type: Easing.InCubic
                        }
                        // Stage 3 (Reverse): Retract vertical height back up into the bar
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

            // STYLE 1: Standard SlantedBox background (Only visible when backgroundStyle is "Slant")
            SlantedBox {
                id: tooltipBgSlant
                visible: tooltipWindow.backgroundStyle === "Slant"
                anchors.left: tooltipWindow.alignSide === "Left" ? parent.left : undefined
                anchors.right: tooltipWindow.alignSide === "Right" ? parent.right : undefined
                anchors.top: parent.top
                height: animContainer.animHeight
                slantWidth: Math.round(height * (tooltipWindow.slantWidth / (tooltipWindow.moduleItem && tooltipWindow.moduleItem.height > 0 ? tooltipWindow.moduleItem.height : 40)))
                width: Math.round(animContainer.visualCoreWidth + slantWidth)

                slantLeft: tooltipWindow.slantLeft
                slantRight: tooltipWindow.slantRight
            }

            // STYLE 2: Symmetrical 4-corner chamfered canvas (Only visible when backgroundStyle is "Hexagon")
            Canvas {
                id: tooltipBgHexagon
                visible: tooltipWindow.backgroundStyle === "Hexagon"
                anchors.horizontalCenter: tooltipWindow.alignSide === "Center" ? parent.horizontalCenter : undefined
                anchors.left: tooltipWindow.alignSide === "Left" ? parent.left : undefined
                anchors.right: tooltipWindow.alignSide === "Right" ? parent.right : undefined
                anchors.top: parent.top

                height: animContainer.animHeight
                width: animContainer.visualCoreWidth

                readonly property real borderW: (shell && shell.theme) ? (shell.theme.globalBorderWidth || 3) : 3
                readonly property real halfB: borderW / 2
                readonly property color colorBase05: (shell && shell.theme) ? (shell.theme.base05 || "yellow") : "yellow"
                readonly property color colorBase00: (shell && shell.theme) ? (shell.theme.base00 || "black") : "black"
                readonly property real sw: tooltipWindow.slantWidth

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();

                    ctx.lineWidth = borderW;
                    ctx.strokeStyle = colorBase05;
                    ctx.fillStyle = colorBase00;

                    var topChamferY = Math.min(height / 2, sw + halfB);
                    var bottomChamferY = Math.max(height / 2, height - sw - halfB);
                    var bottomY = Math.max(halfB, height - halfB);

                    ctx.beginPath();
                    ctx.moveTo(sw + halfB, halfB);
                    ctx.lineTo(width - sw - halfB, halfB);
                    ctx.lineTo(width - halfB, topChamferY);
                    ctx.lineTo(width - halfB, bottomChamferY);
                    ctx.lineTo(width - sw - halfB, bottomY);
                    ctx.lineTo(sw + halfB, bottomY);
                    ctx.lineTo(halfB, bottomChamferY);
                    ctx.lineTo(halfB, topChamferY);
                    ctx.closePath();

                    ctx.fill();
                    ctx.stroke();
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            // Left-to-Right text reveal clipping mask (Only clips when backgroundStyle is "Slant")
            Item {
                id: textClippingMask
                anchors.left: parent.left
                anchors.top: parent.top
                width: tooltipWindow.backgroundStyle === "Slant" ? animContainer.revealWidth : parent.width
                height: tooltipWindow.tooltipHeight
                clip: tooltipWindow.backgroundStyle === "Slant"

                Item {
                    id: textWrapper
                    width: tooltipWindow.tooltipWidth
                    height: tooltipWindow.tooltipHeight
                    anchors.centerIn: tooltipWindow.backgroundStyle === "Hexagon" ? parent : undefined
                    anchors.left: tooltipWindow.backgroundStyle === "Slant" ? parent.left : undefined
                    opacity: animContainer.textOpacity
                }
            }
        }
}
