import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

Item {
    id: customBox

    property var barWindow: null
    property string moduleName: "custom"
    property bool popupVisible: false

    readonly property var settingsManager: (shell && shell.settingsManager) ? shell.settingsManager : null
    readonly property var theme: (shell && shell.theme) ? shell.theme : null

    readonly property string currentMode: settingsManager ? settingsManager.customCapsuleMode : "static"
    readonly property string contentType: settingsManager ? settingsManager.customCapsuleType : "both"
    readonly property string rawText: settingsManager ? settingsManager.customCapsuleText : ""
    readonly property string rawImages: settingsManager ? settingsManager.customCapsuleImages : ""
    readonly property int swapIntervalSec: settingsManager ? settingsManager.customCapsuleSwapInterval : 5
    readonly property real scrollSpeed: settingsManager ? settingsManager.customCapsuleScrollSpeed : 40
    readonly property int imageSize: settingsManager ? (settingsManager.customCapsuleImageSize || 28) : 28
    readonly property bool isRandomSwap: settingsManager ? settingsManager.customCapsuleRandomSwap : false

    property string slantLeft: (shell && shell.settingsManager) ? (shell.settingsManager.getModuleSlant(customBox.moduleName, "center") === "right" ? "Right" : "Left") : "Left"
    property string slantRight: (shell && shell.settingsManager) ? (shell.settingsManager.getModuleSlant(customBox.moduleName, "center") === "right" ? "Right" : "Left") : "Left"
    property int slantWidth: (theme && theme.slantWidth) ? theme.slantWidth : 12

    readonly property var textLines: rawText.split("\n").map(s => s.trim()).filter(s => s.length > 0)
    readonly property var imageList: rawImages.split("\n").map(s => s.trim()).filter(s => s.length > 0)

    property int currentSwapIndex: 0

    function resolvePath(p) {
        if (!p) return "";
        var clean = p.trim().replace(/^['"]|['"]$/g, "");
        var home = Quickshell.env("HOME") || "";

        if (clean.startsWith("~")) clean = home + clean.substring(1);
        else if (clean.startsWith("$HOME")) clean = home + clean.substring(5);

        if (clean.startsWith("file://")) return clean;
        if (clean.startsWith("/")) return "file://" + encodeURI(clean).replace(/#/g, "%23");
        return clean;
    }

    Timer {
        id: swapTimer
        interval: Math.max(1, customBox.swapIntervalSec) * 1000
        running: customBox.currentMode === "swap"
        repeat: true
        onTriggered: {
            var maxCount = Math.max(customBox.textLines.length, customBox.imageList.length);
            if (maxCount <= 1) return;

            if (customBox.isRandomSwap) {
                var nextIdx = Math.floor(Math.random() * maxCount);
                if (nextIdx === customBox.currentSwapIndex) nextIdx = (nextIdx + 1) % maxCount;
                customBox.currentSwapIndex = nextIdx;
            } else {
                customBox.currentSwapIndex = (customBox.currentSwapIndex + 1) % maxCount;
            }
        }
    }

    readonly property string activeText: {
        if (textLines.length === 0) return "";
        if (currentMode === "swap") return textLines[currentSwapIndex % textLines.length];
        return textLines[0];
    }

    readonly property string activeImage: {
        if (imageList.length === 0) return "";
        var raw = (currentMode === "swap") ? imageList[currentSwapIndex % imageList.length] : imageList[0];
        return resolvePath(raw);
    }

    readonly property bool showImage: (contentType === "image" || contentType === "both" || (activeImage !== "" && activeText === "")) && activeImage !== ""
    readonly property bool showText: (contentType === "text" || contentType === "both" || (activeText !== "" && activeImage === "")) && activeText !== ""

    implicitWidth: Math.max(70, contentLayout.implicitWidth + bg.leftPadding + bg.rightPadding + 20)
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: customBox.slantLeft
        slantRight: customBox.slantRight
        slantWidth: customBox.slantWidth
    }

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 4
        anchors.rightMargin: bg.rightPadding + 4
        clip: true

        RowLayout {
            id: contentLayout
            visible: customBox.currentMode !== "scroll"
            anchors.centerIn: parent
            spacing: 8

            AnimatedImage {
                id: barStaticGif
                visible: customBox.showImage
                source: customBox.activeImage
                playing: true
                paused: false
                cache: false
                width: customBox.imageSize
                height: customBox.imageSize
                Layout.preferredWidth: customBox.imageSize
                Layout.preferredHeight: customBox.imageSize
                fillMode: Image.PreserveAspectFit
                smooth: true
                onStatusChanged: if (status === AnimatedImage.Ready) { playing = true; paused = false; }
            }

            Text {
                visible: customBox.showText
                text: customBox.activeText
                font.family: (customBox.theme && customBox.theme.fontFamily) ? customBox.theme.fontFamily : "monospace"
                font.pixelSize: (customBox.theme && customBox.theme.globalFontSize) ? customBox.theme.globalFontSize : 14
                font.bold: true
                color: (customBox.theme && customBox.theme.base05) ? customBox.theme.base05 : "yellow"
                verticalAlignment: Text.AlignVCenter
            }
        }

        Item {
            id: scrollWrapper
            visible: customBox.currentMode === "scroll"
            anchors.fill: parent

            RowLayout {
                id: scrollContent
                x: scrollAnim.currentX
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                AnimatedImage {
                    visible: customBox.showImage
                    source: customBox.activeImage
                    playing: true
                    paused: false
                    cache: false
                    width: customBox.imageSize
                    height: customBox.imageSize
                    Layout.preferredWidth: customBox.imageSize
                    Layout.preferredHeight: customBox.imageSize
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    onStatusChanged: if (status === AnimatedImage.Ready) { playing = true; paused = false; }
                }

                Text {
                    text: customBox.textLines.join("   ★   ")
                    font.family: (customBox.theme && customBox.theme.fontFamily) ? customBox.theme.fontFamily : "monospace"
                    font.pixelSize: (customBox.theme && customBox.theme.globalFontSize) ? customBox.theme.globalFontSize : 14
                    font.bold: true
                    color: (customBox.theme && customBox.theme.base05) ? customBox.theme.base05 : "yellow"
                }
            }

            NumberAnimation {
                id: scrollAnim
                property real currentX: contentContainer.width
                target: scrollAnim
                property: "currentX"
                from: contentContainer.width
                to: -scrollContent.implicitWidth - 20
                duration: Math.max(1000, ((contentContainer.width + scrollContent.implicitWidth) / Math.max(10, customBox.scrollSpeed)) * 1000)
                loops: Animation.Infinite
                running: customBox.currentMode === "scroll" && contentContainer.width > 0
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: customBox.popupVisible = !customBox.popupVisible
    }

    SlantedTooltip {
        id: customTooltip
        moduleItem: customBox
        barWindow: customBox.barWindow
        tooltipActive: customBox.popupVisible
        pin: customBox.popupVisible
        alignSide: "Left"
        tooltipHeight: 560
        expandedCoreWidth: 540
        topOffset: -2

        readonly property real contentBoxWidth: 380

        readonly property color base00: (customBox.theme && customBox.theme.base00) ? customBox.theme.base00 : "#0f0f0f"
        readonly property color base02: (customBox.theme && customBox.theme.base02) ? customBox.theme.base02 : "#1e1e2e"
        readonly property color base03: (customBox.theme && customBox.theme.base03) ? customBox.theme.base03 : "#003399"
        readonly property color base05: (customBox.theme && customBox.theme.base05) ? customBox.theme.base05 : "yellow"
        readonly property color base0C: (customBox.theme && customBox.theme.base0C) ? customBox.theme.base0C : "#04f100"
        readonly property string fontFamily: (customBox.theme && customBox.theme.fontFamily) ? customBox.theme.fontFamily : "monospace"

        Text {
            y: 20
            x: customTooltip.slantX(y) + 48
            text: "⚙ CUSTOM CAPSULE CONFIGURATION"
            font.family: customTooltip.fontFamily
            font.bold: true
            font.pixelSize: 15
            color: customTooltip.base0C
        }

        // Display Mode Row
        Row {
            y: 54
            x: customTooltip.slantX(y) + 48
            spacing: 8

            Text {
                text: "Mode:"
                font.family: customTooltip.fontFamily
                font.bold: true; color: customTooltip.base05
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }

            Repeater {
                model: [
                    { id: "static", label: "Static" },
                    { id: "swap", label: "Swap" },
                    { id: "scroll", label: "Ribbon Scroll" }
                ]
                delegate: Rectangle {
                    readonly property bool isSelected: customBox.currentMode === modelData.id
                    width: mText.implicitWidth + 20; height: 28; radius: 6
                    color: isSelected ? customTooltip.base05 : customTooltip.base00
                    border.color: customTooltip.base05; border.width: 1.5

                    Text {
                        id: mText; anchors.centerIn: parent; text: modelData.label
                        font.family: customTooltip.fontFamily; font.pixelSize: 11; font.bold: true
                        color: isSelected ? customTooltip.base00 : customTooltip.base05
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (customBox.settingsManager) customBox.settingsManager.customCapsuleMode = modelData.id
                    }
                }
            }
        }

        // Content Type Row
        Row {
            y: 90
            x: customTooltip.slantX(y) + 48
            spacing: 8

            Text {
                text: "Type:"
                font.family: customTooltip.fontFamily
                font.bold: true; color: customTooltip.base05
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }

            Repeater {
                model: [
                    { id: "text", label: "Text Only" },
                    { id: "image", label: "Image Only" },
                    { id: "both", label: "Both" }
                ]
                delegate: Rectangle {
                    readonly property bool isSelected: customBox.contentType === modelData.id
                    width: tText.implicitWidth + 20; height: 28; radius: 6
                    color: isSelected ? customTooltip.base05 : customTooltip.base00
                    border.color: customTooltip.base05; border.width: 1.5

                    Text {
                        id: tText; anchors.centerIn: parent; text: modelData.label
                        font.family: customTooltip.fontFamily; font.pixelSize: 11; font.bold: true
                        color: isSelected ? customTooltip.base00 : customTooltip.base05
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (customBox.settingsManager) customBox.settingsManager.customCapsuleType = modelData.id
                    }
                }
            }
        }

        // Shuffle Toggle
        Row {
            y: 126
            x: customTooltip.slantX(y) + 48
            spacing: 10
            visible: customBox.currentMode === "swap"

            Text {
                text: "💡 Cycle 1 item per line:"
                font.family: customTooltip.fontFamily
                font.pixelSize: 10; font.bold: true
                color: customTooltip.base0C
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: randTxt.implicitWidth + 18; height: 26; radius: 6
                color: customBox.isRandomSwap ? customTooltip.base0C : customTooltip.base00
                border.color: customTooltip.base0C; border.width: 1.5

                Text {
                    id: randTxt; anchors.centerIn: parent
                    text: customBox.isRandomSwap ? "🔀 Shuffle: ON" : "🔀 Shuffle: OFF"
                    font.family: customTooltip.fontFamily; font.pixelSize: 10; font.bold: true
                    color: customBox.isRandomSwap ? "#000" : customTooltip.base0C
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (customBox.settingsManager) customBox.settingsManager.customCapsuleRandomSwap = !customBox.settingsManager.customCapsuleRandomSwap
                }
            }
        }

        Text {
            y: customBox.currentMode === "swap" ? 158 : 128
            x: customTooltip.slantX(y) + 48
            text: "Custom Text (multi-line for swap):"
            font.family: customTooltip.fontFamily
            font.bold: true; font.pixelSize: 11; color: customTooltip.base05
        }

        // Text input field
        Rectangle {
            y: customBox.currentMode === "swap" ? 178 : 148
            x: customTooltip.slantX(y) + 48
            width: customTooltip.contentBoxWidth
            height: 56
            radius: 6
            color: customTooltip.base00
            border.color: customTooltip.base05
            border.width: 1.5

            ScrollView {
                anchors.fill: parent
                anchors.margins: 6
                TextArea {
                    text: customBox.rawText
                    placeholderText: "Line 1: Message One\nLine 2: Message Two..."
                    placeholderTextColor: "#666"
                    color: customTooltip.base05
                    font.pixelSize: 12; font.family: customTooltip.fontFamily
                    wrapMode: Text.Wrap
                    background: null
                    onTextEdited: if (customBox.settingsManager) customBox.settingsManager.customCapsuleText = text
                }
            }
        }

        Text {
            y: customBox.currentMode === "swap" ? 242 : 212
            x: customTooltip.slantX(y) + 48
            text: "Image / GIF Path(s) (supports ~, $HOME, file://):"
            font.family: customTooltip.fontFamily
            font.bold: true; font.pixelSize: 11; color: customTooltip.base05
        }

        // Image input field
        Rectangle {
            y: customBox.currentMode === "swap" ? 262 : 232
            x: customTooltip.slantX(y) + 48
            width: customTooltip.contentBoxWidth
            height: 52
            radius: 6
            color: customTooltip.base00
            border.color: customTooltip.base05
            border.width: 1.5

            ScrollView {
                anchors.fill: parent
                anchors.margins: 6
                TextArea {
                    text: customBox.rawImages
                    placeholderText: "~/Pictures/eicons/MoonWhirl.gif..."
                    placeholderTextColor: "#666"
                    color: customTooltip.base05
                    font.pixelSize: 11; font.family: customTooltip.fontFamily
                    wrapMode: Text.Wrap
                    background: null
                    onTextEdited: if (customBox.settingsManager) customBox.settingsManager.customCapsuleImages = text
                }
            }
        }

        // Image Size Slider
        Row {
            y: customBox.currentMode === "swap" ? 322 : 292
            x: customTooltip.slantX(y) + 48
            width: customTooltip.contentBoxWidth
            spacing: 12

            Text {
                text: "Image Size: " + customBox.imageSize + "px"
                font.family: customTooltip.fontFamily; font.pixelSize: 11; font.bold: true; color: customTooltip.base05
                anchors.verticalCenter: parent.verticalCenter
                width: 130
            }

            Slider {
                width: parent.width - 142
                from: 14; to: 50; stepSize: 2; value: customBox.imageSize
                anchors.verticalCenter: parent.verticalCenter
                onMoved: if (customBox.settingsManager) customBox.settingsManager.customCapsuleImageSize = Math.round(value)
            }
        }

        // Swap / Scroll Sliders
        Row {
            y: 362
            x: customTooltip.slantX(y) + 48
            width: customTooltip.contentBoxWidth
            spacing: 12
            visible: customBox.currentMode === "swap"

            Text {
                text: "Swap Time: " + customBox.swapIntervalSec + "s"
                font.family: customTooltip.fontFamily; font.pixelSize: 11; font.bold: true; color: customTooltip.base05
                anchors.verticalCenter: parent.verticalCenter
                width: 130
            }

            Slider {
                width: parent.width - 142
                from: 1; to: 60; stepSize: 1; value: customBox.swapIntervalSec
                anchors.verticalCenter: parent.verticalCenter
                onMoved: if (customBox.settingsManager) customBox.settingsManager.customCapsuleSwapInterval = Math.round(value)
            }
        }

        Row {
            y: 362
            x: customTooltip.slantX(y) + 48
            width: customTooltip.contentBoxWidth
            spacing: 12
            visible: customBox.currentMode === "scroll"

            Text {
                text: "Speed: " + Math.round(customBox.scrollSpeed) + " px/s"
                font.family: customTooltip.fontFamily; font.pixelSize: 11; font.bold: true; color: customTooltip.base05
                anchors.verticalCenter: parent.verticalCenter
                width: 130
            }

            Slider {
                width: parent.width - 142
                from: 10; to: 150; stepSize: 5; value: customBox.scrollSpeed
                anchors.verticalCenter: parent.verticalCenter
                onMoved: if (customBox.settingsManager) customBox.settingsManager.customCapsuleScrollSpeed = Math.round(value)
            }
        }

        // Done Button
        Rectangle {
            y: 416
            x: customTooltip.slantX(y) + customTooltip.contentBoxWidth - width
            width: 84
            height: 32
            radius: 6
            color: doneHov.hovered ? customTooltip.base00 : customTooltip.base05
            border.color: customTooltip.base05
            border.width: 1.5

            Text {
                anchors.centerIn: parent
                text: "✓ Done"
                font.family: customTooltip.fontFamily
                font.bold: true; font.pixelSize: 12
                color: doneHov.hovered ? customTooltip.base05 : customTooltip.base00
            }
            HoverHandler { id: doneHov }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: customBox.popupVisible = false
            }
        }
    }
}
