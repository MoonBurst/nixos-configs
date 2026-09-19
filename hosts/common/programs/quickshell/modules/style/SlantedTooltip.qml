// SlantedTooltip.qml
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: tooltipWindow

    required property Item moduleItem
    property var barWindow: null

    property bool tooltipActive: false
    property bool pin: false

    property int tooltipHeight: 420
    property int collapsedCoreWidth: 130
    property int expandedCoreWidth: 430
    property int topOffset: 0
    property int rightOffset: 18

    property string alignSide: "Right"
    property string backgroundStyle: "Slant"

    property int keyboardFocus: WlrLayershell.None

    property string slantLeft: (moduleItem && typeof moduleItem.slantLeft !== "undefined") ? moduleItem.slantLeft : "Left"
    property string slantRight: (moduleItem && typeof moduleItem.slantRight !== "undefined") ? moduleItem.slantRight : "Left"
    property int slantWidth: (shell && shell.theme) ? (shell.theme.slantWidth || 12) : 12

    property bool innerLayoutTrigger: false

    default property alias content: textWrapper.children

        screen: {
            if (barWindow && barWindow.screen) return barWindow.screen;
            var p = moduleItem;
            while (p) {
                if (p.screen) return p.screen;
                if (p.Window && p.Window.window && p.Window.window.screen) return p.Window.window.screen;
                p = p.parent;
            }
            return Quickshell.screens[0] || null;
        }

        readonly property real screenWidth: tooltipWindow.screen ? tooltipWindow.screen.width : 1920

        WlrLayershell.exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-slanted-tooltip"
        WlrLayershell.keyboardFocus: tooltipWindow.visible ? tooltipWindow.keyboardFocus : WlrLayershell.None

        WlrLayershell.margins.top: tooltipWindow.tooltipActive ? tooltipWindow.targetTopMargin : tooltipWindow.frozenTopMargin
        WlrLayershell.margins.right: tooltipWindow.tooltipActive ? tooltipWindow.calculatedRightMargin : tooltipWindow.frozenRightMargin
        WlrLayershell.margins.left: tooltipWindow.tooltipActive ? tooltipWindow.calculatedLeftMargin : tooltipWindow.frozenLeftMargin

        property real frozenLeftMargin: 0
        property real frozenRightMargin: 0
        property real frozenTopMargin: 0

        onTooltipActiveChanged: {
            if (!tooltipActive) {
                frozenLeftMargin = calculatedLeftMargin;
                frozenRightMargin = calculatedRightMargin;
                frozenTopMargin = targetTopMargin;
            }
        }

        anchors.top: true
        anchors.left: alignSide === "Left" || alignSide === "Center"
        anchors.right: alignSide === "Right"

        visible: (tooltipActive || pin || animContainer.animHeight > 0) && isReady

        implicitWidth: tooltipWidth
        implicitHeight: tooltipHeight
        color: "transparent"

        readonly property bool isReady: moduleItem !== null && moduleItem.width > 0

        readonly property real tooltipSlantWidth: (moduleItem && moduleItem.height > 0)
        ? (tooltipHeight * (slantWidth / moduleItem.height))
        : 15
        readonly property int tooltipWidth: expandedCoreWidth + (backgroundStyle === "Hexagon" ? (slantWidth * 2) : tooltipSlantWidth)

        function slantX(y) {
            if (slantLeft === "Right") {
                return (tooltipHeight - y) * (tooltipSlantWidth / tooltipHeight);
            } else if (slantLeft === "Left") {
                return y * (tooltipSlantWidth / tooltipHeight);
            }
            return 0;
        }

        readonly property point mappedTarget: {
            if (!isReady) return Qt.point(0, 0);
            var depW = moduleItem.width;
            var depH = moduleItem.height;

            var rootItem = moduleItem;
            while (rootItem.parent) {
                rootItem = rootItem.parent;
            }

            if (alignSide === "Center") {
                return moduleItem.mapToItem(rootItem, depW / 2, depH);
            } else {
                return moduleItem.mapToItem(rootItem, depW, depH);
            }
        }

        readonly property real targetTopMargin: isReady ? Math.round(mappedTarget.y) + topOffset : 0

        readonly property real calculatedRightMargin: {
            if (!isReady || alignSide !== "Right") return 0;
            var barW = (barWindow && barWindow.width > 0) ? barWindow.width : tooltipWindow.screenWidth;
            return Math.round(barW - mappedTarget.x + rightOffset - (slantRight === "Left" ? tooltipSlantWidth : 0));
        }

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

        property real animHeight: animContainer.animHeight
        readonly property bool shouldExpand: isReady && (tooltipWindow.tooltipActive || tooltipWindow.pin)

        onShouldExpandChanged: {
            if (shouldExpand) {
                closeAnimation.stop();
                openAnimation.start();
            } else {
                openAnimation.stop();
                closeAnimation.start();
            }
        }

        Component.onCompleted: {
            if (shouldExpand) {
                animContainer.animHeight = tooltipWindow.tooltipHeight;
                animContainer.visualCoreWidth = tooltipWindow.expandedCoreWidth;
                animContainer.textOpacity = 1.0;
                tooltipWindow.innerLayoutTrigger = true;
            } else {
                animContainer.animHeight = 0;
                animContainer.visualCoreWidth = tooltipWindow.collapsedCoreWidth;
                animContainer.textOpacity = 0.0;
                tooltipWindow.innerLayoutTrigger = false;
            }
        }

        Item {
            id: animContainer
            anchors.left: tooltipWindow.alignSide === "Left" ? parent.left : undefined
            anchors.right: tooltipWindow.alignSide === "Right" ? parent.right : undefined
            anchors.horizontalCenter: tooltipWindow.alignSide === "Center" ? parent.horizontalCenter : undefined
            anchors.top: parent.top
            width: parent.width
            height: parent.height

            property real animHeight: 0
            property real visualCoreWidth: tooltipWindow.collapsedCoreWidth
            property real textOpacity: 0

            SequentialAnimation {
                id: openAnimation
                NumberAnimation { target: animContainer; property: "animHeight"; to: tooltipWindow.tooltipHeight; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { target: animContainer; property: "visualCoreWidth"; to: tooltipWindow.expandedCoreWidth; duration: 200; easing.type: Easing.OutCubic }
                PropertyAction { target: tooltipWindow; property: "innerLayoutTrigger"; value: true }
                NumberAnimation { target: animContainer; property: "textOpacity"; to: 1.0; duration: 150; easing.type: Easing.OutQuad }
            }

            SequentialAnimation {
                id: closeAnimation
                PropertyAction { target: tooltipWindow; property: "innerLayoutTrigger"; value: false }
                NumberAnimation { target: animContainer; property: "textOpacity"; to: 0.0; duration: 100; easing.type: Easing.InQuad }
                NumberAnimation { target: animContainer; property: "visualCoreWidth"; to: tooltipWindow.collapsedCoreWidth; duration: 150; easing.type: Easing.InCubic }
                NumberAnimation { target: animContainer; property: "animHeight"; to: 0; duration: 150; easing.type: Easing.InCubic }
            }

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
