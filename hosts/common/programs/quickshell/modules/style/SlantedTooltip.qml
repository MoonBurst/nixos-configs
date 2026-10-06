// SlantedTooltip.qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: tooltipWindow

    required property Item moduleItem
    property var barWindow: null

    property bool tooltipActive: false
    property bool pin: false
    property bool dismissed: false
    property bool isHovered: tooltipAreaHover.hovered

    // True while actively focused on the tooltip; false when clicked off
    property bool isCardActive: true

    // Bar tooltips always use base05
    readonly property color borderColor: (shell && shell.theme && shell.theme.base05) ? shell.theme.base05 : "yellow"

    readonly property bool isPopupMode: {
        if (!moduleItem) return false;
        if ("popupActive" in moduleItem && moduleItem.popupActive) return true;
        if ("popupVisible" in moduleItem && moduleItem.popupVisible) return true;
        if ("isPinned" in moduleItem && moduleItem.isPinned) return true;
        if ("pinTooltip" in moduleItem && moduleItem.pinTooltip) return true;
        return false;
    }

    readonly property bool isInteractive: tooltipWindow.pin || tooltipWindow.isPopupMode || tooltipWindow.isPreviewingFromSettings

    onTooltipActiveChanged: {
        if (!tooltipActive && !pin && !isPopupMode) dismissed = false;
        if (tooltipActive) {
            isCardActive = true;
            refreshTrigger++;
        }
    }

    onPinChanged: {
        if (pin) {
            dismissed = false;
            isCardActive = true;
            refreshTrigger++;
        } else if (!tooltipActive && !isPopupMode) {
            dismissed = false;
        }
    }

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

    readonly property string effectiveSection: {
        if (shell && shell.settingsManager) {
            if (shell.settingsManager.barLeftModules.includes(moduleKey)) return "left";
            if (shell.settingsManager.barRightModules.includes(moduleKey)) return "right";
            return "center";
        }
        return "center";
    }

    property string slantLeft: {
        if (shell && shell.settingsManager) {
            var s = shell.settingsManager.getModuleSlant(moduleKey, effectiveSection);
            if (s === "left") return "Left";
            if (s === "right") return "Right";
            if (s === "center") return "Left";
        }
        if (moduleItem && typeof moduleItem.slantLeft !== "undefined") return moduleItem.slantLeft;
        return "Left";
    }

    property string slantRight: {
        if (shell && shell.settingsManager) {
            var s = shell.settingsManager.getModuleSlant(moduleKey, effectiveSection);
            if (s === "left") return "Left";
            if (s === "right") return "Right";
            if (s === "center") return "Right";
        }
        if (moduleItem && typeof moduleItem.slantRight !== "undefined") return moduleItem.slantRight;
        return "Left";
    }

    readonly property string effectiveAlignSide: {
        if (moduleItem && typeof moduleItem.tooltipAlign !== "undefined" && moduleItem.tooltipAlign !== "") {
            return moduleItem.tooltipAlign;
        }
        if (slantLeft === "Right" && slantRight === "Right") return "Right";
        if (slantLeft === "Left" && slantRight === "Right") return "Center";
        if (alignSide !== undefined && alignSide !== "") return alignSide;
        return (effectiveSection === "right") ? "Right" : (effectiveSection === "center" ? "Center" : "Left");
    }

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
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-slanted-tooltip"

        WlrLayershell.keyboardFocus: {
            if (!tooltipWindow.visible || !tooltipWindow.isEngaged) return WlrKeyboardFocus.None;
            if (tooltipWindow.isCardActive && (tooltipWindow.pin || tooltipWindow.isPopupMode || tooltipWindow.isHovered)) {
                return WlrKeyboardFocus.Exclusive;
            }
            return WlrKeyboardFocus.None;
        }

        // Mask is strictly the visual tooltip shape
        mask: Region {
            item: tooltipBgShape
        }

        readonly property bool isPreviewingFromSettings: (shell && shell.settingsManager && shell.settingsManager.previewCapsule === moduleKey && moduleKey !== "")
        onIsPreviewingFromSettingsChanged: {
            if (isPreviewingFromSettings) {
                dismissed = false;
                isCardActive = true;
                refreshTrigger++;
            }
        }

        readonly property bool isEngaged: !dismissed && (tooltipActive || pin || isPopupMode || isPreviewingFromSettings)
        onIsEngagedChanged: {
            if (isEngaged) {
                isCardActive = true;
                refreshTrigger++;
            }
        }

        anchors.top: true
        anchors.left: true

        WlrLayershell.margins.top: targetTopMargin
        WlrLayershell.margins.left: calculatedLeftMargin

        implicitWidth: tooltipWidth
        implicitHeight: effectiveHeight
        color: "transparent"

        visible: (isEngaged || animContainer.animHeight > 0) && isReady

        function activateCard() {
            tooltipWindow.isCardActive = true;
        }

        function closeTooltip() {
            tooltipWindow.dismissed = true;
            tooltipWindow.isCardActive = false;
            if (shell && shell.settingsManager && shell.settingsManager.previewCapsule === moduleKey) {
                shell.settingsManager.previewCapsule = "";
            }
            if (tooltipWindow.moduleItem) {
                if ("pinTooltip" in tooltipWindow.moduleItem) tooltipWindow.moduleItem.pinTooltip = false;
                if ("isPinned" in tooltipWindow.moduleItem) tooltipWindow.moduleItem.isPinned = false;
                if ("popupVisible" in tooltipWindow.moduleItem) tooltipWindow.moduleItem.popupVisible = false;
                if ("popupActive" in tooltipWindow.moduleItem) tooltipWindow.moduleItem.popupActive = false;
                if ("confirmDeleteMode" in tooltipWindow.moduleItem) tooltipWindow.moduleItem.confirmDeleteMode = false;
            }
        }

        Process {
            id: escWatcher
            running: tooltipWindow.visible && tooltipWindow.isEngaged && tooltipWindow.isInteractive
            command: [
                "luajit",
                Quickshell.shellDir + "/modules/common/escwatcher.lua"
            ]
            stdout: SplitParser {
                splitMarker: "\n"
                onRead: data => {
                    if (data.trim() === "ESC") tooltipWindow.closeTooltip();
                }
            }
        }

        Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: otherScreenCatcher
                required property var modelData
                screen: modelData

                visible: tooltipWindow.visible && tooltipWindow.isEngaged && tooltipWindow.isInteractive && tooltipWindow.isCardActive && (modelData !== tooltipWindow.screen)

                WlrLayershell.namespace: "quickshell-tooltip-dismiss"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                anchors { top: true; bottom: true; left: true; right: true }
                color: "transparent"

                MouseArea {
                    anchors.fill: parent
                    onPressed: {
                        tooltipWindow.isCardActive = false;
                    }
                }
            }
        }

        Shortcut {
            sequence: "Escape"
            enabled: tooltipWindow.visible
            onActivated: tooltipWindow.closeTooltip()
        }

        readonly property bool isReady: moduleItem !== null && moduleItem.width > 0

        readonly property real tooltipSlantWidth: (moduleItem && moduleItem.height > 0)
        ? (effectiveHeight * (slantWidth / moduleItem.height))
        : 15
        readonly property int tooltipWidth: effectiveCoreWidth + (backgroundStyle === "Hexagon" || effectiveAlignSide === "Center" ? (slantWidth * 2) : Math.round(tooltipSlantWidth))

        function slantX(y) {
            var ratio = tooltipSlantWidth / effectiveHeight;
            if (slantLeft === "Right") {
                return (effectiveHeight - y) * ratio;
            } else if (slantLeft === "Left") {
                return y * ratio;
            }
            return 0;
        }

        property int refreshTrigger: 0

        function getCapsuleScreenX() {
            if (!moduleItem) return 0;
            var x = 0;
            var cur = moduleItem;
            while (cur && (cur instanceof Item)) {
                if (typeof cur.x === "number" && !isNaN(cur.x)) {
                    x += cur.x;
                }
                cur = cur.parent;
            }
            return isNaN(x) ? 0 : x;
        }

        function getCapsuleScreenY() {
            if (!moduleItem) return 0;
            var y = 0;
            var cur = moduleItem;
            while (cur && (cur instanceof Item)) {
                if (typeof cur.y === "number" && !isNaN(cur.y)) {
                    y += cur.y;
                }
                cur = cur.parent;
            }
            return isNaN(y) ? 0 : y;
        }

        readonly property real targetTopMargin: {
            var _ = refreshTrigger;
            if (!isReady) return 0;
            var y = getCapsuleScreenY();
            return Math.round(y + moduleItem.height) + topOffset;
        }

        readonly property real calculatedLeftMargin: {
            var _ = refreshTrigger;
            if (!isReady) return 0;
            var capX = getCapsuleScreenX();
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
                isCardActive = true;
                refreshTrigger++;
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
            refreshTrigger++;
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

            MouseArea {
                anchors.fill: parent
                enabled: tooltipWindow.isInteractive && !tooltipWindow.isCardActive
                z: 9999
                cursorShape: Qt.PointingHandCursor
                onPressed: {
                    tooltipWindow.activateCard();
                }
            }

            HoverHandler {
                id: tooltipAreaHover
                onHoveredChanged: {
                    if (hovered && tooltipWindow.visible) {
                        focusScopeItem.forceActiveFocus();
                    } else if (!hovered && !tooltipActive && !pin && !tooltipWindow.isPopupMode) {
                        tooltipWindow.dismissed = false;
                    }
                }
            }

            FocusScope {
                id: focusScopeItem
                anchors.fill: parent
                focus: true
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        tooltipWindow.closeTooltip();
                        event.accepted = true;
                    }
                }
            }

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

            ShapeBox {
                id: tooltipBgShape
                readonly property bool isHex: tooltipWindow.backgroundStyle === "Hexagon" || tooltipWindow.effectiveAlignSide === "Center"
                readonly property int dynamicSlantW: Math.round(height * (tooltipWindow.slantWidth / (tooltipWindow.moduleItem && tooltipWindow.moduleItem.height > 0 ? tooltipWindow.moduleItem.height : 40)))

                shapeType: isHex ? "hexagon" : "slant"
                role: "custom"

                anchors.left: (!isHex && tooltipWindow.effectiveAlignSide === "Left") ? parent.left : undefined
                anchors.right: (!isHex && tooltipWindow.effectiveAlignSide === "Right") ? parent.right : undefined
                anchors.horizontalCenter: isHex ? parent.horizontalCenter : undefined
                anchors.top: parent.top

                height: animContainer.animHeight
                width: isHex ? animContainer.visualCoreWidth : Math.round(animContainer.visualCoreWidth + dynamicSlantW)

                slantLeft: tooltipWindow.slantLeft
                slantRight: tooltipWindow.slantRight
                slantWidth: dynamicSlantW
                hexCut: tooltipWindow.slantWidth

                color: (shell && shell.theme) ? (shell.theme.base00 || "black") : "black"
                borderColor: tooltipWindow.borderColor
                borderWidth: (shell && shell.theme && shell.theme.globalBorderWidth !== undefined) ? shell.theme.globalBorderWidth : 3
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
