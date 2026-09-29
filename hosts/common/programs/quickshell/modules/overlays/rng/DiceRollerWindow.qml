import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root

    property var shell
    property string detectedFocusedScreenName: ""

    screen: {
        var target = (shell && shell.settingsManager && shell.settingsManager.rngScreenTarget)
            ? shell.settingsManager.rngScreenTarget : "focused";
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

    onScreenChanged: {
        if (root.width > 0 && root.height > 0) {
            diceCard.x = Math.max(20, Math.min(root.width - diceCard.width - 20, diceCard.x));
            diceCard.y = Math.max(20, Math.min(root.height - diceCard.height - 20, diceCard.y));
        }
    }

    // Pure awk/shell monitor focus detector - zero jq dependency
    Process {
        id: focusDetector
        command: [
            "sh", "-c",
            "hyprctl monitors 2>/dev/null | awk '/^Monitor/ {m=$2} /focused: (yes|true)/ {print m; exit}' || swaymsg -t get_outputs 2>/dev/null | awk '/name:/ {name=$2} /focused.*true/ {print name; exit}' | tr -d '\", \\t' || echo ''"
        ]
        stdout: SplitParser {
            onRead: data => {
                var name = data.trim();
                if (name.length > 0) {
                    root.detectedFocusedScreenName = name;
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var target = (shell && shell.settingsManager && shell.settingsManager.rngScreenTarget)
                ? shell.settingsManager.rngScreenTarget : "focused";
            if (target === "focused" || target === "") {
                focusDetector.running = true;
            }
        }
    }

    function openWithTarget() {
        var target = (shell && shell.settingsManager && shell.settingsManager.rngScreenTarget)
            ? shell.settingsManager.rngScreenTarget : "focused";
        if (target === "focused" || target === "") {
            focusDetector.running = false;
            focusDetector.running = true;
        }
        root.visible = true;
    }

    function toggleWithTarget() {
        if (root.visible) {
            root.visible = false;
        } else {
            openWithTarget();
        }
    }

    visible: false

    // Wayland Layer Shell Overlay setup
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: diceCard
    }

    color: "transparent"

    // Theme color accessors with safe fallbacks
    readonly property color bgBase: shell && shell.theme ? shell.theme.base01 : "#1e1e2e"
    readonly property color bgCard: shell && shell.theme ? shell.theme.base00 : "#181825"
    readonly property color bgHover: shell && shell.theme ? shell.theme.base02 : "#313244"
    readonly property color borderColor: shell && shell.theme ? shell.theme.base03 : "#45475a"
    readonly property color textColor: shell && shell.theme ? shell.theme.base05 : "#cdd6f4"
    readonly property color accentColor: shell && shell.theme ? shell.theme.base05 : "#a6e3a1"
    readonly property color altAccent: shell && shell.theme ? shell.theme.base05 : "#f38ba8"
    readonly property color highlightColor: shell && shell.theme ? shell.theme.base05 : "#f9e2af"

    // --- ROLL STATE & CALCULATIONS ---
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

    ListModel {
        id: historyModel
    }

    Timer {
        id: marioPartyTimer
        interval: 60
        repeat: true
        running: root.visible && root.lastRolls.length === 0 && !root.showHistoryPanel

        onTriggered: {
            var tempPreview = [];
            var count = Math.min(30, root.diceCount);
            var sides = root.selectedSides < 2 ? 2 : root.selectedSides;

            for (var i = 0; i < count; i++) {
                if (sides === 2) {
                    tempPreview.push(Math.random() < 0.5 ? "H" : "T");
                } else {
                    var randVal = Math.floor(Math.random() * sides) + 1;
                    tempPreview.push(randVal);
                }
            }
            root.previewRolls = tempPreview;
        }
    }

    component NumInput : Rectangle {
        id: numBox
        property int value: 0
        property int minVal: 0
        property int maxVal: 100
        property int step: 1

        implicitWidth: 130
        implicitHeight: 46
        color: root.bgCard
        radius: 8
        border.width: 1
        border.color: root.borderColor

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            Rectangle {
                width: 32
                Layout.fillHeight: true
                radius: 6
                color: upM.containsMouse ? root.bgHover : root.bgBase
                border.width: 1
                border.color: root.borderColor

                Text {
                    text: "▲"
                    anchors.centerIn: parent
                    color: root.highlightColor
                    font.pixelSize: 14
                    font.bold: true
                }

                MouseArea {
                    id: upM
                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: {
                        if (numBox.value < numBox.maxVal) {
                            numBox.value += numBox.step;
                        }
                    }
                }
            }

            TextInput {
                id: txtInput
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: String(numBox.value)
                font.pixelSize: 20
                font.bold: true
                color: root.highlightColor
                horizontalAlignment: Qt.AlignHCenter
                verticalAlignment: Qt.AlignVCenter
                validator: IntValidator { bottom: numBox.minVal; top: numBox.maxVal }
                inputMethodHints: Qt.ImhDigitsOnly

                onTextEdited: {
                    var parsed = parseInt(text);
                    if (!isNaN(parsed)) {
                        numBox.value = Math.min(numBox.maxVal, Math.max(numBox.minVal, parsed));
                    }
                }

                Binding on text {
                    value: String(numBox.value)
                    when: !txtInput.activeFocus
                }
            }

            Rectangle {
                width: 32
                Layout.fillHeight: true
                radius: 6
                color: downM.containsMouse ? root.bgHover : root.bgBase
                border.width: 1
                border.color: root.borderColor

                Text {
                    text: "▼"
                    anchors.centerIn: parent
                    color: root.highlightColor
                    font.pixelSize: 14
                    font.bold: true
                }

                MouseArea {
                    id: downM
                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: {
                        if (numBox.value > numBox.minVal) {
                            numBox.value -= numBox.step;
                        }
                    }
                }
            }
        }
    }

    function executeRoll() {
        var sides = selectedSides;
        if (sides < 2) sides = 2;

        if (sides === 2) {
            var headsCount = 0;
            var tailsCount = 0;
            var coinRolls = [];

            for (var c = 0; c < diceCount; c++) {
                var isHeads = Math.random() < 0.5;
                if (isHeads) {
                    headsCount++;
                    coinRolls.push({ "valStr": "Heads", "kept": true });
                } else {
                    tailsCount++;
                    coinRolls.push({ "valStr": "Tails", "kept": true });
                }
            }

            coinRolls.sort(function(a, b) { return a.valStr.localeCompare(b.valStr); });

            lastRollType = diceCount + (diceCount === 1 ? " Coin Flip" : " Coin Flips");
            coinResult = headsCount + " 🪙 Heads / " + tailsCount + " 🪙 Tails";
            lastRolls = coinRolls;
            lastTotal = headsCount;
            lastAverage = diceCount > 0 ? (headsCount / diceCount) : 0;

            addHistory(lastRollType, headsCount, lastAverage, coinResult);
            return;
        }

        coinResult = "";

        var rawRollObjects = [];
        for (var i = 0; i < diceCount; i++) {
            var raw = Math.floor(Math.random() * sides) + 1;
            var strengthApplied = Math.min(sides, Math.max(1, raw + strengthVal));
            var finalVal = strengthApplied + flatModVal;
            rawRollObjects.push({ "value": finalVal, "kept": true });
        }

        var effectiveKeep = Math.min(diceCount, Math.max(1, keepCount));

        if (keepMode === "kh") {
            rawRollObjects.sort(function(a, b) { return b.value - a.value; });
            for (var k = 0; k < rawRollObjects.length; k++) {
                rawRollObjects[k].kept = (k < effectiveKeep);
            }
        } else if (keepMode === "kl") {
            rawRollObjects.sort(function(a, b) { return a.value - b.value; });
            for (var l = 0; l < rawRollObjects.length; l++) {
                rawRollObjects[l].kept = (l < effectiveKeep);
            }
        } else {
            for (var m = 0; m < rawRollObjects.length; m++) {
                rawRollObjects[m].kept = true;
            }
        }

        rawRollObjects.sort(function(a, b) { return a.value - b.value; });

        var sum = 0;
        var keptNum = 0;
        var rollSummaryStrings = [];

        for (var n = 0; n < rawRollObjects.length; n++) {
            var item = rawRollObjects[n];
            if (item.kept) {
                sum += item.value;
                keptNum++;
                rollSummaryStrings.push(item.value);
            } else {
                rollSummaryStrings.push("(" + item.value + ")");
            }
        }

        var suffix = "";
        if (keepMode === "kh") suffix = " (kh" + effectiveKeep + ")";
        else if (keepMode === "kl") suffix = " (kl" + effectiveKeep + ")";

        lastRollType = diceCount + "d" + sides + suffix;
        lastRolls = rawRollObjects;
        lastTotal = sum;
        lastAverage = keptNum > 0 ? (sum / keptNum) : 0;

        addHistory(lastRollType, lastTotal, lastAverage, rollSummaryStrings.join(", "));
    }

    function addHistory(type, total, avg, rollsStr) {
        var timeStr = Qt.formatDateTime(new Date(), "hh:mm:ss");
        historyModel.insert(0, {
            "timeStr": timeStr,
            "typeStr": type,
            "totalVal": total,
            "avgVal": avg > 0 ? avg.toFixed(2) : "-",
            "rollsStr": rollsStr
        });

        if (historyModel.count > 50) {
            historyModel.remove(50, historyModel.count - 50);
        }
    }

    Rectangle {
        id: diceCard
        x: 100
        y: 100
        width: 580
        height: 840
        radius: 16
        color: root.bgBase
        border.width: 3
        border.color: root.borderColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                height: 48
                color: root.bgCard
                radius: 10
                border.width: 1
                border.color: root.borderColor

                MouseArea {
                    id: headerDrag
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    drag.target: diceCard
                    drag.minimumX: 0
                    drag.minimumY: 0
                    drag.maximumX: root.width - diceCard.width
                    drag.maximumY: root.height - diceCard.height
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8

                    Text {
                        text: "🎲 Dice, Coin & RNG"
                        color: root.highlightColor
                        font.bold: true
                        font.pixelSize: 20
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 110
                        height: 34
                        radius: 8
                        color: root.showHistoryPanel ? root.accentColor : (histMouse.containsMouse ? root.bgHover : root.bgBase)
                        border.width: 1
                        border.color: root.borderColor

                        Text {
                            anchors.centerIn: parent
                            text: root.showHistoryPanel ? "🎲 Roller" : "📜 History"
                            color: root.showHistoryPanel ? "#11111b" : root.highlightColor
                            font.bold: true
                            font.pixelSize: 20
                        }

                        MouseArea {
                            id: histMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.showHistoryPanel = !root.showHistoryPanel
                        }
                    }

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 8
                        color: closeMouse.containsMouse ? root.altAccent : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeMouse.containsMouse ? "#11111b" : root.highlightColor
                            font.bold: true
                            font.pixelSize: 20
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.visible = false
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                visible: !root.showHistoryPanel

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Quantity"; color: root.highlightColor; font.pixelSize: 20; font.bold: true }
                        NumInput {
                            id: qtyBox
                            minVal: 1; maxVal: 100; value: root.diceCount
                            Layout.fillWidth: true
                            onValueChanged: {
                                root.diceCount = value;
                                if (keepSpin.value > value) keepSpin.value = value;
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Strength (Capped)"; color: root.highlightColor; font.pixelSize: 20; font.bold: true }
                        NumInput {
                            id: strBox
                            minVal: -100; maxVal: 100; value: root.strengthVal
                            Layout.fillWidth: true
                            onValueChanged: root.strengthVal = value
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Flat Mod (+X)"; color: root.highlightColor; font.pixelSize: 20; font.bold: true }
                        NumInput {
                            id: flatBox
                            minVal: -100; maxVal: 100; value: root.flatModVal
                            Layout.fillWidth: true
                            onValueChanged: root.flatModVal = value
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 52
                    radius: 10
                    color: root.bgCard
                    border.width: 1
                    border.color: root.borderColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Text {
                            text: "Mode:"
                            color: root.highlightColor
                            font.bold: true
                            font.pixelSize: 18
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Repeater {
                            model: [
                                { "idStr": "all", "label": "Keep All" },
                                { "idStr": "kh", "label": "Advantage" },
                                { "idStr": "kl", "label": "Disadvantage" }
                            ]

                            delegate: Rectangle {
                                readonly property bool isSelected: root.keepMode === modelData.idStr
                                Layout.fillWidth: true
                                height: 40
                                radius: 8
                                color: isSelected ? root.bgHover : root.bgBase
                                border.width: isSelected ? 2 : 1
                                border.color: isSelected ? root.highlightColor : root.borderColor

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: root.highlightColor
                                    font.bold: isSelected
                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.keepMode = modelData.idStr
                                }
                            }
                        }

                        NumInput {
                            id: keepSpin
                            visible: root.keepMode !== "all"
                            minVal: 1; maxVal: Math.max(1, root.diceCount); value: root.keepCount
                            Layout.preferredWidth: 130
                            onValueChanged: root.keepCount = value
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    rowSpacing: 10
                    columnSpacing: 10

                    Repeater {
                        model: [
                            { name: "🪙 Coin", sides: 2 },
                            { name: "d4", sides: 4 },
                            { name: "d6", sides: 6 },
                            { name: "d8", sides: 8 },
                            { name: "d10", sides: 10 },
                            { name: "d12", sides: 12 },
                            { name: "d20", sides: 20 },
                            { name: "d100", sides: 100 }
                        ]

                        delegate: Rectangle {
                            readonly property bool isSelected: root.selectedSides === modelData.sides

                            Layout.fillWidth: true
                            height: 48
                            radius: 10

                            color: root.bgCard
                            border.width: isSelected ? 3 : 1
                            border.color: isSelected ? root.highlightColor : root.borderColor

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: isSelected ? root.highlightColor : (modelData.sides === 2 ? root.accentColor : root.highlightColor)
                                font.bold: isSelected
                                font.pixelSize: 20
                            }

                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.selectedSides = modelData.sides
                            }
                        }
                    }
                }

                Rectangle {
                    readonly property bool isCustomActive: root.selectedSides === root.customSidesVal && root.selectedSides !== 2 && root.selectedSides !== 4 && root.selectedSides !== 6 && root.selectedSides !== 8 && root.selectedSides !== 10 && root.selectedSides !== 12 && root.selectedSides !== 20 && root.selectedSides !== 100

                    Layout.fillWidth: true
                    height: 56
                    radius: 10
                    color: isCustomActive ? root.bgHover : root.bgCard
                    border.width: isCustomActive ? 3 : 1
                    border.color: isCustomActive ? root.highlightColor : root.borderColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Text {
                            text: "🎲 Custom Die (d" + root.customSidesVal + "):"
                            color: root.highlightColor
                            font.bold: true
                            font.pixelSize: 20
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        NumInput {
                            id: customSpin
                            minVal: 2; maxVal: 1000; value: root.customSidesVal
                            Layout.preferredWidth: 140
                            Layout.alignment: Qt.AlignVCenter
                            onValueChanged: {
                                root.customSidesVal = value;
                                root.selectedSides = value;
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: root.selectedSides = root.customSidesVal
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 54
                    radius: 10

                    color: rollMouse.containsMouse ? root.bgHover : root.bgCard
                    border.width: rollMouse.containsMouse ? 3 : 2
                    border.color: rollMouse.containsMouse ? root.highlightColor : root.accentColor

                    Text {
                        anchors.centerIn: parent
                        text: {
                            var suffixStr = "";
                            if (root.keepMode === "kh") suffixStr = " (kh" + root.keepCount + ")";
                            else if (root.keepMode === "kl") suffixStr = " (kl" + root.keepCount + ")";

                            if (root.selectedSides === 2) {
                                return "🎲 ROLL " + root.diceCount + (root.diceCount === 1 ? " Coin" : " Coins");
                            } else {
                                return "🎲 ROLL " + root.diceCount + "d" + root.selectedSides + suffixStr;
                            }
                        }
                        color: rollMouse.containsMouse ? root.highlightColor : root.accentColor
                        font.bold: true
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: rollMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.executeRoll()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: root.bgCard
                    border.width: 1
                    border.color: root.borderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        visible: root.lastRolls.length > 0 || root.coinResult !== ""

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root.lastRollType === "None" ? "" : root.lastRollType
                                color: root.highlightColor
                                font.pixelSize: 20
                                opacity: 0.8
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                visible: root.coinResult !== ""
                                text: root.coinResult
                                color: root.accentColor
                                font.bold: true
                                font.pixelSize: 20
                            }

                            Text {
                                visible: root.coinResult === "" && root.lastRolls.length > 0
                                text: "TOTAL: " + root.lastTotal
                                color: root.accentColor
                                font.bold: true
                                font.pixelSize: 24
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.coinResult === "" && root.lastRolls.length > 0

                            Text {
                                text: (root.keepMode === "all" ? "Average: " : "Average (Kept): ") + root.lastAverage.toFixed(2)
                                color: root.highlightColor
                                font.pixelSize: 20
                                opacity: 0.8
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: root.borderColor
                            visible: root.lastRolls.length > 0
                        }

                        Text {
                            text: root.keepMode === "all" ? "Individual Outcomes:" : "Individual Outcomes (Grayed = Dropped):"
                            color: root.highlightColor
                            font.pixelSize: 20
                            font.bold: true
                            visible: root.lastRolls.length > 0
                        }

                        ScrollView {
                            id: outcomesScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            visible: root.lastRolls.length > 0

                            Flow {
                                width: outcomesScroll.availableWidth > 0 ? outcomesScroll.availableWidth : 500
                                spacing: 8

                                Repeater {
                                    model: root.lastRolls

                                    delegate: Rectangle {
                                        readonly property var entry: modelData
                                        readonly property bool isKept: typeof entry.kept !== "undefined" ? entry.kept : true
                                        readonly property string displayVal: typeof entry.value !== "undefined" ? String(entry.value) : String(entry.valStr)

                                        width: Math.max(46, valText.implicitWidth + 16)
                                        height: 40
                                        radius: 8

                                        color: isKept ? (displayVal === "Heads" ? root.accentColor : (displayVal === "Tails" ? root.bgHover : root.bgBase)) : root.bgCard
                                        border.width: 1
                                        border.color: isKept ? root.accentColor : root.borderColor
                                        opacity: isKept ? 1.0 : 0.35

                                        Text {
                                            id: valText
                                            anchors.centerIn: parent
                                            text: displayVal
                                            color: isKept ? (displayVal === "Heads" ? "#11111b" : root.highlightColor) : root.highlightColor
                                            font.bold: isKept
                                            font.strikeout: !isKept
                                            font.pixelSize: 20
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        visible: root.lastRolls.length === 0 && root.coinResult === ""

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "🎲 " + root.diceCount + (root.selectedSides === 2 ? (root.diceCount === 1 ? " Coin" : " Coins") : ("d" + root.selectedSides)) + " (Waiting to roll...)"
                                color: root.highlightColor
                                font.pixelSize: 20
                                opacity: 0.8
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "TOTAL: ?"
                                color: root.borderColor
                                font.bold: true
                                font.pixelSize: 24
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: root.borderColor
                        }

                        Text {
                            text: "Undetermined Dice:"
                            color: root.highlightColor
                            font.pixelSize: 20
                            font.bold: true
                        }

                        ScrollView {
                            id: previewScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            Flow {
                                width: previewScroll.availableWidth > 0 ? previewScroll.availableWidth : 500
                                spacing: 8

                                Repeater {
                                    model: root.previewRolls

                                    delegate: Rectangle {
                                        width: 48
                                        height: 40
                                        radius: 8

                                        color: root.bgBase
                                        border.width: 2
                                        border.color: root.highlightColor

                                        Text {
                                            anchors.centerIn: parent
                                            text: String(modelData)
                                            color: root.highlightColor
                                            font.bold: true
                                            font.pixelSize: 20
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: root.bgCard
                border.width: 1
                border.color: root.borderColor
                visible: root.showHistoryPanel

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "📜 Roll History (" + historyModel.count + ")"
                            color: root.highlightColor
                            font.bold: true
                            font.pixelSize: 20
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 140
                            height: 34
                            radius: 8
                            color: clearMouse.containsMouse ? root.altAccent : root.bgBase
                            border.width: 1
                            border.color: root.borderColor

                            Text {
                                anchors.centerIn: parent
                                text: "Clear History"
                                color: clearMouse.containsMouse ? "#11111b" : root.highlightColor
                                font.bold: true
                                font.pixelSize: 20
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: historyModel.clear()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: root.borderColor
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                        model: historyModel

                        delegate: Rectangle {
                            width: ListView.view ? ListView.view.width : 0
                            height: 64
                            radius: 8
                            color: root.bgBase
                            border.width: 1
                            border.color: root.borderColor

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: model.timeStr + " • " + model.typeStr
                                        color: root.highlightColor
                                        font.bold: true
                                        font.pixelSize: 20
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: model.typeStr.indexOf("Coin") !== -1 ? model.rollsStr : ("Total: " + model.totalVal + " (Avg: " + model.avgVal + ")")
                                        color: root.accentColor
                                        font.bold: true
                                        font.pixelSize: 20
                                    }
                                }

                                Text {
                                    text: "Outcomes: [ " + model.rollsStr + " ]"
                                    color: root.highlightColor
                                    font.pixelSize: 20
                                    opacity: 0.7
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }
                }
            }
        }
    }
}
