import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root

    property string windowId: "amogus"
    property var shell: null
    property int currentScreenIndex: 0

    readonly property bool isPreviewMode: (shell && shell.settingsManager && shell.settingsManager.previewWindow === windowId)
    property bool isOpenState: false
    visible: isOpenState || isPreviewMode

    property bool isCardActive: true

    // Focused: base03 | Off-focus: base0D
    readonly property color activeBorderColor: (shell && shell.theme && shell.theme.base03) ? shell.theme.base03 : "#003399"
    readonly property color inactiveBorderColor: (shell && shell.theme && shell.theme.base0D) ? shell.theme.base0D : "#003399"

    onVisibleChanged: {
        if (visible && !isPreviewMode) {
            if (shell && typeof shell.closeOtherOverlays === "function") {
                shell.closeOtherOverlays(root);
            }
            root.isCardActive = true;
        }
    }

    screen: {
        if (Quickshell.screens.length > currentScreenIndex) {
            return Quickshell.screens[currentScreenIndex];
        }
        return Quickshell.screens[0] || null;
    }

    function toggleWindow() {
        if (root.isOpenState) hideWindow();
        else showWindow();
    }

    function showWindow() {
        root.isCardActive = true;
        root.isOpenState = true;
    }

    function activateCard() {
        root.isCardActive = true;
    }

    function hideWindow() {
        root.isOpenState = false;
        root.isCardActive = false;
        if (shell && shell.settingsManager && shell.settingsManager.previewWindow === windowId) {
            shell.settingsManager.previewWindow = "";
        }
    }

    function close() {
        hideWindow();
    }

    // Background listener for Escape: catches Escape globally while Among Us is open, even when unfocused
    Process {
        id: escWatcher
        running: root.isOpenState && !root.isPreviewMode
        command: [
            "python3", "-u", "-c",
            "import glob, struct, select, sys\n" +
            "fds = []\n" +
            "for dev in glob.glob('/dev/input/by-id/*-event-kbd') + glob.glob('/dev/input/event*'):\n" +
            "    try:\n" +
            "        fds.append(open(dev, 'rb', buffering=0))\n" +
            "    except Exception:\n" +
            "        pass\n" +
            "if not fds:\n" +
            "    sys.exit(0)\n" +
            "fmt = 'llHHi' if struct.calcsize('l') == 8 else 'iiHHi'\n" +
            "sz = struct.calcsize(fmt)\n" +
            "while True:\n" +
            "    r, _, _ = select.select(fds, [], [])\n" +
            "    for fd in r:\n" +
            "        try:\n" +
            "            d = fd.read(sz)\n" +
            "            if len(d) == sz:\n" +
            "                _, _, t, code, val = struct.unpack(fmt, d)\n" +
            "                if t == 1 and code == 1 and val == 1:\n" +
            "                    print('ESC', flush=True)\n" +
            "        except Exception:\n" +
            "            pass\n"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim() === "ESC") root.close();
            }
        }
    }

    WlrLayershell.namespace: "quickshell-amogus"
    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        return root.isCardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: root.isCardActive ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: amogusCard }

    color: "transparent"

    // Multi-screen click-off detector
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: otherScreenCatcher
            required property var modelData
            screen: modelData

            visible: root.isOpenState && root.isCardActive && !root.isPreviewMode && (modelData !== root.screen)

            WlrLayershell.namespace: "quickshell-amogus-dismiss"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    root.isCardActive = false;
                }
            }
        }
    }

    // Same-screen click-off detector
    MouseArea {
        anchors.fill: parent
        enabled: root.isCardActive && !root.isPreviewMode
        onPressed: {
            root.isCardActive = false;
        }
    }

    readonly property color themeBase00: (shell && shell.theme && shell.theme.base00) ? shell.theme.base00 : "#11111b"
    readonly property color themeBase01: (shell && shell.theme && shell.theme.base01) ? shell.theme.base01 : "#181825"
    readonly property color themeBase02: (shell && shell.theme && shell.theme.base02) ? shell.theme.base02 : "#313244"
    readonly property color themeBase03: (shell && shell.theme && shell.theme.base03) ? shell.theme.base03 : "#45475a"
    readonly property color themeBase05: (shell && shell.theme && shell.theme.base05) ? shell.theme.base05 : "yellow"
    readonly property color themeBase08: (shell && shell.theme && shell.theme.base08) ? shell.theme.base08 : "#ff5555"
    readonly property color themeBase09: (shell && shell.theme && shell.theme.base09) ? shell.theme.base09 : "#fe8019"
    readonly property color themeBase0C: (shell && shell.theme && shell.theme.base0C) ? shell.theme.base0C : "#04f100"
    readonly property string themeFont: (shell && shell.theme && shell.theme.fontFamily) ? shell.theme.fontFamily : "monospace"

    property var crewmates: [
        { name: "Red",     hex: "#C51111", darkHex: "#7A0808", dead: false },
        { name: "Blue",    hex: "#132ED1", darkHex: "#09158E", dead: false },
        { name: "Green",   hex: "#117F2D", darkHex: "#0A4D1A", dead: false },
        { name: "Pink",    hex: "#ED54BA", darkHex: "#AB2B87", dead: false },
        { name: "Orange",  hex: "#EF7D0D", darkHex: "#B04B00", dead: false },
        { name: "Yellow",  hex: "#F5F557", darkHex: "#C2B219", dead: false },
        { name: "Black",   hex: "#3F474E", darkHex: "#1E1F26", dead: false },
        { name: "White",   hex: "#D6E0F0", darkHex: "#8394BF", dead: false },
        { name: "Purple",  hex: "#6B2FBB", darkHex: "#3B177C", dead: false },
        { name: "Brown",   hex: "#71491E", darkHex: "#46290C", dead: false },
        { name: "Cyan",    hex: "#38FEDC", darkHex: "#24A894", dead: false },
        { name: "Lime",    hex: "#50EF39", darkHex: "#249514", dead: false },
        { name: "Maroon",  hex: "#5F1F2E", darkHex: "#370914", dead: false },
        { name: "Rose",    hex: "#ECC0D3", darkHex: "#A9768B", dead: false },
        { name: "Banana",  hex: "#FFFEA7", darkHex: "#C5C073", dead: false },
        { name: "Gray",    hex: "#758593", darkHex: "#465058", dead: false },
        { name: "Tan",     hex: "#918877", darkHex: "#5E5648", dead: false },
        { name: "Coral",   hex: "#D76464", darkHex: "#963434", dead: false }
    ]

    property var crewModel: []

    function initModel() {
        var arr = [];
        for (var i = 0; i < crewmates.length; i++) {
            arr.push(Object.assign({}, crewmates[i]));
        }
        crewModel = arr;
    }

    Component.onCompleted: {
        initModel();
        if (Quickshell.screens.length > 1) {
            currentScreenIndex = 1;
        }
    }

    function toggleColor(idx) {
        if (idx < 0 || idx >= crewModel.length) return;
        var copy = crewModel.slice();
        copy[idx].dead = !copy[idx].dead;
        crewModel = copy;
    }

    function resetAll() {
        var copy = crewModel.slice();
        for (var i = 0; i < copy.length; i++) {
            copy[i].dead = false;
        }
        crewModel = copy;
    }

    readonly property int aliveCount: {
        var count = 0;
        for (var i = 0; i < crewModel.length; i++) {
            if (!crewModel[i].dead) count++;
        }
        return count;
    }

    readonly property int deadCount: crewModel.length - aliveCount

    Rectangle {
        id: amogusCard
        x: 80
        y: 80
        width: (shell && shell.settingsManager) ? shell.settingsManager.getWindowWidth(root.windowId, 580) : 580
        height: (shell && shell.settingsManager) ? shell.settingsManager.getWindowHeight(root.windowId, 440) : 440
        radius: (shell && shell.theme && shell.theme.defaultCardRadius !== undefined) ? shell.theme.defaultCardRadius : 14
        color: root.themeBase00
        border.color: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
        border.width: (shell && shell.theme && shell.theme.globalBorderWidth !== undefined) ? shell.theme.globalBorderWidth : 2.5

        MouseArea {
            anchors.fill: parent
            enabled: !root.isCardActive && !root.isPreviewMode
            z: 9999
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                root.activateCard();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Rectangle {
                visible: root.isPreviewMode
                Layout.fillWidth: true
                height: 24
                radius: 4
                color: root.themeBase0C
                Text {
                    anchors.centerIn: parent
                    text: "👁 AMONG US PREVIEW — Click to Close"
                    font.bold: true; font.pixelSize: 10; color: "#000"
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 38
                radius: 8
                color: root.themeBase01
                border.color: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
                border.width: 1

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    drag.target: amogusCard
                    drag.minimumX: 0
                    drag.minimumY: 0
                    drag.maximumX: Math.max(0, root.width - amogusCard.width)
                    drag.maximumY: Math.max(0, root.height - amogusCard.height)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "ඞ AMONG US"
                        font.family: root.themeFont
                        font.pixelSize: 15
                        font.bold: true
                        color: root.themeBase05
                    }

                    Row {
                        spacing: 4
                        visible: Quickshell.screens.length > 1

                        Repeater {
                            model: Quickshell.screens
                            delegate: Rectangle {
                                width: scrText.implicitWidth + 12
                                height: 22
                                radius: 4
                                color: root.currentScreenIndex === index ? root.themeBase05 : root.themeBase02
                                border.color: root.themeBase05
                                border.width: 1

                                Text {
                                    id: scrText
                                    anchors.centerIn: parent
                                    text: modelData.name || ("Scr " + (index + 1))
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.currentScreenIndex === index ? root.themeBase00 : root.themeBase05
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentScreenIndex = index;
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.aliveCount + " alive • " + root.deadCount + " dead"
                        font.family: "monospace"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.deadCount > 0 ? root.themeBase09 : root.themeBase0C
                    }

                    Rectangle {
                        width: 72
                        height: 24
                        radius: 4
                        color: resetHov.hovered ? root.themeBase05 : "transparent"
                        border.color: root.themeBase05
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "↺ Reset"
                            font.bold: true
                            font.pixelSize: 11
                            color: resetHov.hovered ? root.themeBase00 : root.themeBase05
                        }

                        HoverHandler { id: resetHov }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetAll()
                        }
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 4
                        color: closeHov.hovered ? root.themeBase08 : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.bold: true
                            font.pixelSize: 13
                            color: closeHov.hovered ? "#000000" : root.themeBase05
                        }

                        HoverHandler { id: closeHov }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.hideWindow()
                        }
                    }
                }
            }

            Grid {
                id: crewGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 6
                columnSpacing: 8
                rowSpacing: 8

                readonly property real cardW: Math.max(20, (width - (5 * 8)) / 6)
                readonly property real cardH: Math.max(20, (height - (2 * 8)) / 3)

                Repeater {
                    model: root.crewModel

                    delegate: Rectangle {
                        id: crewCard
                        readonly property var crewItem: modelData
                        readonly property bool isDead: crewItem.dead

                        width: crewGrid.cardW
                        height: crewGrid.cardH
                        radius: 8

                        color: isDead ? "#121218" : "#1a1a24"
                        border.width: isDead ? 1 : 2
                        border.color: isDead ? "#2a2a38" : crewItem.hex
                        opacity: isDead ? 0.28 : 1.0

                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(parent.parent.width * 0.45, 42)
                                height: width * 1.15
                                radius: width * 0.4
                                color: isDead ? "#333333" : crewItem.hex
                                border.color: isDead ? "#222222" : crewItem.darkHex
                                border.width: 1.5

                                Rectangle {
                                    x: parent.width * 0.28
                                    y: parent.height * 0.25
                                    width: parent.width * 0.65
                                    height: parent.height * 0.35
                                    radius: height / 2
                                    color: isDead ? "#555555" : "#99d9ea"

                                    Rectangle {
                                        x: parent.width * 0.15
                                        y: parent.height * 0.15
                                        width: parent.width * 0.4
                                        height: parent.height * 0.35
                                        radius: height / 2
                                        color: "#ffffff"
                                        opacity: 0.8
                                    }
                                }

                                Text {
                                    visible: crewCard.isDead
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.bold: true
                                    font.pixelSize: parent.width * 0.75
                                    color: "#ff4444"
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: crewItem.name.toUpperCase()
                                font.family: root.themeFont
                                font.pixelSize: 10
                                font.bold: true
                                font.strikeout: crewCard.isDead
                                color: crewCard.isDead ? "#555566" : root.themeBase05
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleColor(index)
                        }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible && !root.isPreviewMode
        onActivated: root.close()
    }
}
