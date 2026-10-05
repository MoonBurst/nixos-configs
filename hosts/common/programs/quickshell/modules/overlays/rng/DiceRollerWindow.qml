import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../common" as Common
import "../../common/Utils.js" as Utils
import "../../style" as Style

Common.OverlayWindow {
    id: diceRoot

    windowId: "rng"
    ipcTarget: ""  // OverlayHost owns the "rng" IPC target
    defaultW: 620
    defaultH: 840
    defaultPolicy: "lazy"

    // ---------- RNG state ----------
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
    readonly property int previewCount: Math.min(30, diceCount)
    property int lastTotal: 0
    property real lastAverage: 0.0
    property string coinResult: ""
    property bool showHistoryPanel: false

    // ---------- Color shortcuts ----------
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

    onDiceCountChanged: diceRoot.lastRolls = []
    onSelectedSidesChanged: diceRoot.lastRolls = []

    ListModel { id: historyModel }

    Timer {
        id: marioPartyTimer
        interval: 60; repeat: true
        running: diceRoot.visible && diceRoot.lastRolls.length === 0 && !diceRoot.showHistoryPanel
        onTriggered: {
            var tempPreview = [];
            var count = Math.min(30, diceRoot.diceCount);
            var sides = diceRoot.selectedSides < 2 ? 2 : diceRoot.selectedSides;
            for (var i = 0; i < count; i++) {
                if (sides === 2) tempPreview.push(Math.random() < 0.5 ? "H" : "T");
                else tempPreview.push(Math.floor(Math.random() * sides) + 1);
            }
            diceRoot.previewRolls = tempPreview;
        }
    }

    // ---------- Focused-screen detection ----------
    property string detectedFocusedScreenName: ""

    screen: {
        var target = settingsManager ? settingsManager.rngScreenTarget : "focused";
        if (target === "focused" || target === "") {
            if (diceRoot.detectedFocusedScreenName !== "") {
                var foundFocused = Quickshell.screens.find(s => s.name === diceRoot.detectedFocusedScreenName);
                if (foundFocused) return foundFocused;
            }
            return (safeShell && safeShell.primaryScreen) ? safeShell.primaryScreen : Quickshell.screens[0];
        }
        var found = Quickshell.screens.find(s => s.name === target);
        if (found) return found;
        return (safeShell && safeShell.primaryScreen) ? safeShell.primaryScreen : Quickshell.screens[0];
    }

    Process {
        id: focusDetector
        command: [
            "sh", "-c",
            "swaymsg -t get_outputs 2>/dev/null | awk '/name:/ {name=$2} /focused.*true/ {print name; exit}' | tr -d '\", \\t' || hyprctl monitors 2>/dev/null | awk '/^Monitor/ {m=$2} /focused: (yes|true)/ {print m; exit}' || echo ''"
        ]
        stdout: SplitParser {
            onRead: data => {
                var name = data.trim();
                if (name.length > 0) diceRoot.detectedFocusedScreenName = name;
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

    // ---------- Custom open/toggle API ----------
    function openWithTarget() {
        var target = settingsManager ? settingsManager.rngScreenTarget : "focused";
        if (target === "focused" || target === "") {
            focusDetector.running = false;
            focusDetector.running = true;
        }
        open();
    }

    function toggleWithTarget() {
        if (isOpenState) close();
        else openWithTarget();
    }

    // ---------- Local component ----------
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
            color: diceRoot.bgCard
            borderColor: diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor
            borderWidth: diceRoot.controlBorderWidth
            slantWidth: 10
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.max(14, diceRoot.inputPad.left)
            anchors.rightMargin: Math.max(14, diceRoot.inputPad.right)
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            spacing: 6

            Rectangle {
                width: 28; Layout.fillHeight: true; radius: 4
                color: upM.containsMouse ? diceRoot.bgHover : "transparent"
                border.width: diceRoot.controlBorderWidth
                border.color: diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor
                Text { text: "▲"; anchors.centerIn: parent; color: diceRoot.highlightColor; font.pixelSize: 13; font.bold: true }
                MouseArea { id: upM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onPressed: { if (numBox.value < numBox.maxVal) numBox.value += numBox.step; } }
            }
            TextInput {
                id: txtInput
                Layout.fillWidth: true; Layout.fillHeight: true
                text: String(numBox.value)
                font.pixelSize: 18; font.bold: true; color: diceRoot.highlightColor
                horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
                validator: IntValidator { bottom: numBox.minVal; top: numBox.maxVal }
                inputMethodHints: Qt.ImhDigitsOnly
                onTextEdited: { var p = parseInt(text); if (!isNaN(p)) numBox.value = Math.min(numBox.maxVal, Math.max(numBox.minVal, p)); }
                Binding on text { value: String(numBox.value); when: !txtInput.activeFocus }
            }
            Rectangle {
                width: 28; Layout.fillHeight: true; radius: 4
                color: downM.containsMouse ? diceRoot.bgHover : "transparent"
                border.width: diceRoot.controlBorderWidth
                border.color: diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor
                Text { text: "▼"; anchors.centerIn: parent; color: diceRoot.highlightColor; font.pixelSize: 13; font.bold: true }
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

    // ---------- View ----------
    viewComponent: Component {
        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            // Title bar
            Item {
                Layout.fillWidth: true
                height: 48

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    color: diceRoot.bgCard
                    borderColor: diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor
                    borderWidth: diceRoot.controlBorderWidth
                    slantWidth: 10
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.max(16, diceRoot.inputPad.left)
                    anchors.rightMargin: Math.max(16, diceRoot.inputPad.right)
                    Text { text: "🎲 Dice, Coin & RNG"; color: diceRoot.highlightColor; font.bold: true; font.pixelSize: 18; Layout.fillWidth: true }
                    Item {
                        width: 110; height: 32
                        Style.ShapeBox {
                            anchors.fill: parent
                            role: "input"
                            slantWidth: 6
                            color: diceRoot.showHistoryPanel ? diceRoot.accentColor : (histMouse.containsMouse ? diceRoot.bgHover : diceRoot.bgBase)
                            borderColor: diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor
                            borderWidth: diceRoot.controlBorderWidth
                        }
                        Text { anchors.centerIn: parent; text: diceRoot.showHistoryPanel ? "🎲 Roller" : "📜 History"; color: diceRoot.showHistoryPanel ? "#11111b" : diceRoot.highlightColor; font.bold: true; font.pixelSize: 14 }
                        MouseArea { id: histMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: diceRoot.showHistoryPanel = !diceRoot.showHistoryPanel }
                    }
                    Item {
                        width: 32; height: 32
                        Style.ShapeBox {
                            anchors.fill: parent
                            role: "input"
                            slantWidth: 6
                            color: closeMouse.containsMouse ? diceRoot.altAccent : "transparent"
                            borderColor: "transparent"
                            borderWidth: 0
                        }
                        Text { anchors.centerIn: parent; text: "✕"; color: closeMouse.containsMouse ? "#11111b" : diceRoot.highlightColor; font.bold: true; font.pixelSize: 16 }
                        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: diceRoot.close() }
                    }
                }
            }

            // Roller panel
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                visible: !diceRoot.showHistoryPanel

                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        Text { text: "Quantity"; color: diceRoot.highlightColor; font.pixelSize: 14; font.bold: true }
                        NumInput { id: qtyBox; minVal: 1; maxVal: 100; value: diceRoot.diceCount; Layout.fillWidth: true; onValueChanged: { diceRoot.diceCount = value; if (keepSpin.value > value) keepSpin.value = value; } }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        Text { text: "Strength (Capped)"; color: diceRoot.highlightColor; font.pixelSize: 14; font.bold: true }
                        NumInput { id: strBox; minVal: -100; maxVal: 100; value: diceRoot.strengthVal; Layout.fillWidth: true; onValueChanged: diceRoot.strengthVal = value }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        Text { text: "Flat Mod (+X)"; color: diceRoot.highlightColor; font.pixelSize: 14; font.bold: true }
                        NumInput { id: flatBox; minVal: -100; maxVal: 100; value: diceRoot.flatModVal; Layout.fillWidth: true; onValueChanged: diceRoot.flatModVal = value }
                    }
                }

                Item {
                    Layout.fillWidth: true; height: 50
                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        color: diceRoot.bgCard
                        borderColor: diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor
                        borderWidth: diceRoot.controlBorderWidth
                        slantWidth: 10
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(16, diceRoot.inputPad.left)
                        anchors.rightMargin: Math.max(16, diceRoot.inputPad.right)
                        spacing: 8
                        Text { text: "Mode:"; color: diceRoot.highlightColor; font.bold: true; font.pixelSize: 14 }
                        Repeater {
                            model: [ { "idStr": "all", "label": "Keep All" }, { "idStr": "kh", "label": "Advantage" }, { "idStr": "kl", "label": "Disadvantage" } ]
                            delegate: Item {
                                readonly property bool isSelected: diceRoot.keepMode === modelData.idStr
                                Layout.fillWidth: true; height: 36
                                Style.ShapeBox {
                                    anchors.fill: parent
                                    role: "input"
                                    slantWidth: 8
                                    color: isSelected ? diceRoot.bgHover : diceRoot.bgBase
                                    borderColor: isSelected ? diceRoot.highlightColor : (diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor)
                                    borderWidth: diceRoot.controlBorderWidth
                                }
                                Text { anchors.centerIn: parent; text: modelData.label; color: diceRoot.highlightColor; font.bold: isSelected; font.pixelSize: 13 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: diceRoot.keepMode = modelData.idStr }
                            }
                        }
                        NumInput { id: keepSpin; visible: diceRoot.keepMode !== "all"; minVal: 1; maxVal: Math.max(1, diceRoot.diceCount); value: diceRoot.keepCount; Layout.preferredWidth: 120; onValueChanged: diceRoot.keepCount = value }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true; columns: 4; rowSpacing: 8; columnSpacing: 8
                    Repeater {
                        model: [ { name: "🪙 Coin", sides: 2 }, { name: "d4", sides: 4 }, { name: "d6", sides: 6 }, { name: "d8", sides: 8 }, { name: "d10", sides: 10 }, { name: "d12", sides: 12 }, { name: "d20", sides: 20 }, { name: "d100", sides: 100 } ]
                        delegate: Item {
                            readonly property bool isSelected: diceRoot.selectedSides === modelData.sides
                            Layout.fillWidth: true; height: 44
                            Style.ShapeBox {
                                anchors.fill: parent
                                role: "input"
                                slantWidth: 8
                                color: diceRoot.bgCard
                                borderColor: isSelected ? diceRoot.highlightColor : (diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor)
                                borderWidth: diceRoot.controlBorderWidth
                            }
                            Text { anchors.centerIn: parent; text: modelData.name; color: isSelected ? diceRoot.highlightColor : (modelData.sides === 2 ? diceRoot.accentColor : diceRoot.highlightColor); font.bold: isSelected; font.pixelSize: 16 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: diceRoot.selectedSides = modelData.sides }
                        }
                    }
                }

                Item {
                    id: customDieRow
                    readonly property bool isCustomActive: diceRoot.selectedSides === diceRoot.customSidesVal && diceRoot.selectedSides !== 2 && diceRoot.selectedSides !== 4 && diceRoot.selectedSides !== 6 && diceRoot.selectedSides !== 8 && diceRoot.selectedSides !== 10 && diceRoot.selectedSides !== 12 && diceRoot.selectedSides !== 20 && diceRoot.selectedSides !== 100
                    Layout.fillWidth: true; height: 52
                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 10
                        color: customDieRow.isCustomActive ? diceRoot.bgHover : diceRoot.bgCard
                        borderColor: customDieRow.isCustomActive ? diceRoot.highlightColor : (diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor)
                        borderWidth: diceRoot.controlBorderWidth
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(16, diceRoot.inputPad.left)
                        anchors.rightMargin: Math.max(16, diceRoot.inputPad.right)
                        spacing: 12
                        Text { text: "🎲 Custom Die (d" + diceRoot.customSidesVal + "):"; color: diceRoot.highlightColor; font.bold: true; font.pixelSize: 16 }
                        Item { Layout.fillWidth: true }
                        NumInput { id: customSpin; minVal: 2; maxVal: 1000; value: diceRoot.customSidesVal; Layout.preferredWidth: 130; onValueChanged: { diceRoot.customSidesVal = value; diceRoot.selectedSides = value; } }
                    }
                    MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: diceRoot.selectedSides = diceRoot.customSidesVal }
                }

                Item {
                    Layout.fillWidth: true; height: 50
                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 10
                        color: rollMouse.containsMouse ? diceRoot.bgHover : diceRoot.bgCard
                        borderColor: rollMouse.containsMouse ? diceRoot.highlightColor : diceRoot.accentColor
                        borderWidth: diceRoot.controlBorderWidth
                    }
                    Text {
                        anchors.centerIn: parent
                        text: {
                            var suffixStr = diceRoot.keepMode === "kh" ? " (kh" + diceRoot.keepCount + ")" : (diceRoot.keepMode === "kl" ? " (kl" + diceRoot.keepCount + ")" : "");
                            return diceRoot.selectedSides === 2 ? ("🎲 ROLL " + diceRoot.diceCount + (diceRoot.diceCount === 1 ? " Coin" : " Coins")) : ("🎲 ROLL " + diceRoot.diceCount + "d" + diceRoot.selectedSides + suffixStr);
                        }
                        color: rollMouse.containsMouse ? diceRoot.highlightColor : diceRoot.accentColor
                        font.bold: true; font.pixelSize: 18
                    }
                    MouseArea { id: rollMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: diceRoot.executeRoll() }
                }

                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        slantWidth: 10
                        color: diceRoot.bgCard
                        borderColor: diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor
                        borderWidth: diceRoot.controlBorderWidth
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(18, diceRoot.inputPad.left)
                        anchors.rightMargin: Math.max(18, diceRoot.inputPad.right)
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 8
                        visible: diceRoot.lastRolls.length > 0 || diceRoot.coinResult !== ""
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: diceRoot.lastRollType === "None" ? "" : diceRoot.lastRollType; color: diceRoot.highlightColor; font.pixelSize: 16; opacity: 0.8 }
                            Item { Layout.fillWidth: true }
                            Text { visible: diceRoot.coinResult !== ""; text: diceRoot.coinResult; color: diceRoot.accentColor; font.bold: true; font.pixelSize: 16 }
                            Text { visible: diceRoot.coinResult === "" && diceRoot.lastRolls.length > 0; text: "TOTAL: " + diceRoot.lastTotal; color: diceRoot.accentColor; font.bold: true; font.pixelSize: 20 }
                        }
                        RowLayout {
                            Layout.fillWidth: true; visible: diceRoot.coinResult === "" && diceRoot.lastRolls.length > 0
                            Text { text: (diceRoot.keepMode === "all" ? "Average: " : "Average (Kept): ") + diceRoot.lastAverage.toFixed(2); color: diceRoot.highlightColor; font.pixelSize: 14; opacity: 0.8 }
                        }
                        ScrollView {
                            id: outcomesScroll; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            Flow {
                                width: outcomesScroll.availableWidth > 0 ? outcomesScroll.availableWidth : 480; spacing: 8
                                Repeater {
                                    model: diceRoot.lastRolls
                                    delegate: Item {
                                        readonly property bool isKept: typeof modelData.kept !== "undefined" ? modelData.kept : true
                                        readonly property string displayVal: typeof modelData.value !== "undefined" ? String(modelData.value) : String(modelData.valStr)
                                        width: Math.max(44, valText.implicitWidth + 16); height: 38
                                        opacity: isKept ? 1.0 : 0.35
                                        Style.ShapeBox {
                                            anchors.fill: parent
                                            role: "input"
                                            slantWidth: 6
                                            color: isKept ? (displayVal === "Heads" ? diceRoot.accentColor : (displayVal === "Tails" ? diceRoot.bgHover : diceRoot.bgBase)) : diceRoot.bgCard
                                            borderColor: isKept ? diceRoot.accentColor : (diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor)
                                            borderWidth: diceRoot.controlBorderWidth
                                        }
                                        Text { id: valText; anchors.centerIn: parent; text: displayVal; color: isKept ? (displayVal === "Heads" ? "#11111b" : diceRoot.highlightColor) : diceRoot.highlightColor; font.bold: isKept; font.strikeout: !isKept; font.pixelSize: 16 }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(18, diceRoot.inputPad.left)
                        anchors.rightMargin: Math.max(18, diceRoot.inputPad.right)
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 8
                        visible: diceRoot.lastRolls.length === 0 && diceRoot.coinResult === ""
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "🎲 " + diceRoot.diceCount + (diceRoot.selectedSides === 2 ? (diceRoot.diceCount === 1 ? " Coin" : " Coins") : ("d" + diceRoot.selectedSides)) + " (Waiting to roll...)"; color: diceRoot.highlightColor; font.pixelSize: 16; opacity: 0.8 }
                            Item { Layout.fillWidth: true }
                            Text { text: "TOTAL: ?"; color: (diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor); font.bold: true; font.pixelSize: 20 }
                        }
                        ScrollView {
                            id: previewScroll; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            Flow {
                                width: previewScroll.availableWidth > 0 ? previewScroll.availableWidth : 480; spacing: 8
                                Repeater {
                                    model: diceRoot.previewCount
                                    delegate: Item {
                                        readonly property var currentVal: (index < diceRoot.previewRolls.length) ? diceRoot.previewRolls[index] : ""
                                        width: 44; height: 38
                                        Style.ShapeBox {
                                            anchors.fill: parent
                                            role: "input"
                                            slantWidth: 6
                                            color: diceRoot.bgBase
                                            borderColor: diceRoot.highlightColor
                                            borderWidth: diceRoot.controlBorderWidth
                                        }
                                        Text { anchors.centerIn: parent; text: String(currentVal); color: diceRoot.highlightColor; font.bold: true; font.pixelSize: 16 }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // History panel
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: diceRoot.showHistoryPanel

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    slantWidth: 10
                    color: diceRoot.bgCard
                    borderColor: diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor
                    borderWidth: diceRoot.controlBorderWidth
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "📜 Roll History (" + historyModel.count + ")"; color: diceRoot.highlightColor; font.bold: true; font.pixelSize: 16 }
                        Item { Layout.fillWidth: true }
                        Item {
                            width: 130; height: 30
                            Style.ShapeBox {
                                anchors.fill: parent
                                role: "input"
                                slantWidth: 6
                                color: clearMouse.containsMouse ? diceRoot.altAccent : diceRoot.bgBase
                                borderColor: diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor
                                borderWidth: diceRoot.controlBorderWidth
                            }
                            Text { anchors.centerIn: parent; text: "Clear History"; color: clearMouse.containsMouse ? "#11111b" : diceRoot.highlightColor; font.bold: true; font.pixelSize: 14 }
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
                                color: diceRoot.bgBase
                                borderColor: diceRoot.isCardActive ? diceRoot.activeBorderColor : diceRoot.inactiveBorderColor
                                borderWidth: diceRoot.controlBorderWidth
                            }
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 8; spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: model.timeStr + " • " + model.typeStr; color: diceRoot.highlightColor; font.bold: true; font.pixelSize: 14 }
                                    Item { Layout.fillWidth: true }
                                    Text { text: model.typeStr.indexOf("Coin") !== -1 ? model.rollsStr : ("Total: " + model.totalVal + " (Avg: " + model.avgVal + ")"); color: diceRoot.accentColor; font.bold: true; font.pixelSize: 14 }
                                }
                                Text { text: "Outcomes: [ " + model.rollsStr + " ]"; color: diceRoot.highlightColor; font.pixelSize: 13; opacity: 0.7; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }
                }
            }
        }
    }
}
