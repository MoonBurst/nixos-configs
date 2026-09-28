import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import "../../style"
import "../../settings"

Item {
    id: panelRoot

    property var shell: null
    property var settingsManager: (shell && shell.settingsManager) ? shell.settingsManager : null
    readonly property var theme: (shell && shell.theme) ? shell.theme : null

    readonly property int liveFontSize: (theme && theme.globalFontSize) ? theme.globalFontSize : 14
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

    anchors.fill: parent
    property int activeTab: 0

    ColorPickerPopup {
        id: guiColorPicker
        theme: panelRoot.theme
        onColorSelected: function(propName, hexStr) {
            if (settingsManager && settingsManager[propName] !== undefined) {
                settingsManager.useStylix = false;
                settingsManager[propName] = hexStr;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: panelRoot.livePadding

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: ["Stylix & Sliders", "Color Palette", "GPU & Hardware", "Bar Layout & Slants", "Overlays & Tools"]
                delegate: Item {
                    Layout.fillWidth: true
                    height: Math.max(34, panelRoot.liveFontSize * 1.8)
                    clip: true

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: "Left"
                        slantRight: "Left"
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
                        font.pixelSize: Math.min(13, panelRoot.liveFontSize - 1)
                        font.bold: true
                        elide: Text.ElideRight
                        color: panelRoot.activeTab === index ? panelRoot.liveBase00 : panelRoot.liveBase05
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: {
                            if (settingsManager) settingsManager.previewCapsule = "";
                            panelRoot.activeTab = index;
                        }
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
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            flickableDirection: Flickable.VerticalFlick
            pressDelay: 120
            contentWidth: width
            contentHeight: tab0Layout.implicitHeight + 80
            visible: panelRoot.activeTab === 0
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

            ColumnLayout {
                id: tab0Layout
                width: parent.width - 16
                spacing: panelRoot.livePadding

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    CyberToggle {
                        label: "Follow Stylix Theme"
                        checked: settingsManager ? settingsManager.useStylix : false
                        theme: panelRoot.theme
                        onToggled: (st) => {
                            if (settingsManager) {
                                settingsManager.useStylix = st;
                                if (st) settingsManager.syncStylixDefaults();
                            }
                        }
                    }

                    Rectangle {
                        width: 140; height: 32; radius: 6
                        color: resyncHover.hovered ? panelRoot.liveBase0C : "transparent"
                        border.color: panelRoot.liveBase0C; border.width: 1.5

                        Text {
                            anchors.centerIn: parent
                            text: "↺ Re-sync with Stylix"
                            font.bold: true; font.pixelSize: 10
                            color: resyncHover.hovered ? panelRoot.liveBase00 : panelRoot.liveBase0C
                        }

                        HoverHandler { id: resyncHover }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true
                            onClicked: if (settingsManager) settingsManager.syncStylixDefaults()
                        }
                    }

                    Rectangle {
                        width: 150; height: 32; radius: 6
                        color: syncNixSizesHover.hovered ? panelRoot.liveBase05 : "transparent"
                        border.color: panelRoot.liveBase05; border.width: 1.5

                        Text {
                            anchors.centerIn: parent
                            text: "💾 Write to theme.nix"
                            font.bold: true; font.pixelSize: 10
                            color: syncNixSizesHover.hovered ? panelRoot.liveBase00 : panelRoot.liveBase05
                        }

                        HoverHandler { id: syncNixSizesHover }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true
                            onClicked: if (settingsManager) settingsManager.syncToNixTheme()
                        }
                    }
                }

                CyberToggle {
                    label: "Enable UI Smooth Animations"
                    checked: settingsManager ? settingsManager.animationsEnabled : true
                    theme: panelRoot.theme
                    onToggled: (st) => { if (settingsManager) settingsManager.animationsEnabled = st; }
                }

                Text {
                    text: settingsManager && settingsManager.animationsEnabled
                        ? "ℹ Smooth animations are ON (150ms-250ms cubic curves)."
                        : "⚡ Smooth animations are OFF (0ms instantaneous 1-frame response)."
                    font.family: panelRoot.liveFontFamily
                    font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                    color: panelRoot.liveBase0C
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                CyberSlider {
                    label: "Top Bar Height"
                    from: 32; to: 64; stepSize: 2; unit: "px"
                    value: settingsManager ? settingsManager.barHeight : 42
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.barHeight = Math.round(v); }
                }

                CyberSlider {
                    label: "Capsule Spacing (Down to -100px for Deep Overlap)"
                    from: -100; to: 20; stepSize: 1; unit: "px"
                    value: settingsManager ? settingsManager.capsuleSpacing : 2
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.capsuleSpacing = v; }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: panelRoot.livePadding

                    CyberSlider {
                        label: "Global Font Size"
                        from: 10; to: 24; stepSize: 1; unit: "px"
                        value: settingsManager ? settingsManager.globalFontSize : 14
                        theme: panelRoot.theme
                        onValueModified: (v) => {
                            if (settingsManager) {
                                settingsManager.useStylix = false;
                                settingsManager.globalFontSize = v;
                            }
                        }
                    }

                    CyberSlider {
                        label: "Capsule Slant Width"
                        from: 4; to: 24; stepSize: 1; unit: "px"
                        value: settingsManager ? settingsManager.slantWidth : 12
                        theme: panelRoot.theme
                        onValueModified: (v) => {
                            if (settingsManager) {
                                settingsManager.useStylix = false;
                                settingsManager.slantWidth = v;
                            }
                        }
                    }

                    CyberSlider {
                        label: "Global Border Width"
                        from: 1; to: 6; stepSize: 1; unit: "px"
                        value: settingsManager ? settingsManager.globalBorderWidth : 3
                        theme: panelRoot.theme
                        onValueModified: (v) => {
                            if (settingsManager) {
                                settingsManager.useStylix = false;
                                settingsManager.globalBorderWidth = v;
                            }
                        }
                    }

                    CyberSlider {
                        label: "Global Container Padding"
                        from: 4; to: 24; stepSize: 2; unit: "px"
                        value: settingsManager ? settingsManager.globalPadding : 12
                        theme: panelRoot.theme
                        onValueModified: (v) => {
                            if (settingsManager) {
                                settingsManager.useStylix = false;
                                settingsManager.globalPadding = v;
                            }
                        }
                    }
                }
            }
        }

        // TAB 1: COLOR PALETTE
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            flickableDirection: Flickable.VerticalFlick
            pressDelay: 120
            contentWidth: width
            contentHeight: tab1Layout.implicitHeight + 80
            visible: panelRoot.activeTab === 1
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

            ColumnLayout {
                id: tab1Layout
                width: parent.width - 16
                spacing: panelRoot.livePadding

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "🎨 COLOR SCHEME OVERRIDES (Click square for GUI Picker)"
                        font.pixelSize: panelRoot.liveFontSize; font.bold: true
                        color: panelRoot.liveBase05
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 150; height: 32; radius: 6
                        color: syncNixHover.hovered ? panelRoot.liveBase0C : "transparent"
                        border.color: panelRoot.liveBase0C; border.width: 1.5

                        Text {
                            anchors.centerIn: parent
                            text: "💾 Write to theme.nix"
                            font.bold: true; font.pixelSize: 11
                            color: syncNixHover.hovered ? panelRoot.liveBase00 : panelRoot.liveBase0C
                        }

                        HoverHandler { id: syncNixHover }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true
                            onClicked: if (settingsManager) settingsManager.syncToNixTheme()
                        }
                    }
                }

                Repeater {
                    model: [
                        { name: "Primary Background (base00)", prop: "customBase00", def: "#0f0f0f" },
                        { name: "Slanted Bar Border (base03)", prop: "customBase03", def: "#003399" },
                        { name: "Primary Accent / Text (base05)", prop: "customBase05", def: "#f7f700" },
                        { name: "Danger / Alert Red (base08)", prop: "customBase08", def: "#ff0000" },
                        { name: "Warning / Elevated Orange (base09)", prop: "customBase09", def: "#fe8019" },
                        { name: "Success / Metric Green (base0C)", prop: "customBase0C", def: "#04f100" },
                        { name: "Accent Blue / Focus (base0D)", prop: "customBase0D", def: "#003399" }
                    ]

                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            width: 34; height: 34; radius: 6
                            color: settingsManager ? settingsManager[modelData.prop] : modelData.def
                            border.width: 2; border.color: "#ffffff"

                            Text { anchors.centerIn: parent; text: "🎨"; font.pixelSize: 12; opacity: 0.6 }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true
                                onClicked: {
                                    var curCol = settingsManager ? settingsManager[modelData.prop] : modelData.def;
                                    guiColorPicker.openPicker(modelData.prop, curCol);
                                }
                            }
                        }

                        Text {
                            text: modelData.name
                            font.family: panelRoot.liveFontFamily
                            font.pixelSize: panelRoot.liveFontSize
                            color: panelRoot.liveBase05
                            Layout.fillWidth: true
                        }

                        TextField {
                            text: settingsManager ? settingsManager[modelData.prop] : modelData.def
                            font.family: "monospace"
                            font.pixelSize: panelRoot.liveFontSize - 1
                            color: panelRoot.liveBase05
                            background: Rectangle {
                                implicitWidth: 100; implicitHeight: 30
                                color: panelRoot.liveBase02
                                border.color: panelRoot.liveBase03
                                border.width: 1; radius: 4
                            }
                            onTextChanged: if (text.length === 7 && text.startsWith("#") && settingsManager) settingsManager[modelData.prop] = text
                        }
                    }
                }
            }
        }

        // TAB 2: MULTI-GPU & HARDWARE
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            flickableDirection: Flickable.VerticalFlick
            pressDelay: 120
            contentWidth: width
            contentHeight: tab2Layout.implicitHeight + 80
            visible: panelRoot.activeTab === 2
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

            ColumnLayout {
                id: tab2Layout
                width: parent.width - 16
                spacing: 16

                Text {
                    text: "🎮 MULTI-GPU & HARDWARE CONFIGURATION"
                    font.pixelSize: panelRoot.liveFontSize; font.bold: true
                    color: panelRoot.liveBase05
                }

                CyberSlider {
                    label: "Hardware Polling Interval (CPU, RAM, GPU, Net)"
                    from: 1000; to: 10000; stepSize: 500; unit: "ms"
                    value: settingsManager ? settingsManager.hardwarePollInterval : 2000
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.hardwarePollInterval = Math.round(v); }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: (settingsManager && settingsManager.discoveredGpus.length > 0)
                            ? settingsManager.discoveredGpus
                            : [{ id: "card0", name: "RX 7900 XTX" }, { id: "card1", name: "Radeon Graphics" }]

                        delegate: Rectangle {
                            readonly property bool isEditing: panelRoot.editingGpuCard === modelData.id
                            readonly property bool isMonitored: settingsManager && settingsManager.activeGpuCard === modelData.id

                            Layout.fillWidth: true
                            height: 42
                            radius: 6
                            color: isEditing ? panelRoot.liveBase05 : panelRoot.liveBase00
                            border.width: 1.5
                            border.color: isMonitored ? panelRoot.liveBase0C : panelRoot.liveBase03

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: modelData.name + " (" + modelData.id + ")" + (isMonitored ? " [ACTIVE BAR]" : "")
                                    font.bold: true; font.pixelSize: 12
                                    color: isEditing ? panelRoot.liveBase00 : panelRoot.liveBase05
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true
                                onClicked: {
                                    panelRoot.editingGpuCard = modelData.id;
                                    if (settingsManager) settingsManager.activeGpuCard = modelData.id;
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    CyberSlider {
                        label: "[" + panelRoot.editingGpuCard + "] Temperature Warning Threshold (Orange if ≥ X°C)"
                        from: 0; to: 110; stepSize: 1; unit: "°C"
                        value: settingsManager ? settingsManager.getGpuTempWarn(panelRoot.editingGpuCard) : 70
                        theme: panelRoot.theme
                        onValueModified: (v) => { if (settingsManager) settingsManager.setGpuThreshold(panelRoot.editingGpuCard, "tempWarn", v); }
                    }

                    CyberSlider {
                        label: "[" + panelRoot.editingGpuCard + "] Temperature Danger Threshold (Red if ≥ X°C)"
                        from: 0; to: 115; stepSize: 1; unit: "°C"
                        value: settingsManager ? settingsManager.getGpuTempDanger(panelRoot.editingGpuCard) : 80
                        theme: panelRoot.theme
                        onValueModified: (v) => { if (settingsManager) settingsManager.setGpuThreshold(panelRoot.editingGpuCard, "tempDanger", v); }
                    }

                    CyberSlider {
                        label: "[" + panelRoot.editingGpuCard + "] Low Free VRAM Warning (Orange if Free ≤ X GiB)"
                        from: 0; to: 64; stepSize: 1; unit: "GiB"
                        value: settingsManager ? settingsManager.getGpuVramWarn(panelRoot.editingGpuCard) : 4
                        theme: panelRoot.theme
                        onValueModified: (v) => { if (settingsManager) settingsManager.setGpuThreshold(panelRoot.editingGpuCard, "vramWarn", v); }
                    }

                    CyberSlider {
                        label: "[" + panelRoot.editingGpuCard + "] Critical Free VRAM Danger (Red if Free ≤ X GiB)"
                        from: 0; to: 64; stepSize: 1; unit: "GiB"
                        value: settingsManager ? settingsManager.getGpuVramDanger(panelRoot.editingGpuCard) : 2
                        theme: panelRoot.theme
                        onValueModified: (v) => { if (settingsManager) settingsManager.setGpuThreshold(panelRoot.editingGpuCard, "vramDanger", v); }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: panelRoot.liveBase03 }

                Text {
                    text: "🔊 AUDIO CONTROLS"
                    font.pixelSize: panelRoot.liveFontSize; font.bold: true
                    color: panelRoot.liveBase05
                }

                CyberSlider {
                    label: "Master Output Volume (PipeWire)"
                    from: 0; to: 100; stepSize: 2; unit: "%"
                    value: settingsManager ? settingsManager.masterVolume : 80
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.masterVolume = v; }
                }

                CyberSlider {
                    label: "Microphone Capture Level"
                    from: 0; to: 100; stepSize: 2; unit: "%"
                    value: settingsManager ? settingsManager.micVolume : 100
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.micVolume = v; }
                }

                CyberToggle {
                    label: "Microphone Muted"
                    checked: settingsManager ? settingsManager.micMuted : false
                    theme: panelRoot.theme
                    onToggled: (st) => { if (settingsManager) settingsManager.micMuted = st; }
                }
            }
        }

        // TAB 3: BAR LAYOUT & PER-MODULE SLANTS
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            flickableDirection: Flickable.VerticalFlick
            pressDelay: 120
            contentWidth: width
            contentHeight: tab3Layout.implicitHeight + 80
            visible: panelRoot.activeTab === 3
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

            ColumnLayout {
                id: tab3Layout
                width: parent.width - 16
                spacing: 16

                Text {
                    text: "📊 REORDER CAPSULES & PER-MODULE SLANTS"
                    font.pixelSize: panelRoot.liveFontSize; font.bold: true
                    color: panelRoot.liveBase05
                }

                Repeater {
                    model: [
                        { id: "left", label: "LEFT BAR SECTION", list: settingsManager ? settingsManager.getLeftList() : ["calendar", "music", "alarm", "weather", "unified", "notify"] },
                        { id: "center", label: "CENTER BAR SECTION", list: settingsManager ? settingsManager.getCenterList() : ["audio", "clock", "mic"] },
                        { id: "right", label: "RIGHT BAR SECTION", list: settingsManager ? settingsManager.getRightList() : ["tray", "ram", "gpu", "cpu", "net", "battery"] }
                    ]

                    delegate: ColumnLayout {
                        id: sectionBlock
                        readonly property string currentSection: modelData.id
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: modelData.label
                            font.bold: true; font.pixelSize: panelRoot.liveFontSize - 1
                            color: panelRoot.liveBase0C
                        }

                        Repeater {
                            model: modelData.list

                            delegate: Rectangle {
                                id: cardDelegate
                                readonly property int itemIdx: index
                                readonly property string currentSlant: settingsManager ? settingsManager.getModuleSlant(modelData, sectionBlock.currentSection) : "left"
                                property bool drawerExpanded: false

                                Layout.fillWidth: true
                                Layout.preferredHeight: drawerExpanded ? 155 : 44
                                Layout.minimumHeight: Layout.preferredHeight
                                height: Layout.preferredHeight
                                radius: 6
                                color: panelRoot.liveBase00
                                border.width: 1
                                border.color: drawerExpanded ? panelRoot.liveBase05 : panelRoot.liveBase03
                                clip: true

                                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        height: 32
                                        spacing: 8

                                        Rectangle {
                                            width: 26; height: 26; radius: 4
                                            color: upHover.hovered ? panelRoot.liveBase02 : "transparent"
                                            border.width: 1; border.color: panelRoot.liveBase03
                                            Text { anchors.centerIn: parent; text: "▲"; font.bold: true; font.pixelSize: 11; color: panelRoot.liveBase05 }
                                            HoverHandler { id: upHover }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true; onClicked: settingsManager.moveWithinSection(sectionBlock.currentSection, itemIdx, itemIdx - 1) }
                                        }

                                        Rectangle {
                                            width: 26; height: 26; radius: 4
                                            color: downHover.hovered ? panelRoot.liveBase02 : "transparent"
                                            border.width: 1; border.color: panelRoot.liveBase03
                                            Text { anchors.centerIn: parent; text: "▼"; font.bold: true; font.pixelSize: 11; color: panelRoot.liveBase05 }
                                            HoverHandler { id: downHover }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true; onClicked: settingsManager.moveWithinSection(sectionBlock.currentSection, itemIdx, itemIdx + 1) }
                                        }

                                        Text {
                                            text: modelData.toUpperCase()
                                            font.bold: true; font.pixelSize: panelRoot.liveFontSize - 1
                                            color: panelRoot.liveBase05
                                            Layout.fillWidth: true
                                        }

                                        Row {
                                            spacing: 2
                                            Rectangle {
                                                width: 26; height: 24; radius: 3
                                                color: currentSlant === "left" ? panelRoot.liveBase05 : panelRoot.liveBase02
                                                border.width: 1; border.color: panelRoot.liveBase03
                                                Text { anchors.centerIn: parent; text: "\\ \\"; font.bold: true; font.pixelSize: 9; color: currentSlant === "left" ? panelRoot.liveBase00 : panelRoot.liveBase05 }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true; onClicked: settingsManager.setModuleSlant(modelData, "left") }
                                            }
                                            Rectangle {
                                                width: 26; height: 24; radius: 3
                                                color: currentSlant === "center" ? panelRoot.liveBase05 : panelRoot.liveBase02
                                                border.width: 1; border.color: panelRoot.liveBase03
                                                Text { anchors.centerIn: parent; text: "\\ /"; font.bold: true; font.pixelSize: 9; color: currentSlant === "center" ? panelRoot.liveBase00 : panelRoot.liveBase05 }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true; onClicked: settingsManager.setModuleSlant(modelData, "center") }
                                            }
                                            Rectangle {
                                                width: 26; height: 24; radius: 3
                                                color: currentSlant === "right" ? panelRoot.liveBase05 : panelRoot.liveBase02
                                                border.width: 1; border.color: panelRoot.liveBase03
                                                Text { anchors.centerIn: parent; text: "/ /"; font.bold: true; font.pixelSize: 9; color: currentSlant === "right" ? panelRoot.liveBase00 : panelRoot.liveBase05 }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true; onClicked: settingsManager.setModuleSlant(modelData, "right") }
                                            }
                                        }

                                        Rectangle {
                                            width: 32; height: 24; radius: 4
                                            color: cardDelegate.drawerExpanded ? panelRoot.liveBase05 : panelRoot.liveBase02
                                            border.color: panelRoot.liveBase05; border.width: 1
                                            Text { anchors.centerIn: parent; text: "📐"; font.pixelSize: 11; opacity: cardDelegate.drawerExpanded ? 1.0 : 0.8 }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                preventStealing: true
                                                onClicked: {
                                                    cardDelegate.drawerExpanded = !cardDelegate.drawerExpanded;
                                                    if (settingsManager) {
                                                        settingsManager.previewCapsule = cardDelegate.drawerExpanded ? modelData : "";
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 52; height: 24; radius: 4
                                            color: settingsManager.isCapsuleVisible(modelData) ? panelRoot.liveBase0C : panelRoot.liveBase08
                                            Text { anchors.centerIn: parent; text: settingsManager.isCapsuleVisible(modelData) ? "SHOW" : "HIDE"; font.pixelSize: 9; font.bold: true; color: "#11111b" }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true; onClicked: settingsManager.toggleCapsuleVisibility(modelData) }
                                        }

                                        Row {
                                            spacing: 2
                                            Rectangle {
                                                width: 22; height: 24; radius: 3
                                                color: sectionBlock.currentSection === "left" ? panelRoot.liveBase05 : panelRoot.liveBase02
                                                Text { anchors.centerIn: parent; text: "L"; font.bold: true; font.pixelSize: 9; color: sectionBlock.currentSection === "left" ? panelRoot.liveBase00 : panelRoot.liveBase05 }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true; onClicked: settingsManager.moveModule(modelData, "left", 99) }
                                            }
                                            Rectangle {
                                                width: 22; height: 24; radius: 3
                                                color: sectionBlock.currentSection === "center" ? panelRoot.liveBase05 : panelRoot.liveBase02
                                                Text { anchors.centerIn: parent; text: "C"; font.bold: true; font.pixelSize: 9; color: sectionBlock.currentSection === "center" ? panelRoot.liveBase00 : panelRoot.liveBase05 }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true; onClicked: settingsManager.moveModule(modelData, "center", 99) }
                                            }
                                            Rectangle {
                                                width: 22; height: 24; radius: 3
                                                color: sectionBlock.currentSection === "right" ? panelRoot.liveBase05 : panelRoot.liveBase02
                                                Text { anchors.centerIn: parent; text: "R"; font.bold: true; font.pixelSize: 9; color: sectionBlock.currentSection === "right" ? panelRoot.liveBase00 : panelRoot.liveBase05 }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true; onClicked: settingsManager.moveModule(modelData, "right", 99) }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        visible: cardDelegate.drawerExpanded
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12

                                            CyberSlider {
                                                label: "Tooltip Width"
                                                from: 300; to: 1400; stepSize: 20; unit: "px"
                                                value: settingsManager ? (settingsManager.getCapsuleWidth(modelData) || 500) : 500
                                                theme: panelRoot.theme
                                                Layout.fillWidth: true
                                                onValueModified: (v) => { if (settingsManager) settingsManager.setCapsuleWidth(modelData, v); }
                                            }

                                            CyberSlider {
                                                label: "Tooltip Height"
                                                from: 180; to: 750; stepSize: 20; unit: "px"
                                                value: settingsManager ? (settingsManager.getCapsuleHeight(modelData) || 460) : 460
                                                theme: panelRoot.theme
                                                Layout.fillWidth: true
                                                onValueModified: (v) => { if (settingsManager) settingsManager.setCapsuleHeight(modelData, v); }
                                            }

                                            Rectangle {
                                                width: 60; height: 28; radius: 4
                                                color: rstHov.hovered ? panelRoot.liveBase08 : "transparent"
                                                border.color: panelRoot.liveBase08; border.width: 1
                                                Layout.alignment: Qt.AlignVCenter
                                                Text { anchors.centerIn: parent; text: "↺ Reset"; font.pixelSize: 10; font.bold: true; color: rstHov.hovered ? "#000000" : panelRoot.liveBase08 }
                                                HoverHandler { id: rstHov }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (settingsManager) settingsManager.resetCapsuleSize(modelData); }
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

        // TAB 4: OVERLAYS & TOOLS
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            flickableDirection: Flickable.VerticalFlick
            pressDelay: 120
            contentWidth: width
            contentHeight: tab4Layout.implicitHeight + 140
            visible: panelRoot.activeTab === 4
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

            ColumnLayout {
                id: tab4Layout
                width: parent.width - 16
                spacing: 16

                Text {
                    text: "🔔 NOTIFICATIONS & DISPLAY ROUTING"
                    font.pixelSize: panelRoot.liveFontSize; font.bold: true
                    color: panelRoot.liveBase0C
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Target Display:"; color: panelRoot.liveBase05; font.bold: true; font.pixelSize: 13
                    }

                    Repeater {
                        model: {
                            var list = ["Auto"];
                            if (typeof Quickshell !== "undefined" && Quickshell.screens) {
                                for (var i = 0; i < Quickshell.screens.length; i++) {
                                    if (Quickshell.screens[i] && Quickshell.screens[i].name) {
                                        list.push(Quickshell.screens[i].name);
                                    }
                                }
                            }
                            return list;
                        }
                        delegate: Rectangle {
                            readonly property bool isSelected: {
                                var cur = settingsManager ? settingsManager.notifScreenName : "";
                                return (modelData === "Auto" && cur === "") || (modelData === cur);
                            }
                            width: screenBtnText.implicitWidth + 20
                            height: 30
                            radius: 4
                            color: isSelected ? panelRoot.liveBase05 : panelRoot.liveBase02
                            border.color: panelRoot.liveBase05
                            border.width: 1

                            Text {
                                id: screenBtnText
                                anchors.centerIn: parent
                                text: modelData
                                font.bold: true
                                font.pixelSize: 11
                                color: isSelected ? panelRoot.liveBase00 : panelRoot.liveBase05
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (settingsManager) {
                                        settingsManager.notifScreenName = (modelData === "Auto") ? "" : modelData;
                                        if (shell && shell.notificationOverlay) {
                                            shell.notificationOverlay.triggerPreviewNotification();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 130
                        height: 30
                        radius: 4
                        color: testHover.hovered ? panelRoot.liveBase0C : "transparent"
                        border.color: panelRoot.liveBase0C
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "🔔 Test Popup"
                            font.bold: true
                            font.pixelSize: 11
                            color: testHover.hovered ? panelRoot.liveBase00 : panelRoot.liveBase0C
                        }

                        HoverHandler { id: testHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (shell && shell.notificationOverlay) {
                                    shell.notificationOverlay.triggerPreviewNotification();
                                }
                            }
                        }
                    }
                }

                CyberSlider {
                    label: "Notification Card Stacking Overlap"
                    from: 0; to: 150; stepSize: 5; unit: "px"
                    value: settingsManager ? settingsManager.notifStackOverlap : 25
                    theme: panelRoot.theme
                    onValueModified: (v) => {
                        if (settingsManager) {
                            settingsManager.notifStackOverlap = Math.round(v);
                            if (shell && shell.notificationOverlay) {
                                shell.notificationOverlay.triggerPreviewNotification();
                            }
                        }
                    }
                }

                CyberSlider {
                    label: "Toast Notification Vertical Y-Position (Live Preview)"
                    from: 50; to: 950; stepSize: 25; unit: "px"
                    value: settingsManager ? settingsManager.notifBaselineY : 350
                    theme: panelRoot.theme
                    onValueModified: (v) => {
                        if (settingsManager) {
                            settingsManager.notifBaselineY = Math.round(v);
                            if (shell && shell.notificationOverlay) {
                                shell.notificationOverlay.triggerPreviewNotification(Math.round(v));
                            }
                        }
                    }
                }

                CyberSlider {
                    label: "Toast Display Duration"
                    from: 2; to: 20; stepSize: 1; unit: "s"
                    value: settingsManager ? settingsManager.notifHoldDurationSec : 5
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.notifHoldDurationSec = Math.round(v); }
                }

                CyberSlider {
                    label: "Notification Audio Volume"
                    from: 0; to: 100; stepSize: 5; unit: "%"
                    value: settingsManager ? settingsManager.notifVolume : 80
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.notifVolume = Math.round(v); }
                }

                CyberToggle {
                    label: "Enable Text-to-Speech Voice Alerts (sage-tts)"
                    checked: settingsManager ? settingsManager.enableTts : true
                    theme: panelRoot.theme
                    onToggled: (st) => { if (settingsManager) settingsManager.enableTts = st; }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: panelRoot.liveBase03 }

                Text {
                    text: "🚀 LAUNCHER SIZING & PREFERENCES"
                    font.pixelSize: panelRoot.liveFontSize; font.bold: true
                    color: panelRoot.liveBase0C
                }

                CyberSlider {
                    label: "Launcher Window Width"
                    from: 650; to: 1200; stepSize: 20; unit: "px"
                    value: settingsManager ? settingsManager.launcherWidth : 840
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.launcherWidth = Math.round(v); }
                }

                CyberSlider {
                    label: "Launcher Window Height"
                    from: 450; to: 950; stepSize: 25; unit: "px"
                    value: settingsManager ? settingsManager.launcherHeight : 700
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.launcherHeight = Math.round(v); }
                }

                CyberSlider {
                    label: "App Result Card Height"
                    from: 50; to: 110; stepSize: 5; unit: "px"
                    value: settingsManager ? settingsManager.appItemHeight : 80
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.appItemHeight = Math.round(v); }
                }

                CyberSlider {
                    label: "App Icon Size"
                    from: 20; to: 64; stepSize: 4; unit: "px"
                    value: settingsManager ? settingsManager.appIconSize : 32
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.appIconSize = Math.round(v); }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "Default Mode:"; color: panelRoot.liveBase05; font.bold: true; font.pixelSize: 13 }
                    Repeater {
                        model: ["apps", "clipboard", "pass", "todo", "notes"]
                        delegate: Rectangle {
                            width: 75; height: 30; radius: 4
                            color: (settingsManager && settingsManager.defaultLauncherMode === modelData) ? panelRoot.liveBase05 : panelRoot.liveBase02
                            border.color: panelRoot.liveBase05; border.width: 1
                            Text { anchors.centerIn: parent; text: modelData.toUpperCase(); font.bold: true; font.pixelSize: 10; color: (settingsManager && settingsManager.defaultLauncherMode === modelData) ? panelRoot.liveBase00 : panelRoot.liveBase05 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (settingsManager) settingsManager.defaultLauncherMode = modelData }
                        }
                    }
                }

                CyberSlider {
                    label: "Clipboard Max Search History"
                    from: 50; to: 500; stepSize: 25; unit: " items"
                    value: settingsManager ? settingsManager.clipboardMaxItems : 200
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.clipboardMaxItems = Math.round(v); }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text { text: "Notes File Path:"; color: panelRoot.liveBase05; font.bold: true; font.pixelSize: 13 }
                    TextField {
                        Layout.fillWidth: true
                        text: settingsManager ? settingsManager.notesFilePath : ""
                        font.family: "monospace"; font.pixelSize: 12
                        color: panelRoot.liveBase05
                        background: Rectangle { color: panelRoot.liveBase02; border.color: panelRoot.liveBase03; border.width: 1; radius: 4 }
                        onTextEdited: if (settingsManager) settingsManager.notesFilePath = text
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: panelRoot.liveBase03 }

                Text {
                    text: "🔍 SCREEN MAGNIFIER"
                    font.pixelSize: panelRoot.liveFontSize; font.bold: true
                    color: panelRoot.liveBase0C
                }

                CyberSlider {
                    label: "Default Startup Zoom Level"
                    from: 2; to: 20; stepSize: 1; unit: "x"
                    value: settingsManager ? settingsManager.magnifierDefaultZoom : 8.0
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.magnifierDefaultZoom = Math.round(v); }
                }

                CyberSlider {
                    label: "Magnifier Lens Size"
                    from: 150; to: 500; stepSize: 25; unit: "px"
                    value: settingsManager ? settingsManager.magnifierLensSize : 300
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.magnifierLensSize = Math.round(v); }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: panelRoot.liveBase03 }

                Text {
                    text: "📸 QUICKSHOT SCREENSHOT STUDIO"
                    font.pixelSize: panelRoot.liveFontSize; font.bold: true
                    color: panelRoot.liveBase0C
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text { text: "Save Path:"; color: panelRoot.liveBase05; font.bold: true; font.pixelSize: 13 }
                    TextField {
                        Layout.fillWidth: true
                        text: settingsManager ? settingsManager.screenshotSaveDir : ""
                        font.family: "monospace"; font.pixelSize: 12
                        color: panelRoot.liveBase05
                        background: Rectangle { color: panelRoot.liveBase02; border.color: panelRoot.liveBase03; border.width: 1; radius: 4 }
                        onTextEdited: if (settingsManager) settingsManager.screenshotSaveDir = text
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text { text: "Default Watermark Tag:"; color: panelRoot.liveBase05; font.bold: true; font.pixelSize: 13 }
                    TextField {
                        Layout.fillWidth: true
                        placeholderText: "e.g. internal, confidential..."
                        text: settingsManager ? settingsManager.defaultWatermarkTag : ""
                        font.family: "monospace"; font.pixelSize: 12
                        color: panelRoot.liveBase05
                        background: Rectangle { color: panelRoot.liveBase02; border.color: panelRoot.liveBase03; border.width: 1; radius: 4 }
                        onTextEdited: if (settingsManager) settingsManager.defaultWatermarkTag = text
                    }
                }

                CyberSlider {
                    label: "Screenshot Cache Retention Limit"
                    from: 10; to: 200; stepSize: 10; unit: " shots"
                    value: settingsManager ? settingsManager.quickshotHistoryLimit : 50
                    theme: panelRoot.theme
                    onValueModified: (v) => { if (settingsManager) settingsManager.quickshotHistoryLimit = Math.round(v); }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: panelRoot.liveBase03 }

                Text {
                    text: "🤖 AI & LAUNCHER PREFERENCES"
                    font.pixelSize: panelRoot.liveFontSize; font.bold: true
                    color: panelRoot.liveBase0C
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text { text: "Gemini Model:"; color: panelRoot.liveBase05; font.bold: true; font.pixelSize: 13 }

                    Rectangle {
                        width: 160; height: 32; radius: 4
                        color: (settingsManager && settingsManager.geminiModelName === "gemini-flash-latest") ? panelRoot.liveBase05 : panelRoot.liveBase02
                        border.color: panelRoot.liveBase05; border.width: 1
                        Text { anchors.centerIn: parent; text: "⚡ Flash (Fast)"; font.bold: true; font.pixelSize: 12; color: (settingsManager && settingsManager.geminiModelName === "gemini-flash-latest") ? panelRoot.liveBase00 : panelRoot.liveBase05 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (settingsManager) settingsManager.geminiModelName = "gemini-flash-latest" }
                    }

                    Rectangle {
                        width: 160; height: 32; radius: 4
                        color: (settingsManager && settingsManager.geminiModelName === "gemini-pro-latest") ? panelRoot.liveBase05 : panelRoot.liveBase02
                        border.color: panelRoot.liveBase05; border.width: 1
                        Text { anchors.centerIn: parent; text: "🧠 Pro (Deep Reasoning)"; font.bold: true; font.pixelSize: 12; color: (settingsManager && settingsManager.geminiModelName === "gemini-pro-latest") ? panelRoot.liveBase00 : panelRoot.liveBase05 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (settingsManager) settingsManager.geminiModelName = "gemini-pro-latest" }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: panelRoot.liveBase03 }

                Text {
                    text: "✉️ EMAIL SIGNATURE"
                    font.pixelSize: panelRoot.liveFontSize; font.bold: true
                    color: panelRoot.liveBase0C
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 110
                    radius: 6
                    color: "#000000"
                    border.color: panelRoot.liveBase05
                    border.width: 1.5
                    clip: true

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 6
                        clip: true

                        TextArea {
                            id: sigArea
                            background: null
                            color: "#f7f700"
                            selectionColor: panelRoot.liveBase03
                            selectedTextColor: "#ffffff"
                            font.family: "monospace"
                            font.pixelSize: 13
                            text: settingsManager ? settingsManager.emailSignature : ""
                            wrapMode: Text.Wrap
                            selectByMouse: true
                            onTextChanged: if (settingsManager && activeFocus) settingsManager.emailSignature = text
                        }
                    }
                }
            }
        }
    }
}
