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

    // Per-module dimension overrides from Settings
    readonly property string moduleKey: (moduleItem && typeof moduleItem.moduleName !== "undefined") ? moduleItem.moduleName : ""
    readonly property int customWidthFromSettings: (shell && shell.settingsManager && moduleKey !== "")
        ? shell.settingsManager.getCapsuleWidth(moduleKey)
        : 0
    readonly property int customHeightFromSettings: (shell && shell.settingsManager && moduleKey !== "")
        ? shell.settingsManager.getCapsuleHeight(moduleKey)
        : 0

    readonly property int effectiveCoreWidth: customWidthFromSettings > 0 ? customWidthFromSettings : expandedCoreWidth
    readonly property int effectiveHeight: {
        if (customHeightFromSettings > 0) return customHeightFromSettings;
        if (tooltipHeight > 0) return tooltipHeight;
        return 460;
    }

    readonly property int liveTooltipHeight: effectiveHeight

    property int collapsedCoreWidth: 130
    property int expandedCoreWidth: 430
    property int tooltipHeight: 460
    property int topOffset: -2
    property int rightOffset: 0

    property string alignSide: "Right"
    property string backgroundStyle: "Slant"
    property int keyboardFocus: WlrKeyboardFocus.None

    readonly property string effectiveAlignSide: {
        if (moduleItem && typeof moduleItem.tooltipAlign !== "undefined" && moduleItem.tooltipAlign !== "") {
            return moduleItem.tooltipAlign;
        }
        if (slantLeft === "Right" && slantRight === "Right") return "Right";
        if (slantLeft === "Left" && slantRight === "Right") return "Center";
        if (alignSide !== undefined && alignSide !== "") return alignSide;
        return "Left";
    }

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

    WlrLayershell.exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-slanted-tooltip"
    WlrLayershell.keyboardFocus: tooltipWindow.visible ? tooltipWindow.keyboardFocus : WlrLayershell.None

    readonly property bool isPreviewingFromSettings: (shell && shell.settingsManager && shell.settingsManager.previewCapsule === moduleKey && moduleKey !== "")
    readonly property bool isEngaged: tooltipActive || pin || isPreviewingFromSettings

    anchors.top: true
    anchors.left: true

    WlrLayershell.margins.top: isEngaged ? targetTopMargin : frozenTopMargin
    WlrLayershell.margins.left: isEngaged ? calculatedLeftMargin : frozenLeftMargin

    property real frozenLeftMargin: 0
    property real frozenTopMargin: 0

    onIsEngagedChanged: {
        if (!isEngaged) {
            frozenLeftMargin = calculatedLeftMargin;
            frozenTopMargin = targetTopMargin;
        }
    }

    visible: (isEngaged || animContainer.animHeight > 0) && isReady

    implicitWidth: tooltipWidth
    implicitHeight: effectiveHeight
    color: "transparent"

    readonly property bool isReady: moduleItem !== null && moduleItem.width > 0

    readonly property real tooltipSlantWidth: (moduleItem && moduleItem.height > 0)
        ? (effectiveHeight * (slantWidth / moduleItem.height))
        : 15
    readonly property int tooltipWidth: effectiveCoreWidth + (backgroundStyle === "Hexagon" || effectiveAlignSide === "Center" ? (slantWidth * 2) : Math.round(tooltipSlantWidth))

    function slantX(y) {
        if (slantLeft === "Right") {
            return (effectiveHeight - y) * (tooltipSlantWidth / effectiveHeight);
        } else if (slantLeft === "Left") {
            return y * (tooltipSlantWidth / effectiveHeight);
        }
        return 0;
    }

    readonly property Item barContent: (barWindow && barWindow.contentItem) ? barWindow.contentItem : null
    readonly property point capsuleScreenPos: {
        if (!isReady || !moduleItem) return Qt.point(0, 0);
        var totalX = 0;
        var totalY = 0;
        var cur = moduleItem;
        while (cur && cur.parent) {
            totalX += cur.x;
            totalY += cur.y;
            cur = cur.parent;
        }
        return Qt.point(totalX, totalY);
    }

    readonly property real targetTopMargin: isReady ? Math.round(capsuleScreenPos.y + moduleItem.height) + topOffset : 0

    readonly property real calculatedLeftMargin: {
        if (!isReady) return 0;
        var capX = capsuleScreenPos.x;
        var capW = moduleItem.width;
        var capSlant = moduleItem.slantWidth !== undefined ? moduleItem.slantWidth : 12;

        var leftEdge = 0;
        if (effectiveAlignSide === "Left") {
            leftEdge = Math.round(capX + capSlant);
        } else if (effectiveAlignSide === "Right") {
            leftEdge = Math.round(capX + capW - tooltipWidth - capSlant);
        } else {
            leftEdge = Math.round(capX + (capW / 2) - (tooltipWidth / 2));
        }

        var maxLeft = (screen ? screen.width : 1920) - tooltipWidth - 10;
        return Math.max(10, Math.min(maxLeft, leftEdge));
    }

    readonly property bool smoothAnim: (shell && shell.settingsManager) ? shell.settingsManager.animationsEnabled : true

    property real animHeight: animContainer.animHeight
    readonly property bool shouldExpand: isReady && isEngaged

    onShouldExpandChanged: {
        if (shouldExpand) {
            closeAnimation.stop();
            openAnimation.start();
        } else {
            openAnimation.stop();
            closeAnimation.start();
        }
    }

    onEffectiveCoreWidthChanged: {
        if (shouldExpand) animContainer.visualCoreWidth = effectiveCoreWidth;
    }
    onEffectiveHeightChanged: {
        if (shouldExpand) animContainer.animHeight = effectiveHeight;
    }

    Component.onCompleted: {
        if (shouldExpand) {
            animContainer.animHeight = tooltipWindow.effectiveHeight;
            animContainer.visualCoreWidth = tooltipWindow.effectiveCoreWidth;
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
        anchors.left: tooltipWindow.effectiveAlignSide === "Left" ? parent.left : undefined
        anchors.right: tooltipWindow.effectiveAlignSide === "Right" ? parent.right : undefined
        anchors.horizontalCenter: tooltipWindow.effectiveAlignSide === "Center" ? parent.horizontalCenter : undefined
        anchors.top: parent.top

        width: parent.width
        height: parent.height

        property real animHeight: 0
        property real visualCoreWidth: tooltipWindow.collapsedCoreWidth
        property real textOpacity: 0

        SequentialAnimation {
            id: openAnimation
            NumberAnimation { target: animContainer; property: "animHeight"; to: tooltipWindow.effectiveHeight; duration: tooltipWindow.smoothAnim ? 200 : 0; easing.type: Easing.OutCubic }
            NumberAnimation { target: animContainer; property: "visualCoreWidth"; to: tooltipWindow.effectiveCoreWidth; duration: tooltipWindow.smoothAnim ? 180 : 0; easing.type: Easing.OutCubic }
            PropertyAction { target: tooltipWindow; property: "innerLayoutTrigger"; value: true }
            NumberAnimation { target: animContainer; property: "textOpacity"; to: 1.0; duration: tooltipWindow.smoothAnim ? 120 : 0; easing.type: Easing.OutQuad }
        }

        SequentialAnimation {
            id: closeAnimation
            PropertyAction { target: tooltipWindow; property: "innerLayoutTrigger"; value: false }
            NumberAnimation { target: animContainer; property: "textOpacity"; to: 0.0; duration: tooltipWindow.smoothAnim ? 80 : 0; easing.type: Easing.InQuad }
            NumberAnimation { target: animContainer; property: "visualCoreWidth"; to: tooltipWindow.collapsedCoreWidth; duration: tooltipWindow.smoothAnim ? 140 : 0; easing.type: Easing.InCubic }
            NumberAnimation { target: animContainer; property: "animHeight"; to: 0; duration: tooltipWindow.smoothAnim ? 160 : 0; easing.type: Easing.InCubic }
        }

        SlantedBox {
            id: tooltipBgSlant
            visible: tooltipWindow.backgroundStyle === "Slant" && tooltipWindow.effectiveAlignSide !== "Center"
            anchors.left: tooltipWindow.effectiveAlignSide === "Left" ? parent.left : undefined
            anchors.right: tooltipWindow.effectiveAlignSide === "Right" ? parent.right : undefined
            anchors.top: parent.top
            height: animContainer.animHeight
            slantWidth: Math.round(height * (tooltipWindow.slantWidth / (tooltipWindow.moduleItem && tooltipWindow.moduleItem.height > 0 ? tooltipWindow.moduleItem.height : 40)))
            width: Math.round(animContainer.visualCoreWidth + slantWidth)
            slantLeft: tooltipWindow.slantLeft
            slantRight: tooltipWindow.slantRight
        }

        Canvas {
            id: tooltipBgHexagon
            visible: tooltipWindow.backgroundStyle === "Hexagon" || tooltipWindow.effectiveAlignSide === "Center"
            anchors.horizontalCenter: parent.horizontalCenter
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
            height: tooltipWindow.effectiveHeight
            anchors.centerIn: (tooltipWindow.backgroundStyle === "Hexagon" || tooltipWindow.effectiveAlignSide === "Center") ? parent : undefined
            anchors.left: (tooltipWindow.backgroundStyle === "Slant" && tooltipWindow.effectiveAlignSide !== "Center") ? parent.left : undefined
            opacity: animContainer.textOpacity
        }
    }
}
