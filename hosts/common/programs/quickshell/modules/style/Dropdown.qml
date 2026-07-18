import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: dropdownWindow
    property Item capsule: null          // The bar capsule (e.g., ramBox) to bind to
    property var barWindow: null         // Force-passed reactive window from parent
    property bool active: false          // Condition to trigger open/close
    property int tooltipHeight: 420      // Target stretch height
    property int tooltipWidth: 380       // Base target width
    property int topOffset: -6           // Vertical alignment tweak
    property int rightOffset: 0          // Horizontal right offset tweak
    property int leftOffset: 0           // Horizontal left offset tweak

    // Adjust this to change the starting width of the box while it is lowering down
    property int initialWidth: capsule ? capsule.width : 175

    // Side Alignment: Right/Left
    property string align: "Right"
    property string slantLeft: "Right"
    property string slantRight: "Right"

    // Increase this number to draw the top yellow border line more
    property int topBorderExcludeOffset: 0
    default property alias content: contentContainer.data

        readonly property bool hovered: dropdownHoverTracker.hovered
        readonly property int revealCharCount: internal.revealCharCount
        // -------------------------------------------------------------------------


        readonly property var activeBarWindow: dropdownWindow.barWindow ? dropdownWindow.barWindow : (capsule ? capsule.window : null)

        //  slant calculations
        readonly property real slantRatio: (capsule && capsule.height > 0)
        ? (capsule.slantWidth / capsule.height)
        : (((shell && shell.theme && shell.theme.slantWidth) ? shell.theme.slantWidth : 12) / 30)

        readonly property real tooltipSlantWidth: tooltipHeight * slantRatio
        readonly property int calculatedWidth: tooltipWidth + (tooltipSlantWidth * 2)

        readonly property int calculatedRightMargin: {
            var _windowWidth = activeBarWindow ? activeBarWindow.width : 0;
            var _capsuleX = capsule ? capsule.x : 0;
            var _capsuleWidth = capsule ? capsule.width : 0; // Reactively track capsule width changes

            if (activeBarWindow && capsule) {
                var absoluteX = capsule.mapToItem(null, 0, 0).x;
                return activeBarWindow.WlrLayershell.margins.right + (activeBarWindow.width - absoluteX - _capsuleWidth);
            }
            return 10;
        }

        readonly property int calculatedLeftMargin: {
            var _windowWidth = activeBarWindow ? activeBarWindow.width : 0;
            var _capsuleX = capsule ? capsule.x : 0;
            var _capsuleWidth = capsule ? capsule.width : 0; // Reactively track capsule width changes

            if (activeBarWindow && capsule) {
                var absoluteX = capsule.mapToItem(null, 0, 0).x;
                return activeBarWindow.WlrLayershell.margins.left + absoluteX;
            }
            return 10;
        }

        screen: activeBarWindow ? activeBarWindow.screen : null
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-slanted-dropdown"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.left: dropdownWindow.align === "Left"
        anchors.right: dropdownWindow.align === "Right"

        WlrLayershell.margins.top: topOffset
        WlrLayershell.margins.left: dropdownWindow.align === "Left" ? (calculatedLeftMargin + leftOffset) : 0
        WlrLayershell.margins.right: dropdownWindow.align === "Right" ? ((activeBarWindow ? activeBarWindow.WlrLayershell.margins.right : 0) + rightOffset) : 0

        color: "transparent"
        width: calculatedWidth
        height: tooltipHeight

        visible: internal.animHeight > 0 || active

        QtObject {
            id: internal
            property real animHeight: 0
            property real visualWidth: dropdownWindow.initialWidth
            property int revealCharCount: 0
        }

        Item {
            id: animatedContainer
            anchors.top: parent.top
            anchors.right: dropdownWindow.align === "Right" ? parent.right : undefined
            anchors.left: dropdownWindow.align === "Left" ? parent.left : undefined
            clip: true

            width: internal.visualWidth + tooltipBg.slantWidth
            height: internal.animHeight

            HoverHandler {
                id: dropdownHoverTracker
            }

            states: [
                State {
                    name: "closed"
                    when: !dropdownWindow.active
                    PropertyChanges { target: internal; visualWidth: dropdownWindow.initialWidth; animHeight: 0; revealCharCount: 0 }
                },
                State {
                    name: "expanded"
                    when: dropdownWindow.active
                    PropertyChanges { target: internal; visualWidth: dropdownWindow.calculatedWidth - dropdownWindow.tooltipSlantWidth; animHeight: dropdownWindow.tooltipHeight; revealCharCount: 50 }
                }
            ]

            transitions: [
                Transition {
                    from: "closed"; to: "expanded"
                    SequentialAnimation {
                        // Stretch vertically down
                        NumberAnimation { target: internal; property: "animHeight"; to: dropdownWindow.tooltipHeight; duration: 250; easing.type: Easing.OutCubic }
                        // Expand horizontally
                        NumberAnimation { target: internal; property: "visualWidth"; to: dropdownWindow.calculatedWidth - dropdownWindow.tooltipSlantWidth; duration: 250; easing.type: Easing.OutCubic }
                        //Typewrite text lines
                        NumberAnimation { target: internal; property: "revealCharCount"; from: 0; to: 50; duration: 350; easing.type: Easing.OutQuad }
                    }
                },
                Transition {
                    from: "expanded"; to: "closed"
                    SequentialAnimation {
                        PropertyAction { target: internal; property: "revealCharCount"; value: 0 }
                        // Collapse horizontally back to capsule width
                        NumberAnimation { target: internal; property: "visualWidth"; to: dropdownWindow.initialWidth; duration: 200; easing.type: Easing.InCubic }
                        // Pull vertically back up
                        NumberAnimation { target: internal; property: "animHeight"; to: 0; duration: 200; easing.type: Easing.InCubic }
                    }
                }
            ]

            SlantedBox {
                id: tooltipBg
                anchors.fill: parent
                slantLeft: dropdownWindow.slantLeft
                slantRight: dropdownWindow.slantRight
                slantWidth: animatedContainer.height * dropdownWindow.slantRatio
                showTopBorder: true
                topBorderExcludeRight: Math.max(0, (capsule ? capsule.width : 0) - dropdownWindow.topBorderExcludeOffset)
            }

            Item {
                id: staticContent
                width: dropdownWindow.calculatedWidth
                height: dropdownWindow.tooltipHeight
                anchors.top: parent.top
                anchors.right: dropdownWindow.align === "Right" ? parent.right : undefined
                anchors.left: dropdownWindow.align === "Left" ? parent.left : undefined

                Item {
                    id: contentContainer
                    anchors.fill: parent
                }
            }
        }
}
