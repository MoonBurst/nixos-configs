import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style" as Style
import "../../common" as Common
import "../../common/Utils.js" as Utils
import "../../settings" as SettingsTools

PanelWindow {
    id: root

    property string windowId: "rng"
    property var shell: null
    readonly property var safeShell: (typeof shell !== "undefined" && shell) ? shell : null
    readonly property var settingsManager: safeShell ? safeShell.settingsManager : null
    readonly property var theme: (safeShell && safeShell.theme) ? safeShell.theme : null

    property string detectedFocusedScreenName: ""

    screen: {
        var target = settingsManager ? settingsManager.rngScreenTarget : "focused";
        if (target === "focused" || target === "") {
            if (detectedFocusedScreenName !== "") {
                var foundFocused = Quickshell.screens.find(s => s.name === detectedFocusedScreenName);
                if (foundFocused) return foundFocused;
            }
            return null;
        }
        var found = Quickshell.screens.find(s => s.name === target);
        if (found) return found;
        return null;
    }

    readonly property bool isPreviewMode: (settingsManager && settingsManager.previewWindow === windowId)
    property bool isOpenState: false
    visible: isOpenState || isPreviewMode

    property bool isCardActive: true

    readonly property color activeBorderColor: (theme && theme.base03) ? theme.base03 : "#003399"
    readonly property color inactiveBorderColor: (theme && theme.base0D) ? theme.base0D : "#003399"

    WlrLayershell.layer: isPreviewMode ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!visible || isPreviewMode) return WlrKeyboardFocus.None;
        return root.isCardActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    mask: root.isCardActive ? null : cardMaskRegion
    Region { id: cardMaskRegion; item: diceCard }

    function openWithTarget() {
        var target = settingsManager ? settingsManager.rngScreenTarget : "focused";
        if (target === "focused" || target === "") {
            focusDetector.running = false;
            focusDetector.running = true;
        }
        root.isCardActive = true;
        root.isOpenState = true;
    }

    function activateCard() {
        root.isCardActive = true;
    }

    function toggleWithTarget() {
        if (root.isOpenState) root.close();
        else openWithTarget();
    }

    function close() {
        root.isOpenState = false;
        root.isCardActive = false;
        if (settingsManager && settingsManager.previewWindow === windowId) {
            settingsManager.previewWindow = "";
        }
    }

    Common.GlobalEscWatcher {
        active: root.isOpenState && !root.isPreviewMode
        onEscapePressed: root.close()
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: otherScreenCatcher
            required property var modelData
            screen: modelData

            visible: root.isOpenState && root.isCardActive && !root.isPreviewMode && (modelData !== root.screen)

            WlrLayershell.namespace: "quickshell-rng-dismiss"
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

    MouseArea {
        anchors.fill: parent
        enabled: root.isCardActive && !root.isPreviewMode
        onPressed: {
            root.isCardActive = false;
        }
    }

    Process {
        id: focusDetector
        command: [
            "sh", "-c",
            "hyprctl monitors 2>/dev/null | awk '/^Monitor/ {m=$2} /focused: (yes|true)/ {print m; exit}' || swaymsg -t get_outputs 2>/dev/null | awk '/name:/ {name=$2} /focused.*true/ {print name; exit}' | tr -d '\", \\t' || echo ''"
        ]
        stdout: SplitParser {
            onRead: data => {
                var name = data.trim();
                if (name.length > 0) root.detectedFocusedScreenName = name;
            }
        }
    }

    Timer {
        interval: 1500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var target = settingsManager ? settingsManager.rngScreenTarget : "focused";
            if (target === "focused" || target === "") focusDetector.running = true;
        }
    }

    readonly property color bgBase: theme ? theme.base01 : "#1e1e2e"
    readonly property color bgCard: theme ? theme.base00 : "#181825"
    readonly property color bgHover: theme ? theme.base02 : "#313244"
    readonly property color textColor: theme ? theme.base05 : "#cdd6f4"
    readonly property color accentColor: theme ? theme.base05 : "#a6e3a1"
    readonly property color altAccent: theme ? theme.base05 : "#f38ba8"
    readonly property color highlightColor: theme ? theme.base05 : "#f9e2af"

    readonly property int globalBorderWidth: (theme && theme.globalBorderWidth !== undefined) ? theme.globalBorderWidth : 3
    readonly property int controlBorderWidth: (settingsManager && settingsManager.controlBorderWidth)
        ? settingsManager.controlBorderWidth
        : ((theme && theme.controlBorderWidth) ? theme.controlBorderWidth : 2)

    readonly property var inputPad: Utils.getSafeInputPadding(settingsManager)

    property int diceCount: 1
    property int strengthVal: 0
    property int flatModVal: 0
    property int customSidesVal: 3
    property int selectedSides: 6
    property string keepMode: "all"
    property int keepCount: 1

    property string lastRollType: "None"
    property var lastRolls: []
    property var previewRolls: []
    property int lastTotal: 0
    property real lastAverage: 0.0
    property string coinResult: ""
    property bool showHistoryPanel: false

    onDiceCountChanged: root.lastRolls = []
    onSelectedSidesChanged: root.lastRolls = []

    ListModel { id: historyModel }

    Timer {
        id: marioPartyTimer
        interval: 60; repeat: true
        running: root.visible && root.lastRolls.length === 0 && !root.showHistoryPanel
        onTriggered: {
            var tempPreview = [];
            var count = Math.min(30, root.diceCount);
            var sides = root.selectedSides < 2 ? 2 : root.selectedSides;
            for (var i = 0; i < count; i++) {
                if (sides === 2) tempPreview.push(Math.random() < 0.5 ? "H" : "T");
                else tempPreview.push(Math.floor(Math.random() * sides) + 1);
            }
            root.previewRolls = tempPreview;
        }
    }

    component NumInput : Item {
        id: numBox
        property int value: 0
        property int minVal: 0
        property int maxVal: 100
        property int step: 1

        implicitWidth: 130; implicitHeight: 46

        Style.ShapeBox {
            anchors.fill: parent
            role: "input"
            color: root.bgCard
            borderColor: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
            borderWidth: root.controlBorderWidth
            slantWidth: 10
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.max(14, root.inputPad.left)
            anchors.rightMargin: Math.max(14, root.inputPad.right)
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            spacing: 6

            Rectangle {
                width: 28; Layout.fillHeight: true; radius: 4
                color: upM.containsMouse ? root.bgHover : "transparent"
                border.width: root.controlBorderWidth
                border.color: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
                Text { text: "▲"; anchors.centerIn: parent; color: root.highlightColor; font.pixelSize: 13; font.bold: true }
                MouseArea { id: upM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onPressed: { if (numBox.value < numBox.maxVal) numBox.value += numBox.step; } }
            }
            TextInput {
                id: txtInput
                Layout.fillWidth: true; Layout.fillHeight: true
                text: String(numBox.value)
                font.pixelSize: 18; font.bold: true; color: root.highlightColor
                horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
                validator: IntValidator { bottom: numBox.minVal; top: numBox.maxVal }
                inputMethodHints: Qt.ImhDigitsOnly
                onTextEdited: { var p = parseInt(text); if (!isNaN(p)) numBox.value = Math.min(numBox.maxVal, Math.max(numBox.minVal, p)); }
                Binding on text { value: String(numBox.value); when: !txtInput.activeFocus }
            }
            Rectangle {
                width: 28; Layout.fillHeight: true; radius: 4
                color: downM.containsMouse ? root.bgHover : "transparent"
                border.width: root.controlBorderWidth
                border.color: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
                Text { text: "▼"; anchors.centerIn: parent; color: root.highlightColor; font.pixelSize: 13; font.bold: true }
                MouseArea { id: downM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onPressed: { if (numBox.value > numBox.minVal) numBox.value -= numBox.step; } }
            }
        }
    }

    function executeRoll() {
        var sides = selectedSides < 2 ? 2 : selectedSides;
        if (sides === 2) {
            var headsCount = 0, tailsCount = 0, coinRolls = [];
            for (var c = 0; c < diceCount; c++) {
                if (Math.random() < 0.5) { headsCount++; coinRolls.push({ "valStr": "Heads", "kept": true }); }
                else { tailsCount++; coinRolls.push({ "valStr": "Tails", "kept": true }); }
            }
            coinRolls.sort((a, b) => a.valStr.localeCompare(b.valStr));
            lastRollType = diceCount + (diceCount === 1 ? " Coin Flip" : " Coin Flips");
            coinResult = headsCount + " 🪙 Heads / " + tailsCount + " 🪙 Tails";
            lastRolls = coinRolls; lastTotal = headsCount; lastAverage = diceCount > 0 ? (headsCount / diceCount) : 0;
            addHistory(lastRollType, headsCount, lastAverage, coinResult);
            return;
        }
        coinResult = "";
        var rawRollObjects = [];
        for (var i = 0; i < diceCount; i++) {
            var raw = Math.floor(Math.random() * sides) + 1;
            rawRollObjects.push({ "value": Math.min(sides, Math.max(1, raw + strengthVal)) + flatModVal, "kept": true });
        }
        var effectiveKeep = Math.min(diceCount, Math.max(1, keepCount));
        if (keepMode === "kh") {
            rawRollObjects.sort((a, b) => b.value - a.value);
            for (var k = 0; k < rawRollObjects.length; k++) rawRollObjects[k].kept = (k < effectiveKeep);
        } else if (keepMode === "kl") {
            rawRollObjects.sort((a, b) => a.value - b.value);
            for (var l = 0; l < rawRollObjects.length; l++) rawRollObjects[l].kept = (l < effectiveKeep);
        }
        rawRollObjects.sort((a, b) => a.value - b.value);
        var sum = 0, keptNum = 0, rollSummaryStrings = [];
        for (var n = 0; n < rawRollObjects.length; n++) {
            var item = rawRollObjects[n];
            if (item.kept) { sum += item.value; keptNum++; rollSummaryStrings.push(item.value); }
            else { rollSummaryStrings.push("(" + item.value + ")"); }
        }
        var suffix = keepMode === "kh" ? " (kh" + effectiveKeep + ")" : (keepMode === "kl" ? " (kl" + effectiveKeep + ")" : "");
        lastRollType = diceCount + "d" + sides + suffix;
        lastRolls = rawRollObjects; lastTotal = sum; lastAverage = keptNum > 0 ? (sum / keptNum) : 0;
        addHistory(lastRollType, lastTotal, lastAverage, rollSummaryStrings.join(", "));
    }

    function addHistory(type, total, avg, rollsStr) {
        historyModel.insert(0, {
            "timeStr": Qt.formatDateTime(new Date(), "hh:mm:ss"),
            "typeStr": type, "totalVal": total, "avgVal": avg > 0 ? avg.toFixed(2) : "-", "rollsStr": rollsStr
        });
        if (historyModel.count > 50) historyModel.remove(50, historyModel.count - 50);
    }

    Item {
        id: diceCard
        anchors.centerIn: parent
        width: settingsManager ? settingsManager.getWindowWidth(root.windowId, 620) : 620
        height: settingsManager ? settingsManager.getWindowHeight(root.windowId, 840) : 840

        readonly property var safePad: Utils.getSafeCardPadding(settingsManager)

        Style.ShapeBox {
            anchors.fill: parent
            role: "card"
            color: root.bgBase
            borderColor: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
            borderWidth: root.globalBorderWidth
        }

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
            anchors.leftMargin: diceCard.safePad.h
            anchors.rightMargin: diceCard.safePad.h
            anchors.topMargin: diceCard.safePad.v
            anchors.bottomMargin: diceCard.safePad.v
            spacing: 12

            Item {
                Layout.fillWidth: true
                height: 48

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    color: root.bgCard
                    borderColor: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
                    borderWidth: root.controlBorderWidth
                    slantWidth: 10
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.max(16, root.inputPad.left)
                    anchors.rightMargin: Math.max(16, root.inputPad.right)
                    Text { text: "🎲 Dice, Coin & RNG"; color: root.highlightColor; font.bold: true; font.pixelSize: 18; Layout.fillWidth: true }
                    Item {
                        width: 110; height: 32
                        Style.ShapeBox {
                            anchors.fill: parent
                            role: "input"
                            slantWidth: 6
                            color: root.showHistoryPanel ? root.accentColor : (histMouse.containsMouse ? root.bgHover : root.bgBase)
                            borderColor: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
                            borderWidth: root.controlBorderWidth
                        }
                        Text { anchors.centerIn: parent; text: root.showHistoryPanel ? "🎲 Roller" : "📜 History"; color: root.showHistoryPanel ? "#11111b" : root.highlightColor; font.bold: true; font.pixelSize: 14 }
                        MouseArea { id: histMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.showHistoryPanel = !root.showHistoryPanel }
                    }
                    Item {
                        width: 32; height: 32
                        Style.ShapeBox {
                            anchors.fill: parent
                            role: "input"
                            slantWidth: 6
                            color: closeMouse.containsMouse ? root.altAccent : "transparent"
                            borderColor: "transparent"
                            borderWidth: 0
                        }
                        Text { anchors.centerIn: parent; text: "✕"; color: closeMouse.containsMouse ? "#11111b" : root.highlightColor; font.bold: true; font.pixelSize: 16 }
                        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                visible: !root.showHistoryPanel

                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        Text { text: "Quantity"; color: root.highlightColor; font.pixelSize: 14; font.bold: true }
                        NumInput { id: qtyBox; minVal: 1; maxVal: 100; value: root.diceCount; Layout.fillWidth: true; onValueChanged: { root.diceCount = value; if (keepSpin.value > value) keepSpin.value = value; } }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        Text { text: "Strength (Capped)"; color: root.highlightColor; font.pixelSize: 14; font.bold: true }
                        NumInput { id: strBox; minVal: -100; maxVal: 100; value: root.strengthVal; Layout.fillWidth: true; onValueChanged: root.strengthVal = value }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        Text { text: "Flat Mod (+X)"; color: root.highlightColor; font.pixelSize: 14; font.bold: true }
                        NumInput { id: flatBox; minVal: -100; maxVal: 100; value: root.flatModVal; Layout.fillWidth: true; onValueChanged: root.flatModVal = value }
                    }
                }

                Item {
                    Layout.fillWidth: true; height: 50
                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        color: root.bgCard
                        borderColor: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
                        borderWidth: root.controlBorderWidth
                        slantWidth: 10
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(16, root.inputPad.left)
                        anchors.rightMargin: Math.max(16, root.inputPad.right)
                        spacing: 8
                        Text { text: "Mode:"; color: root.highlightColor; font.bold: true; font.pixelSize: 14 }
                        Repeater {
                            model: [ { "idStr": "all", "label": "Keep All" }, { "idStr": "kh", "label": "Advantage" }, { "idStr": "kl", "label": "Disadvantage" } ]
                            delegate: Item {
                                readonly property bool isSelected: root.keepMode === modelData.idStr
                                Layout.fillWidth: true; height: 36
                                Style.ShapeBox {
                                    anchors.fill: parent
                                    role: "input"
                                    slantWidth: 8
                                    color: isSelected ? root.bgHover : root.bgBase
                                    borderColor: isSelected ? root.highlightColor : (root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor)
                                    borderWidth: root.controlBorderWidth
                                }
                                Text { anchors.centerIn: parent; text: modelData.label; color: root.highlightColor; font.bold: isSelected; font.pixelSize: 13 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.keepMode = modelData.idStr }
                            }
                        }
                        NumInput { id: keepSpin; visible: root.keepMode !== "all"; minVal: 1; maxVal: Math.max(1, root.diceCount); value: root.keepCount; Layout.preferredWidth: 120; onValueChanged: root.keepCount = value }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true; columns: 4; rowSpacing: 8; columnSpacing: 8
                    Repeater {
                        model: [ { name: "🪙 Coin", sides: 2 }, { name: "d4", sides: 4 }, { name: "d6", sides: 6 }, { name: "d8", sides: 8 }, { name: "d10", sides: 10 }, { name: "d12", sides: 12 }, { name: "d20", sides: 20 }, { name: "d100", sides: 100 } ]
                        delegate: Item {
                            readonly property bool isSelected: root.selectedSides === modelData.sides
                            Layout.fillWidth: true; height: 44
                            Style.ShapeBox {
                                anchors.fill: parent
                                role: "input"
                                slantWidth: 8
                                color: root.bgCard
                                borderColor: isSelected ? root.highlightColor : (root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor)
                                borderWidth: root.controlBorderWidth
                            }
                            Text { anchors.centerIn: parent; text: modelData.name; color: isSelected ? root.highlightColor : (modelData.sides === 2 ? root.accentColor : root.highlightColor); font.bold: isSelected; font.pixelSize: 16 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedSides = modelData.sides }
                        }
                    }
                }

                Item {
                    readonly property bool isCustomActive: root.selectedSides === root.customSidesVal && root.selectedSides !== 2 && root.selectedSides !== 4 && root.selectedSides !== 6 && root.selectedSides !== 8 && root.selectedSides !== 10 && root.selectedSides !== 12 && root.selectedSides !== 20 && root.selectedSides !== 100
                    Layout.fillWidth: true; height: 52
                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 10
                        color: isCustomActive ? root.bgHover : root.bgCard
                        borderColor: isCustomActive ? root.highlightColor : (root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor)
                        borderWidth: root.controlBorderWidth
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(16, root.inputPad.left)
                        anchors.rightMargin: Math.max(16, root.inputPad.right)
                        spacing: 12
                        Text { text: "🎲 Custom Die (d" + root.customSidesVal + "):"; color: root.highlightColor; font.bold: true; font.pixelSize: 16 }
                        Item { Layout.fillWidth: true }
                        NumInput { id: customSpin; minVal: 2; maxVal: 1000; value: root.customSidesVal; Layout.preferredWidth: 130; onValueChanged: { root.customSidesVal = value; root.selectedSides = value; } }
                    }
                    MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedSides = root.customSidesVal }
                }

                Item {
                    Layout.fillWidth: true; height: 50
                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 10
                        color: rollMouse.containsMouse ? root.bgHover : root.bgCard
                        borderColor: rollMouse.containsMouse ? root.highlightColor : root.accentColor
                        borderWidth: root.controlBorderWidth
                    }
                    Text {
                        anchors.centerIn: parent
                        text: {
                            var suffixStr = root.keepMode === "kh" ? " (kh" + root.keepCount + ")" : (root.keepMode === "kl" ? " (kl" + root.keepCount + ")" : "");
                            return root.selectedSides === 2 ? ("🎲 ROLL " + root.diceCount + (root.diceCount === 1 ? " Coin" : " Coins")) : ("🎲 ROLL " + root.diceCount + "d" + root.selectedSides + suffixStr);
                        }
                        color: rollMouse.containsMouse ? root.highlightColor : root.accentColor
                        font.bold: true; font.pixelSize: 18
                    }
                    MouseArea { id: rollMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.executeRoll() }
                }

                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 10
                        color: root.bgCard
                        borderColor: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
                        borderWidth: root.controlBorderWidth
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(18, root.inputPad.left)
                        anchors.rightMargin: Math.max(18, root.inputPad.right)
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 8
                        visible: root.lastRolls.length > 0 || root.coinResult !== ""
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: root.lastRollType === "None" ? "" : root.lastRollType; color: root.highlightColor; font.pixelSize: 16; opacity: 0.8 }
                            Item { Layout.fillWidth: true }
                            Text { visible: root.coinResult !== ""; text: root.coinResult; color: root.accentColor; font.bold: true; font.pixelSize: 16 }
                            Text { visible: root.coinResult === "" && root.lastRolls.length > 0; text: "TOTAL: " + root.lastTotal; color: root.accentColor; font.bold: true; font.pixelSize: 20 }
                        }
                        RowLayout {
                            Layout.fillWidth: true; visible: root.coinResult === "" && root.lastRolls.length > 0
                            Text { text: (root.keepMode === "all" ? "Average: " : "Average (Kept): ") + root.lastAverage.toFixed(2); color: root.highlightColor; font.pixelSize: 14; opacity: 0.8 }
                        }
                        ScrollView {
                            id: outcomesScroll; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            Flow {
                                width: outcomesScroll.availableWidth > 0 ? outcomesScroll.availableWidth : 480; spacing: 8
                                Repeater {
                                    model: root.lastRolls
                                    delegate: Item {
                                        readonly property bool isKept: typeof modelData.kept !== "undefined" ? modelData.kept : true
                                        readonly property string displayVal: typeof modelData.value !== "undefined" ? String(modelData.value) : String(modelData.valStr)
                                        width: Math.max(44, valText.implicitWidth + 16); height: 38
                                        opacity: isKept ? 1.0 : 0.35
                                        Style.ShapeBox {
                                            anchors.fill: parent
                                            role: "input"
                                            slantWidth: 6
                                            color: isKept ? (displayVal === "Heads" ? root.accentColor : (displayVal === "Tails" ? root.bgHover : root.bgBase)) : root.bgCard
                                            borderColor: isKept ? root.accentColor : (root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor)
                                            borderWidth: root.controlBorderWidth
                                        }
                                        Text { id: valText; anchors.centerIn: parent; text: displayVal; color: isKept ? (displayVal === "Heads" ? "#11111b" : root.highlightColor) : root.highlightColor; font.bold: isKept; font.strikeout: !isKept; font.pixelSize: 16 }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(18, root.inputPad.left)
                        anchors.rightMargin: Math.max(18, root.inputPad.right)
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 8
                        visible: root.lastRolls.length === 0 && root.coinResult === ""
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "🎲 " + root.diceCount + (root.selectedSides === 2 ? (root.diceCount === 1 ? " Coin" : " Coins") : ("d" + root.selectedSides)) + " (Waiting to roll...)"; color: root.highlightColor; font.pixelSize: 16; opacity: 0.8 }
                            Item { Layout.fillWidth: true }
                            Text { text: "TOTAL: ?"; color: (root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor); font.bold: true; font.pixelSize: 20 }
                        }
                        ScrollView {
                            id: previewScroll; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            Flow {
                                width: previewScroll.availableWidth > 0 ? previewScroll.availableWidth : 480; spacing: 8
                                Repeater {
                                    model: root.previewRolls
                                    delegate: Item {
                                        width: 44; height: 38
                                        Style.ShapeBox {
                                            anchors.fill: parent
                                            role: "input"
                                            slantWidth: 6
                                            color: root.bgBase
                                            borderColor: root.highlightColor
                                            borderWidth: root.controlBorderWidth
                                        }
                                        Text { anchors.centerIn: parent; text: String(modelData); color: root.highlightColor; font.bold: true; font.pixelSize: 16 }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: root.showHistoryPanel

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    slantWidth: 10
                    color: root.bgCard
                    borderColor: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
                    borderWidth: root.controlBorderWidth
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "📜 Roll History (" + historyModel.count + ")"; color: root.highlightColor; font.bold: true; font.pixelSize: 16 }
                        Item { Layout.fillWidth: true }
                        Item {
                            width: 130; height: 30
                            Style.ShapeBox {
                                anchors.fill: parent
                                role: "input"
                                slantWidth: 6
                                color: clearMouse.containsMouse ? root.altAccent : root.bgBase
                                borderColor: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
                                borderWidth: root.controlBorderWidth
                            }
                            Text { anchors.centerIn: parent; text: "Clear History"; color: clearMouse.containsMouse ? "#11111b" : root.highlightColor; font.bold: true; font.pixelSize: 14 }
                            MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: historyModel.clear() }
                        }
                    }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
                        model: historyModel
                        delegate: Item {
                            width: ListView.view ? ListView.view.width : 0; height: 58
                            Style.ShapeBox {
                                anchors.fill: parent
                                role: "input"
                                slantWidth: 6
                                color: root.bgBase
                                borderColor: root.isCardActive ? root.activeBorderColor : root.inactiveBorderColor
                                borderWidth: root.controlBorderWidth
                            }
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 8; spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: model.timeStr + " • " + model.typeStr; color: root.highlightColor; font.bold: true; font.pixelSize: 14 }
                                    Item { Layout.fillWidth: true }
                                    Text { text: model.typeStr.indexOf("Coin") !== -1 ? model.rollsStr : ("Total: " + model.totalVal + " (Avg: " + model.avgVal + ")"); color: root.accentColor; font.bold: true; font.pixelSize: 14 }
                                }
                                Text { text: "Outcomes: [ " + model.rollsStr + " ]"; color: root.highlightColor; font.pixelSize: 13; opacity: 0.7; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }
                }
            }
        }
    }

    SettingsTools.PreviewInspector {
        id: previewInspector
        visible: root.isPreviewMode
        windowId: root.windowId
        settingsManager: root.settingsManager
        theme: root.theme
        defaultW: 620; defaultH: 840
        hasField: false; hasIcon: false
        defaultPolicy: "lazy"
        onDoneRequested: {
            if (settingsManager) settingsManager.previewWindow = "";
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible && !root.isPreviewMode
        onActivated: root.close()
    }
}
