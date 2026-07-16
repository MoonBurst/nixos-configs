import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import "../../style"

Item {
    id: alarmInputFieldRoot

    width: parent ? parent.width : 340
    implicitHeight: 280

    property alias countdownText: countdownField.text
    property alias targetTimeText: targetTimeField.text
    property bool editingHours: true
    property real slantRatio: 0.35

    readonly property color colorBase05: (shell && shell.theme) ? (shell.theme.base05 || "yellow") : "yellow"
    readonly property color colorBase00: (shell && shell.theme) ? (shell.theme.base00 || "black") : "black"
    readonly property color colorBase03: (shell && shell.theme) ? (shell.theme.base03 || "#333333") : "#333333"
    readonly property string fontFamily: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"

    signal accepted()
    signal rejected()

    function forceInitialFocus() {
        // Clear countdown field on open
        countdownField.text = "";

        var now = new Date();
        var currentHours = now.getHours();
        var currentMinutes = String(now.getMinutes()).padStart(2, '0');

        var displayHours = currentHours % 12;
        if (displayHours === 0) displayHours = 12;

        // Populate target time field
        targetTimeField.text = displayHours + ":" + currentMinutes;

        alarmInputFieldRoot.editingHours = true;
        countdownField.forceActiveFocus();
    }

    function adjustTimeSegment(isUp) {
        var parts = targetTimeField.text.split(":");
        if (parts.length !== 2) return;

        var h = parseInt(parts[0], 10);
        var m = parseInt(parts[1], 10);
        if (isNaN(h)) h = 12;
        if (isNaN(m)) m = 0;

        if (alarmInputFieldRoot.editingHours) {
            if (isUp) {
                h = (h === 12) ? 1 : h + 1;
            } else {
                h = (h === 1) ? 12 : h - 1;
            }
        } else {
            if (isUp) {
                m = (m === 59) ? 0 : m + 1;
            } else {
                m = (m === 0) ? 59 : m - 1;
            }
        }

        var hStr = String(h);
        var mStr = String(m).padStart(2, '0');
        targetTimeField.text = hStr + ":" + mStr;
        countdownField.text = "";

        updateTimeSelection();
    }

    function updateTimeSelection() {
        var colonIdx = targetTimeField.text.indexOf(":");
        if (colonIdx === -1) return;

        if (alarmInputFieldRoot.editingHours) {
            targetTimeField.select(0, colonIdx);
        } else {
            targetTimeField.select(colonIdx + 1, targetTimeField.text.length);
        }
    }

        //countdown field
        Item {
        id: countdownBlock
        y: 20
        x: 175 * alarmInputFieldRoot.slantRatio
        width: alarmInputFieldRoot.width - (175 * alarmInputFieldRoot.slantRatio)
        height: 100

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            text: "countdown"
            color: alarmInputFieldRoot.colorBase05
            font.family: alarmInputFieldRoot.fontFamily
            font.pixelSize: 24
            font.bold: true
        }

        TextField {
            id: countdownField
            anchors.horizontalCenter: parent.horizontalCenter
            y: 40

            width: parent.width
            height: 50
            font.family: alarmInputFieldRoot.fontFamily
            font.pixelSize: 22
            font.bold: true

            color: alarmInputFieldRoot.colorBase05
            selectionColor: alarmInputFieldRoot.colorBase05
            selectedTextColor: alarmInputFieldRoot.colorBase00
            horizontalAlignment: Text.AlignHCenter

            // Padding prevents typed numbers from clipping on slanted edges
            leftPadding: 28
            rightPadding: 24

            onTextChanged: {
                if (activeFocus && text.trim() !== "") {
                    targetTimeField.text = "";
                }
            }

            onAccepted: alarmInputFieldRoot.accepted()

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    alarmInputFieldRoot.rejected();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    var cNum = parseInt(countdownField.text, 10);
                    if (isNaN(cNum)) cNum = 0;
                    countdownField.text = String(cNum + 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    var cNum2 = parseInt(countdownField.text, 10);
                    if (isNaN(cNum2) || cNum2 <= 0) cNum2 = 1;
                    countdownField.text = String(cNum2 - 1);
                    event.accepted = true;
                }
            }

            background: SlantedBox {
                id: countdownBg
                anchors.fill: parent
                slantLeft: "Left"
                slantRight: "Left"
                slantWidth: countdownField.height * alarmInputFieldRoot.slantRatio
                borderColor: countdownField.focus ? alarmInputFieldRoot.colorBase05 : alarmInputFieldRoot.colorBase03
                color: alarmInputFieldRoot.colorBase00
                borderWidth: 2
            }
        }
    }

        // What Time field
        Item {
        id: targetTimeBlock
        y: 150
        x: 275 * alarmInputFieldRoot.slantRatio
        width: alarmInputFieldRoot.width - (150 * alarmInputFieldRoot.slantRatio)
        height: 100

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            text: "what time?"
            color: alarmInputFieldRoot.colorBase05
            font.family: alarmInputFieldRoot.fontFamily
            font.pixelSize: 24
            font.bold: true
        }

        TextField {
            id: targetTimeField
            anchors.horizontalCenter: parent.horizontalCenter
            y: 40

            width: parent.width
            height: 50
            font.family: alarmInputFieldRoot.fontFamily
            font.pixelSize: 22
            font.bold: true

            color: alarmInputFieldRoot.colorBase05
            selectionColor: alarmInputFieldRoot.colorBase05
            selectedTextColor: alarmInputFieldRoot.colorBase00
            horizontalAlignment: Text.AlignHCenter

            leftPadding: 28
            rightPadding: 24

            onTextChanged: {
                if (activeFocus && text.trim() !== "") {
                    countdownField.text = "";
                }
            }

            onAccepted: alarmInputFieldRoot.accepted()

            onActiveFocusChanged: {
                if (activeFocus) {
                    alarmInputFieldRoot.updateTimeSelection();
                }
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    alarmInputFieldRoot.rejected();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left) {
                    alarmInputFieldRoot.editingHours = true;
                    alarmInputFieldRoot.updateTimeSelection();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    alarmInputFieldRoot.editingHours = false;
                    alarmInputFieldRoot.updateTimeSelection();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    alarmInputFieldRoot.adjustTimeSegment(true);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    alarmInputFieldRoot.adjustTimeSegment(false);
                    event.accepted = true;
                }
            }

            background: SlantedBox {
                id: targetTimeBg
                anchors.fill: parent
                slantLeft: "Left"
                slantRight: "Left"
                slantWidth: targetTimeField.height * alarmInputFieldRoot.slantRatio
                borderColor: targetTimeField.focus ? alarmInputFieldRoot.colorBase05 : alarmInputFieldRoot.colorBase03
                color: alarmInputFieldRoot.colorBase00
                borderWidth: 2
            }
        }
    }
}
