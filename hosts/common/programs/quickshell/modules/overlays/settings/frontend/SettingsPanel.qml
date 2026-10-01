import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import "../../../style"
import "../../../settings"

Item {
    id: panelRoot

    property var shell: null
    property var settingsManager: (shell && shell.settingsManager) ? shell.settingsManager : null
    readonly property var theme: (shell && shell.theme) ? shell.theme : null

    readonly property int liveFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize
        : ((theme && theme.globalFontSize) ? theme.globalFontSize : 16)

    readonly property int liveBorderWidth: (theme && theme.globalBorderWidth) ? theme.globalBorderWidth : 2
    readonly property int livePadding: (theme && theme.globalPadding) ? theme.globalPadding : 12
    readonly property int liveSlantWidth: (theme && theme.slantWidth) ? theme.slantWidth : 8
    readonly property color liveBase00: (theme && theme.base00) ? theme.base00 : "#0f0f0f"
    readonly property color liveBase02: (theme && theme.base02) ? theme.base02 : "#1e1e2e"
    readonly property color liveBase03: (theme && theme.base03) ? theme.base03 : "#003399"
    readonly property color liveBase05: (theme && theme.base05) ? theme.base05 : "#f7f700"
    readonly property color liveBase08: (theme && theme.base08) ? theme.base08 : "#ff0000"
    readonly property color liveBase09: (theme && theme.base09) ? theme.base09 : "#fe8019"
    readonly property color liveBase0C: (theme && theme.base0C) ? theme.base0C : "#04f100"
    readonly property string liveFontFamily: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"

    property string editingGpuCard: settingsManager ? settingsManager.activeGpuCard : "card0"

    function slantLeftFor(section) { return (section === "right") ? "Right" : "Left"; }
    function slantRightFor(section) { return (section === "left") ? "Left" : "Right"; }
    function slantGlyphFor(section) {
        if (section === "center") return "\\ /";
        if (section === "right") return "/ /";
        return "\\ \\";
    }

    readonly property int chipSlantWidth: Math.max(4, Math.min(panelRoot.liveSlantWidth, 8))

    anchors.fill: parent
    property int activeTab: 0

    onActiveTabChanged: {
        if (settingsManager && activeTab !== 4 && settingsManager.previewWindow !== "") {
            settingsManager.previewWindow = "";
        }
    }

    onVisibleChanged: {
        if (!visible && settingsManager) {
            settingsManager.previewCapsule = "";
            settingsManager.previewWindow = "";
        }
    }

    ColorPickerPopup {
        id: guiColorPicker
        theme: panelRoot.theme
        onColorSelected: function(propName, hexStr) {
            if (settingsManager && settingsManager[propName] !== undefined) {
                settingsManager.useStylix = false;
                settingsManager[propName] = hexStr;
            }
        }
        onSaveToStylixRequested: function(propName, hexStr) {
            if (settingsManager) {
                settingsManager.saveColorToStylix(propName, hexStr);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: panelRoot.livePadding

        // Tab Headers
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: ["Stylix & Sliders", "Color Palette", "GPU & Hardware", "Bar Layout & Slants", "Overlays & Windows"]
                delegate: Item {
                    Layout.fillWidth: true
                    height: Math.max(34, panelRoot.liveFontSize * 2.0)
                    clip: true

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"; slantRight: "Left"
                        slantWidth: panelRoot.liveSlantWidth
                        color: panelRoot.activeTab === index ? panelRoot.liveBase05 : "transparent"
                        borderColor: panelRoot.liveBase05
                        borderWidth: panelRoot.liveBorderWidth
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: panelRoot.liveSlantWidth + 2
                        anchors.rightMargin: panelRoot.liveSlantWidth + 2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        font.family: panelRoot.liveFontFamily
                        font.pixelSize: Math.max(10, Math.min(14, panelRoot.liveFontSize - 3))
                        font.bold: true
                        elide: Text.ElideRight
                        color: panelRoot.activeTab === index ? panelRoot.liveBase00 : panelRoot.liveBase05
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true
                        onClicked: panelRoot.activeTab = index
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: panelRoot.liveBorderWidth
            color: panelRoot.liveBase03
        }

        // TAB 0: STYLIX & LIVE METRICS
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            flickableDirection: Flickable.VerticalFlick; pressDelay: 120
            contentWidth: width; contentHeight: tab0Layout.implicitHeight + 80
            visible: panelRoot.activeTab === 0
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

            ColumnLayout {
                id: tab0Layout
                width: parent.width - 16
                spacing: panelRoot.livePadding

                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    CyberToggle {
                        label: "Follow Stylix Theme"
                        checked: settingsManager ? settingsManager.useStylix : false
                        theme: panelRoot.theme
                        fontSize: panelRoot.liveFontSize
                        onToggled: (st) => {
                            if (settingsManager) {
                                settingsManager.useStylix = st;
                            }
                        }
                    }
                }

                // FIXED: Self-sizing button that prevents text from falling out
                RowLayout {
                    Layout.fillWidth: true; spacing: 12

                    Text {
                        text: "🎨 Stylix Colors:"
                        font.bold: true
                        color: panelRoot.liveBase05
                        font.pixelSize: Math.max(12, panelRoot.liveFontSize - 1)
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(32, panelRoot.liveFontSize * 1.9)
                        radius: 6
                        color: panelRoot.liveBase00
                        border.color: panelRoot.liveBase03
                        border.width: 1

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: Text.AlignVCenter
                            text: "Nix Base16 Color Definitions (theme.nix)"
                            font.family: "monospace"
                            font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                            color: panelRoot.liveBase05
                            elide: Text.ElideMiddle
                        }
                    }

                    Rectangle {
                        id: copyNixBtn
                        implicitWidth: copyBtnRow.implicitWidth + 28
                        implicitHeight: Math.max(32, panelRoot.liveFontSize * 1.9)
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        radius: 6
                        color: copyBtnHov.hovered ? panelRoot.liveBase05 : panelRoot.liveBase02
                        border.color: panelRoot.liveBase05
                        border.width: 1

                        Row {
                            id: copyBtnRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "📋"
                                font.pixelSize: Math.max(12, panelRoot.liveFontSize - 2)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Copy Nix Colors"
                                font.bold: true
                                font.pixelSize: Math.max(11, panelRoot.liveFontSize - 3)
                                color: copyBtnHov.hovered ? panelRoot.liveBase00 : panelRoot.liveBase05
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        HoverHandler { id: copyBtnHov }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (settingsManager) {
                                    var block = settingsManager.getNixColorBlock();
                                    Quickshell.clipboardText = block;
                                    Quickshell.execDetached(["notify-send", "-a", "Settings", "🎨 Copied Nix Colors", "Base16 theme block copied to clipboard."]);
                                }
                            }
                        }
                    }
                }

                CyberSlider {
                    label: "Global Overlays Text / Font Size"
                    from: 11; to: 32; stepSize: 1; unit: "px"
                    value: settingsManager ? settingsManager.overlayFontSize : 16
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.overlayFontSize = Math.round(v); }
                }

                CyberSlider {
                    label: "Global Search & Input Field Height (All Windows)"
                    from: 36; to: 200; stepSize: 2; unit: "px"
                    value: settingsManager ? settingsManager.globalFieldHeight : 52
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.globalFieldHeight = Math.round(v); }
                }

                CyberSlider {
                    label: "Global Overlay Window Width"
                    from: 500; to: 1600; stepSize: 20; unit: "px"
                    value: settingsManager ? settingsManager.globalOverlayWidth : 840
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.globalOverlayWidth = Math.round(v); }
                }

                CyberSlider {
                    label: "Global Overlay Window Height"
                    from: 300; to: 1050; stepSize: 25; unit: "px"
                    value: settingsManager ? settingsManager.globalOverlayHeight : 650
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.globalOverlayHeight = Math.round(v); }
                }

                CyberSlider {
                    label: "Top Bar Height"
                    from: 32; to: 64; stepSize: 2; unit: "px"
                    value: settingsManager ? settingsManager.barHeight : 42
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.barHeight = Math.round(v); }
                }

                CyberSlider {
                    label: "Capsule Spacing"
                    from: -100; to: 20; stepSize: 1; unit: "px"
                    value: settingsManager ? settingsManager.capsuleSpacing : 2
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.capsuleSpacing = v; }
                }

                CyberSlider {
                    label: "Global Font Size (Bar)"
                    from: 10; to: 24; stepSize: 1; unit: "px"
                    value: settingsManager ? settingsManager.globalFontSize : 14
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) { settingsManager.useStylix = false; settingsManager.globalFontSize = v; } }
                }

                CyberSlider {
                    label: "Capsule Slant Width"
                    from: 4; to: 24; stepSize: 1; unit: "px"
                    value: settingsManager ? settingsManager.slantWidth : 12
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) { settingsManager.useStylix = false; settingsManager.slantWidth = v; } }
                }

                CyberSlider {
                    label: "Global Border Width"
                    from: 1; to: 6; stepSize: 1; unit: "px"
                    value: settingsManager ? settingsManager.globalBorderWidth : 3
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) { settingsManager.useStylix = false; settingsManager.globalBorderWidth = v; } }
                }
            }
        }

        // TAB 1: COLOR PALETTE
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            flickableDirection: Flickable.VerticalFlick; pressDelay: 120
            contentWidth: width; contentHeight: tab1Layout.implicitHeight + 80
            visible: panelRoot.activeTab === 1
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

            ColumnLayout {
                id: tab1Layout
                width: parent.width - 16
                spacing: panelRoot.livePadding

                Repeater {
                    model: [
                        { name: "Primary Background (base00)", prop: "customBase00", def: "#0f0f0f" },
                        { name: "Slanted Bar Border (base03)", prop: "customBase03", def: "#003399" },
                        { name: "Primary Accent / Text (base05)", prop: "customBase05", def: "#f7f700" },
                        { name: "Danger / Alert Red (base08)", prop: "customBase08", def: "#ff0000" },
                        { name: "Warning / Orange (base09)", prop: "customBase09", def: "#fe8019" },
                        { name: "Success / Green (base0C)", prop: "customBase0C", def: "#04f100" },
                        { name: "Accent Blue / Focus (base0D)", prop: "customBase0D", def: "#003399" }
                    ]
                    delegate: RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Rectangle {
                            width: Math.max(34, panelRoot.liveFontSize * 2); height: width; radius: 6
                            color: settingsManager ? settingsManager[modelData.prop] : modelData.def
                            border.width: 2; border.color: "#ffffff"
                            MouseArea { anchors.fill: parent; onClicked: guiColorPicker.openPicker(modelData.prop, parent.color) }
                        }
                        Text { text: modelData.name; font.family: panelRoot.liveFontFamily; font.pixelSize: panelRoot.liveFontSize; color: panelRoot.liveBase05; Layout.fillWidth: true }
                    }
                }
            }
        }

        // TAB 2: GPU & HARDWARE THRESHOLDS
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            flickableDirection: Flickable.VerticalFlick; pressDelay: 120
            contentWidth: width; contentHeight: tab2Layout.implicitHeight + 80
            visible: panelRoot.activeTab === 2
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

            ColumnLayout {
                id: tab2Layout
                width: parent.width - 16; spacing: 16

                Text {
                    text: "🎮 GPU ALERT THRESHOLDS & MONITORING"
                    font.family: panelRoot.liveFontFamily
                    font.pixelSize: panelRoot.liveFontSize + 1
                    font.bold: true
                    color: panelRoot.liveBase0C
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Text { text: "Select GPU:"; font.bold: true; color: panelRoot.liveBase05; font.pixelSize: panelRoot.liveFontSize - 1 }

                    Repeater {
                        model: (settingsManager && settingsManager.availableGpuCards) ? settingsManager.availableGpuCards : [{ id: "card0", name: "GPU 0" }, { id: "card1", name: "GPU 1" }]
                        delegate: Rectangle {
                            readonly property bool isSelected: panelRoot.editingGpuCard === modelData.id
                            width: gpuPillText.implicitWidth + 24; height: Math.max(30, panelRoot.liveFontSize * 1.8); radius: 6
                            color: isSelected ? panelRoot.liveBase05 : panelRoot.liveBase02
                            border.color: panelRoot.liveBase05; border.width: 1

                            Text {
                                id: gpuPillText
                                anchors.centerIn: parent
                                text: modelData.name || modelData.id
                                font.bold: true; font.pixelSize: Math.max(10, panelRoot.liveFontSize - 2)
                                color: isSelected ? panelRoot.liveBase00 : panelRoot.liveBase05
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    panelRoot.editingGpuCard = modelData.id;
                                    if (settingsManager) settingsManager.activeGpuCard = modelData.id;
                                }
                            }
                        }
                    }
                }

                CyberSlider {
                    label: (panelRoot.editingGpuCard === "card1" ? "GPU 1" : "GPU 0") + " Temperature Warning Threshold"
                    from: 40; to: 95; stepSize: 1; unit: "°C"
                    value: settingsManager ? settingsManager.getGpuTempWarn(panelRoot.editingGpuCard) : 70
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.setGpuThreshold(panelRoot.editingGpuCard, "tempWarn", v); }
                }

                CyberSlider {
                    label: (panelRoot.editingGpuCard === "card1" ? "GPU 1" : "GPU 0") + " Temperature Danger Threshold"
                    from: 50; to: 105; stepSize: 1; unit: "°C"
                    value: settingsManager ? settingsManager.getGpuTempDanger(panelRoot.editingGpuCard) : 80
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.setGpuThreshold(panelRoot.editingGpuCard, "tempDanger", v); }
                }

                CyberSlider {
                    label: (panelRoot.editingGpuCard === "card1" ? "GPU 1" : "GPU 0") + " Free VRAM Warning Threshold"
                    from: 1; to: 16; stepSize: 1; unit: "GiB"
                    value: settingsManager ? settingsManager.getGpuVramWarn(panelRoot.editingGpuCard) : 4
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.setGpuThreshold(panelRoot.editingGpuCard, "vramWarn", v); }
                }

                CyberSlider {
                    label: (panelRoot.editingGpuCard === "card1" ? "GPU 1" : "GPU 0") + " Free VRAM Danger Threshold"
                    from: 0; to: 8; stepSize: 1; unit: "GiB"
                    value: settingsManager ? settingsManager.getGpuVramDanger(panelRoot.editingGpuCard) : 2
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.setGpuThreshold(panelRoot.editingGpuCard, "vramDanger", v); }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: panelRoot.liveBase03 }

                CyberSlider {
                    label: "Hardware Polling Interval"
                    from: 1000; to: 10000; stepSize: 500; unit: "ms"
                    value: settingsManager ? settingsManager.hardwarePollInterval : 2000
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.hardwarePollInterval = Math.round(v); }
                }
            }
        }

        // TAB 3: BAR MODULES
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            flickableDirection: Flickable.VerticalFlick; pressDelay: 120
            contentWidth: width; contentHeight: tab3Layout.implicitHeight + 80
            visible: panelRoot.activeTab === 3
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

            ColumnLayout {
                id: tab3Layout
                width: parent.width - 16; spacing: 16

                Text {
                    text: "📊 REORDER CAPSULES & SLANT MODES"
                    font.pixelSize: panelRoot.liveFontSize + 1; font.bold: true
                    color: panelRoot.liveBase05
                }

                Row {
                    spacing: 12
                    Layout.fillWidth: true

                    Text {
                        text: "Global Slants:"
                        font.bold: true
                        color: panelRoot.liveBase05
                        font.pixelSize: panelRoot.liveFontSize - 1
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Repeater {
                        model: [
                            { id: "symmetric", label: "Symmetric (\\ /)" },
                            { id: "all-left", label: "All Left (\\ \\)" },
                            { id: "all-right", label: "All Right (/ /)" }
                        ]
                        delegate: Rectangle {
                            readonly property bool isSelected: settingsManager && settingsManager.slantStyleMode === modelData.id
                            width: modeTxt.implicitWidth + 24
                            height: Math.max(30, panelRoot.liveFontSize * 1.8)
                            radius: 6
                            color: isSelected ? panelRoot.liveBase05 : panelRoot.liveBase02
                            border.color: panelRoot.liveBase05; border.width: 1

                            Text {
                                id: modeTxt
                                anchors.centerIn: parent
                                text: modelData.label
                                font.bold: true
                                font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                                color: isSelected ? panelRoot.liveBase00 : panelRoot.liveBase05
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: if (settingsManager) settingsManager.slantStyleMode = modelData.id
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: panelRoot.liveBase03 }

                Repeater {
                    model: [
                        { id: "left", label: "LEFT BAR SECTION", list: settingsManager ? settingsManager.getLeftList() : [] },
                        { id: "center", label: "CENTER BAR SECTION", list: settingsManager ? settingsManager.getCenterList() : [] },
                        { id: "right", label: "RIGHT BAR SECTION", list: settingsManager ? settingsManager.getRightList() : [] }
                    ]
                    delegate: ColumnLayout {
                        id: sectionBlock
                        readonly property string currentSection: modelData.id
                        readonly property string sectionLabel: modelData.label
                        readonly property var sectionList: modelData.list
                        readonly property string sectionSlantLeft: panelRoot.slantLeftFor(currentSection)
                        readonly property string sectionSlantRight: panelRoot.slantRightFor(currentSection)

                        Layout.fillWidth: true; spacing: 6

                        SlantedBox {
                            id: sectionHeader
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(28, panelRoot.liveFontSize * 2.0)
                            slantLeft: sectionBlock.sectionSlantLeft
                            slantRight: sectionBlock.sectionSlantRight
                            slantWidth: panelRoot.liveSlantWidth
                            color: panelRoot.liveBase02
                            borderColor: panelRoot.liveBase0C
                            borderWidth: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: parent.leftPadding
                                anchors.rightMargin: parent.rightPadding
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: sectionBlock.sectionLabel
                                    font.family: panelRoot.liveFontFamily
                                    font.bold: true; font.pixelSize: Math.max(11, panelRoot.liveFontSize - 2)
                                    color: panelRoot.liveBase0C
                                }
                                Text {
                                    text: panelRoot.slantGlyphFor(sectionBlock.currentSection)
                                    font.family: "monospace"
                                    font.bold: true; font.pixelSize: Math.max(11, panelRoot.liveFontSize - 2)
                                    color: panelRoot.liveBase05
                                }
                            }
                        }

                        Repeater {
                            model: sectionBlock.sectionList

                            delegate: SlantedBox {
                                id: cardDelegate
                                readonly property string capsuleId: modelData
                                readonly property bool hasTooltip: (capsuleId !== "audio" && capsuleId !== "mic")
                                readonly property string currentSlant: settingsManager ? settingsManager.getModuleSlant(capsuleId, sectionBlock.currentSection) : "left"
                                readonly property string cardSlantLeft: sectionBlock.sectionSlantLeft
                                readonly property string cardSlantRight: sectionBlock.sectionSlantRight
                                property bool drawerExpanded: false

                                Layout.fillWidth: true
                                Layout.preferredHeight: drawerExpanded ? (capsuleId === "tray" ? 140 : 160) : Math.max(46, panelRoot.liveFontSize * 2.2)
                                height: Layout.preferredHeight
                                slantLeft: cardDelegate.cardSlantLeft
                                slantRight: cardDelegate.cardSlantRight
                                slantWidth: panelRoot.liveSlantWidth
                                color: panelRoot.liveBase00
                                borderColor: drawerExpanded ? panelRoot.liveBase05 : panelRoot.liveBase03
                                borderWidth: drawerExpanded ? panelRoot.liveBorderWidth : 1
                                clip: true

                                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: cardDelegate.leftPadding
                                    anchors.rightMargin: cardDelegate.rightPadding
                                    anchors.topMargin: 6; anchors.bottomMargin: 6
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true; height: Math.max(32, panelRoot.liveFontSize * 2.0); spacing: 8

                                        SlantedBox {
                                            Layout.preferredWidth: 32; Layout.preferredHeight: 32
                                            Layout.alignment: Qt.AlignVCenter
                                            slantLeft: cardDelegate.cardSlantLeft; slantRight: cardDelegate.cardSlantRight
                                            slantWidth: panelRoot.chipSlantWidth
                                            color: upBtnHover.hovered ? panelRoot.liveBase02 : "transparent"
                                            borderColor: panelRoot.liveBase03; borderWidth: 1
                                            Text { anchors.centerIn: parent; text: "▲"; font.bold: true; font.pixelSize: 11; color: panelRoot.liveBase05 }
                                            HoverHandler { id: upBtnHover }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsManager.moveWithinSection(sectionBlock.currentSection, index, index - 1) }
                                        }

                                        SlantedBox {
                                            Layout.preferredWidth: 32; Layout.preferredHeight: 32
                                            Layout.alignment: Qt.AlignVCenter
                                            slantLeft: cardDelegate.cardSlantLeft; slantRight: cardDelegate.cardSlantRight
                                            slantWidth: panelRoot.chipSlantWidth
                                            color: downBtnHover.hovered ? panelRoot.liveBase02 : "transparent"
                                            borderColor: panelRoot.liveBase03; borderWidth: 1
                                            Text { anchors.centerIn: parent; text: "▼"; font.bold: true; font.pixelSize: 11; color: panelRoot.liveBase05 }
                                            HoverHandler { id: downBtnHover }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsManager.moveWithinSection(sectionBlock.currentSection, index, index + 1) }
                                        }

                                        Text {
                                            text: cardDelegate.capsuleId.toUpperCase()
                                            font.bold: true; font.pixelSize: panelRoot.liveFontSize
                                            color: panelRoot.liveBase05
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Row {
                                            spacing: 8
                                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                            SlantedBox {
                                                visible: cardDelegate.hasTooltip
                                                width: editRow.implicitWidth + 24; height: 30
                                                slantLeft: cardDelegate.cardSlantLeft; slantRight: cardDelegate.cardSlantRight
                                                slantWidth: panelRoot.chipSlantWidth
                                                color: cardDelegate.drawerExpanded ? panelRoot.liveBase05 : panelRoot.liveBase02
                                                borderColor: panelRoot.liveBase05; borderWidth: 1
                                                Row {
                                                    id: editRow
                                                    anchors.centerIn: parent; spacing: 4
                                                    Text { text: "📐"; font.pixelSize: 11; color: cardDelegate.drawerExpanded ? panelRoot.liveBase00 : panelRoot.liveBase05; anchors.verticalCenter: parent.verticalCenter }
                                                    Text { text: cardDelegate.drawerExpanded ? "Done" : "Edit"; font.bold: true; font.pixelSize: 10; color: cardDelegate.drawerExpanded ? panelRoot.liveBase00 : panelRoot.liveBase05; anchors.verticalCenter: parent.verticalCenter }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        cardDelegate.drawerExpanded = !cardDelegate.drawerExpanded;
                                                        if (settingsManager && cardDelegate.capsuleId !== "tray") {
                                                            settingsManager.previewCapsule = cardDelegate.drawerExpanded ? cardDelegate.capsuleId : "";
                                                        }
                                                    }
                                                }
                                            }

                                            SlantedBox {
                                                width: 62; height: 30
                                                slantLeft: cardDelegate.cardSlantLeft; slantRight: cardDelegate.cardSlantRight
                                                slantWidth: panelRoot.chipSlantWidth
                                                color: settingsManager.isCapsuleVisible(cardDelegate.capsuleId) ? panelRoot.liveBase0C : panelRoot.liveBase08
                                                borderColor: settingsManager.isCapsuleVisible(cardDelegate.capsuleId) ? panelRoot.liveBase0C : panelRoot.liveBase08
                                                borderWidth: 1
                                                Text { anchors.centerIn: parent; text: settingsManager.isCapsuleVisible(cardDelegate.capsuleId) ? "SHOW" : "HIDE"; font.pixelSize: 11; font.bold: true; color: "#000" }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsManager.toggleCapsuleVisibility(cardDelegate.capsuleId) }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        visible: cardDelegate.drawerExpanded && cardDelegate.hasTooltip
                                        spacing: 6

                                        Row {
                                            spacing: 8
                                            Layout.fillWidth: true

                                            Text {
                                                text: "Slant:"
                                                font.bold: true
                                                font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                                                color: panelRoot.liveBase05
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Repeater {
                                                model: [
                                                    { id: "auto", label: "Auto" },
                                                    { id: "left", label: "\\ Left" },
                                                    { id: "right", label: "/ Right" },
                                                    { id: "center", label: "\\ / Center" }
                                                ]
                                                delegate: Rectangle {
                                                    readonly property string targetOption: modelData.id
                                                    readonly property bool isCurrent: {
                                                        var custom = settingsManager ? settingsManager.capsuleSlants[cardDelegate.capsuleId] : undefined;
                                                        if (targetOption === "auto") return !custom || custom === "auto";
                                                        return custom === targetOption;
                                                    }
                                                    width: pillText.implicitWidth + 14; height: 26; radius: 4
                                                    color: isCurrent ? panelRoot.liveBase05 : panelRoot.liveBase02
                                                    border.color: panelRoot.liveBase05; border.width: 1

                                                    Text {
                                                        id: pillText; anchors.centerIn: parent
                                                        text: modelData.label
                                                        font.pixelSize: 10; font.bold: true
                                                        color: isCurrent ? panelRoot.liveBase00 : panelRoot.liveBase05
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (settingsManager) {
                                                                settingsManager.setModuleSlant(cardDelegate.capsuleId, targetOption);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        CyberSlider {
                                            visible: cardDelegate.capsuleId === "tray"
                                            label: "Tray Auto-Collapse Timeout"
                                            from: 0; to: 30; stepSize: 1; unit: "s"
                                            value: settingsManager ? settingsManager.trayCollapseTimeoutSec : 3
                                            fontSize: panelRoot.liveFontSize - 2
                                            theme: panelRoot.theme; Layout.fillWidth: true
                                            valueFormatter: function(v) { return v === 0 ? "Disabled (Stay Open)" : Math.round(v) + "s"; }
                                            onValueModified: (v) => { if (settingsManager) settingsManager.trayCollapseTimeoutSec = Math.round(v); }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true; spacing: 12
                                            visible: cardDelegate.capsuleId !== "tray"
                                            CyberSlider {
                                                label: "Tooltip Width"; from: 300; to: 1400; stepSize: 20; unit: "px"
                                                value: settingsManager ? (settingsManager.getCapsuleWidth(cardDelegate.capsuleId) || 500) : 500
                                                fontSize: panelRoot.liveFontSize - 2
                                                theme: panelRoot.theme; Layout.fillWidth: true
                                                onValueModified: (v) => { if (settingsManager) settingsManager.setCapsuleWidth(cardDelegate.capsuleId, v); }
                                            }
                                            CyberSlider {
                                                label: "Tooltip Height"; from: 180; to: 750; stepSize: 20; unit: "px"
                                                value: settingsManager ? (settingsManager.getCapsuleHeight(cardDelegate.capsuleId) || 460) : 460
                                                fontSize: panelRoot.liveFontSize - 2
                                                theme: panelRoot.theme; Layout.fillWidth: true
                                                onValueModified: (v) => { if (settingsManager) settingsManager.setCapsuleHeight(cardDelegate.capsuleId, v); }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // TAB 4: OVERLAYS & LIVE PREVIEWS
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            flickableDirection: Flickable.VerticalFlick; pressDelay: 120
            contentWidth: width; contentHeight: tab4Layout.implicitHeight + 160
            visible: panelRoot.activeTab === 4
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

            ColumnLayout {
                id: tab4Layout
                width: parent.width - 16; spacing: 16

                // NOTIFICATION CONTROLS
                Text { text: "🔔 NOTIFICATIONS, TTS PHRASES & EXCLUSIONS"; font.pixelSize: panelRoot.liveFontSize + 1; font.bold: true; color: panelRoot.liveBase0C }

                RowLayout {
                    Layout.fillWidth: true; spacing: 16
                    CyberToggle {
                        Layout.fillWidth: true
                        label: "Notifications Enabled"
                        checked: settingsManager ? settingsManager.notificationsEnabled : true
                        theme: panelRoot.theme
                        fontSize: panelRoot.liveFontSize
                        onToggled: (st) => { if (settingsManager) settingsManager.notificationsEnabled = st; }
                    }
                    CyberToggle {
                        Layout.fillWidth: true
                        label: "Voice TTS Speech"
                        checked: settingsManager ? settingsManager.enableTts : true
                        theme: panelRoot.theme
                        fontSize: panelRoot.liveFontSize
                        onToggled: (st) => { if (settingsManager) settingsManager.enableTts = st; }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    Text { text: "Card Border Color:"; font.bold: true; color: panelRoot.liveBase05; font.pixelSize: panelRoot.liveFontSize - 1 }
                    Rectangle {
                        width: 32; height: 32; radius: 6
                        color: (settingsManager && settingsManager.notifBorderColor) ? settingsManager.notifBorderColor : panelRoot.liveBase05
                        border.width: 2; border.color: "#ffffff"
                        MouseArea { anchors.fill: parent; onClicked: guiColorPicker.openPicker("notifBorderColor", parent.color) }
                    }
                    Item { width: 10 }
                    Text { text: "Default Icon:"; font.bold: true; color: panelRoot.liveBase05; font.pixelSize: panelRoot.liveFontSize - 1 }
                    Rectangle {
                        Layout.fillWidth: true; height: Math.max(34, panelRoot.liveFontSize * 2.0); radius: 6; color: panelRoot.liveBase00
                        border.color: panelRoot.liveBase03; border.width: 1
                        TextInput {
                            anchors.fill: parent; anchors.margins: 8; color: panelRoot.liveBase05
                            font.pixelSize: panelRoot.liveFontSize - 2; verticalAlignment: TextInput.AlignVCenter
                            text: settingsManager ? settingsManager.notifCustomIcon : ""
                            onTextChanged: if (settingsManager) settingsManager.notifCustomIcon = text
                            Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; text: "Optional fallback icon path / icon name..."; color: "#666"; visible: parent.text === "" }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "SageTTS Speech Target Keywords (comma-separated):"; font.bold: true; color: panelRoot.liveBase05; font.pixelSize: panelRoot.liveFontSize - 2 }
                    Rectangle {
                        Layout.fillWidth: true; height: Math.max(36, panelRoot.liveFontSize * 2.2); radius: 6; color: panelRoot.liveBase00
                        border.color: panelRoot.liveBase03; border.width: 1
                        TextInput {
                            anchors.fill: parent; anchors.margins: 8; color: panelRoot.liveBase05
                            font.pixelSize: panelRoot.liveFontSize - 2; verticalAlignment: TextInput.AlignVCenter
                            text: settingsManager ? settingsManager.ttsKeywordsStr : ""
                            onTextChanged: if (settingsManager) settingsManager.ttsKeywordsStr = text
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "Strings & App Names to Exclude from Toasts & History (comma-separated):"; font.bold: true; color: panelRoot.liveBase05; font.pixelSize: panelRoot.liveFontSize - 2 }
                    Rectangle {
                        Layout.fillWidth: true; height: Math.max(36, panelRoot.liveFontSize * 2.2); radius: 6; color: panelRoot.liveBase00
                        border.color: panelRoot.liveBase03; border.width: 1
                        TextInput {
                            anchors.fill: parent; anchors.margins: 8; color: panelRoot.liveBase05
                            font.pixelSize: panelRoot.liveFontSize - 2; verticalAlignment: TextInput.AlignVCenter
                            text: settingsManager ? settingsManager.notifExcludedStr : ""
                            onTextChanged: if (settingsManager) settingsManager.notifExcludedStr = text
                        }
                    }
                }

                // FIXED: 3-Toast Preview Button & Screen Row
                RowLayout {
                    Layout.fillWidth: true; spacing: 12

                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "Target Screen:"
                            color: panelRoot.liveBase05
                            font.bold: true
                            font.pixelSize: Math.max(12, panelRoot.liveFontSize - 1)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                            model: {
                                var list = ["Auto"];
                                if (typeof Quickshell !== "undefined" && Quickshell.screens) {
                                    for (var i = 0; i < Quickshell.screens.length; i++) {
                                        if (Quickshell.screens[i] && Quickshell.screens[i].name) list.push(Quickshell.screens[i].name);
                                    }
                                }
                                return list;
                            }
                            delegate: Rectangle {
                                readonly property bool isSelected: {
                                    var cur = settingsManager ? settingsManager.notifScreenName : "";
                                    return (modelData === "Auto" && cur === "") || (modelData === cur);
                                }
                                width: scrText.implicitWidth + 24
                                height: Math.max(28, panelRoot.liveFontSize * 1.8)
                                radius: 4
                                color: isSelected ? panelRoot.liveBase05 : panelRoot.liveBase02
                                border.color: panelRoot.liveBase05; border.width: 1

                                Text {
                                    id: scrText
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.bold: true
                                    font.pixelSize: Math.max(11, panelRoot.liveFontSize - 3)
                                    color: isSelected ? panelRoot.liveBase00 : panelRoot.liveBase05
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (settingsManager) {
                                            settingsManager.notifScreenName = (modelData === "Auto") ? "" : modelData;
                                            if (shell && shell.notificationOverlay) shell.notificationOverlay.triggerPreviewNotification();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // FIXED: Dedicated Layout.preferredWidth and self-contained sizing prevents text breaking out
                    Rectangle {
                        id: toastPreviewBtn
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: toastBtnRow.implicitWidth + 28
                        implicitHeight: Math.max(30, panelRoot.liveFontSize * 1.9)
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        radius: 6
                        color: testNotifHov.hovered ? panelRoot.liveBase0C : "transparent"
                        border.color: panelRoot.liveBase0C
                        border.width: 1.5

                        Row {
                            id: toastBtnRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "🔔"
                                font.pixelSize: Math.max(12, panelRoot.liveFontSize - 2)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "3-Toast Preview"
                                font.bold: true
                                font.pixelSize: Math.max(11, panelRoot.liveFontSize - 3)
                                color: testNotifHov.hovered ? panelRoot.liveBase00 : panelRoot.liveBase0C
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        HoverHandler { id: testNotifHov }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (shell && shell.notificationOverlay) shell.notificationOverlay.triggerPreviewNotification()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    CyberSlider {
                        label: "Toast Stacking Baseline Y"; from: 50; to: 900; stepSize: 10; unit: "px"
                        value: settingsManager ? settingsManager.notifBaselineY : 350
                        fontSize: panelRoot.liveFontSize
                        theme: panelRoot.theme; Layout.fillWidth: true
                        onValueModified: (v) => { if (settingsManager) settingsManager.notifBaselineY = Math.round(v); }
                    }
                    CyberSlider {
                        label: "Card Stacking Overlap"; from: 0; to: 60; stepSize: 5; unit: "px"
                        value: settingsManager ? settingsManager.notifStackOverlap : 25
                        fontSize: panelRoot.liveFontSize
                        theme: panelRoot.theme; Layout.fillWidth: true
                        onValueModified: (v) => { if (settingsManager) settingsManager.notifStackOverlap = Math.round(v); }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    CyberSlider {
                        label: "Toast Display Duration"; from: 1; to: 20; stepSize: 1; unit: "s"
                        value: settingsManager ? settingsManager.notifHoldDurationSec : 5
                        fontSize: panelRoot.liveFontSize
                        theme: panelRoot.theme; Layout.fillWidth: true
                        onValueModified: (v) => { if (settingsManager) settingsManager.notifHoldDurationSec = Math.round(v); }
                    }
                    CyberSlider {
                        label: "Screen Margin (Right X)"; from: 0; to: 80; stepSize: 4; unit: "px"
                        value: settingsManager ? settingsManager.notifMarginX : 20
                        fontSize: panelRoot.liveFontSize
                        theme: panelRoot.theme; Layout.fillWidth: true
                        onValueModified: (v) => { if (settingsManager) settingsManager.notifMarginX = Math.round(v); }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: panelRoot.liveBase03 }

                // WINDOW SIZING & LIVE PREVIEWS SECTION
                Text { text: "🪟 WINDOW SIZING & LIVE PREVIEWS"; font.pixelSize: panelRoot.liveFontSize + 1; font.bold: true; color: panelRoot.liveBase0C }

                // LAZY LOADER SLIDER POSITIONED RIGHT BELOW WINDOWS SECTION HEADER
                CyberSlider {
                    label: "Lazy Loader Unload Grace Period (Keeps RAM/VRAM warm for fast re-opens)"
                    from: 0; to: 120; stepSize: 5; unit: "s"
                    value: settingsManager ? settingsManager.overlayGraceTimeoutSec : 10
                    fontSize: panelRoot.liveFontSize
                    theme: panelRoot.theme; Layout.fillWidth: true
                    valueFormatter: function(v) { return v === 0 ? "Instant (0s)" : Math.round(v) + "s"; }
                    onValueModified: (v) => { if (settingsManager) settingsManager.overlayGraceTimeoutSec = Math.round(v); }
                }

                Repeater {
                    model: [
                        { id: "launcher",   name: "App Launcher",        icon: "🚀" },
                        { id: "calc",       name: "Calculator & Units",  icon: "🧮" },
                        { id: "clipboard",  name: "Clipboard Manager",   icon: "📋" },
                        { id: "dictionary", name: "Dictionary",          icon: "📖" },
                        { id: "unicode",    name: "Unicode Search",      icon: "🔣" },
                        { id: "notes",      name: "Quick Notes",         icon: "📝" },
                        { id: "pass",       name: "Password Store",      icon: "🔑" },
                        { id: "power",      name: "Power & Session",     icon: "⚡" },
                        { id: "todo",       name: "Todo Task Board",     icon: "✅" },
                        { id: "gemini",     name: "Gemini AI Assistant", icon: "🤖" },
                        { id: "settings",   name: "Settings Menu Window",icon: "⚙" },
                        { id: "web",        name: "Web Search",          icon: "🌐" },
                        { id: "email",      name: "Email Client",        icon: "✉" },
                        { id: "amogus",     name: "Among Us Tracker",    icon: "ඞ" }
                    ]

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: Math.max(46, panelRoot.liveFontSize * 2.2)
                        radius: 8
                        color: panelRoot.liveBase00
                        border.color: (settingsManager && settingsManager.previewWindow === modelData.id) ? panelRoot.liveBase0C : panelRoot.liveBase03
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text { text: modelData.icon; font.pixelSize: Math.max(14, panelRoot.liveFontSize) }
                            Text {
                                text: modelData.name.toUpperCase()
                                font.bold: true; font.pixelSize: panelRoot.liveFontSize
                                color: panelRoot.liveBase05
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 8
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                Rectangle {
                                    width: openBtnText.implicitWidth + 20
                                    height: Math.max(28, panelRoot.liveFontSize * 1.7)
                                    radius: 4
                                    color: openBtnHover.hovered ? panelRoot.liveBase05 : "transparent"
                                    border.color: panelRoot.liveBase05; border.width: 1

                                    Text {
                                        id: openBtnText
                                        anchors.centerIn: parent
                                        text: "🚀 Open"
                                        font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                                        font.bold: true
                                        color: openBtnHover.hovered ? "#000" : panelRoot.liveBase05
                                    }
                                    HoverHandler { id: openBtnHover }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (settingsManager) settingsManager.previewWindow = "";
                                            if (!shell) return;
                                            switch (modelData.id) {
                                                case "launcher": shell.appLauncherWindow.open(); break;
                                                case "calc": shell.calcWindow.open(); break;
                                                case "clipboard": shell.clipboardWindow.open(); break;
                                                case "dictionary": shell.dictionaryWindow.open(); break;
                                                case "unicode": shell.unicodeWindow.open(); break;
                                                case "notes": shell.notesWindow.open(); break;
                                                case "pass": shell.passWindow.open(); break;
                                                case "power": shell.powerWindow.open(); break;
                                                case "todo": shell.todoWindow.open(); break;
                                                case "gemini": shell.geminiWindow.open(); break;
                                                case "settings": shell.settingsWindow.open(); break;
                                                case "web": shell.startPageWindow.open(); break;
                                                case "email": shell.emailWindow.open(); break;
                                                case "amogus": if (shell.amogusWindowInstance) shell.amogusWindowInstance.toggleWindow(); break;
                                            }
                                        }
                                    }
                                }

                                // Opens live preview in front with sliders docked in a static position
                                Rectangle {
                                    width: editBtnRow.implicitWidth + 20
                                    height: Math.max(28, panelRoot.liveFontSize * 1.7)
                                    radius: 4
                                    color: (settingsManager && settingsManager.previewWindow === modelData.id) ? panelRoot.liveBase05 : panelRoot.liveBase02
                                    border.color: panelRoot.liveBase05; border.width: 1

                                    Row {
                                        id: editBtnRow
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text { text: "📐"; font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3); color: (settingsManager && settingsManager.previewWindow === modelData.id) ? panelRoot.liveBase00 : panelRoot.liveBase05; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "Edit"; font.bold: true; font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3); color: (settingsManager && settingsManager.previewWindow === modelData.id) ? panelRoot.liveBase00 : panelRoot.liveBase05; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (settingsManager) {
                                                settingsManager.previewWindow = (settingsManager.previewWindow === modelData.id) ? "" : modelData.id;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
