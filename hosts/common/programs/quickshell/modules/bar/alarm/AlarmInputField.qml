import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: alarmInputGroupRoot
    spacing: 12
    anchors.horizontalCenter: parent.horizontalCenter

    property alias countdownText: countdownField.text
    property alias targetTimeText: targetTimeField.text

    property bool editingHours: true

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

        alarmInputGroupRoot.editingHours = true;
        countdownField.forceActiveFocus();
    }

    function adjustTimeSegment(isUp) {
        var parts = targetTimeField.text.split(":");
        if (parts.length !== 2) return;

        var h = parseInt(parts[0], 10);
        var m = parseInt(parts[1], 10);
        if (isNaN(h)) h = 12;
        if (isNaN(m)) m = 0;

        if (alarmInputGroupRoot.editingHours) {
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

        // Clear countdown field because user is now adjusting target time
        countdownField.text = "";

        updateTimeSelection();
    }

    function updateTimeSelection() {
        var colonIdx = targetTimeField.text.indexOf(":");
        if (colonIdx === -1) return;

        if (alarmInputGroupRoot.editingHours) {
            targetTimeField.select(0, colonIdx);
        } else {
            targetTimeField.select(colonIdx + 1, targetTimeField.text.length);
        }
    }

    // ============================================================================
    // FIELD 1: COUNTDOWN
    // ============================================================================
    ColumnLayout {
        spacing: 4
        Layout.alignment: Qt.AlignHCenter

        Text {
            text: "countdown"
            color: "yellow"
            font.family: "monospace"
            font.pixelSize: 20
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        TextField {
            id: countdownField

            Layout.preferredWidth: 180
            Layout.preferredHeight: 40
            font.family: "monospace"
            font.pixelSize: 20
            font.bold: true

            color: "yellow"
            selectionColor: "yellow"
            selectedTextColor: "black"
            horizontalAlignment: Text.AlignHCenter

            //  If the user types a countdown, clear the target clock field
            onTextChanged: {
                if (activeFocus && text.trim() !== "") {
                    targetTimeField.text = "";
                }
            }

            onAccepted: alarmInputGroupRoot.accepted()

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    alarmInputGroupRoot.rejected();
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

            background: Rectangle {
                color: "black"
                border.width: 2
                border.color: parent.focus ? "yellow" : "#333333"
                radius: 4
            }
        }
    }

    // ============================================================================
    // FIELD 2: WHAT TIME?
    // ============================================================================
    ColumnLayout {
        spacing: 4
        Layout.alignment: Qt.AlignHCenter

        Text {
            text: "what time?"
            color: "yellow"
            font.family: "monospace"
            font.pixelSize: 20
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        TextField {
            id: targetTimeField

            Layout.preferredWidth: 180
            Layout.preferredHeight: 38
            font.family: "monospace"
            font.pixelSize: 20
            font.bold: true

            color: "yellow"
            selectionColor: "yellow"
            selectedTextColor: "black"
            horizontalAlignment: Text.AlignHCenter

            // If the user explicitly clicks/tabs here and types, wipe the countdown field
            onTextChanged: {
                if (activeFocus && text.trim() !== "") {
                    countdownField.text = "";
                }
            }

            onAccepted: alarmInputGroupRoot.accepted()

            onActiveFocusChanged: {
                if (activeFocus) {
                    alarmInputGroupRoot.updateTimeSelection();
                }
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    alarmInputGroupRoot.rejected();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left) {
                    alarmInputGroupRoot.editingHours = true;
                    alarmInputGroupRoot.updateTimeSelection();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    alarmInputGroupRoot.editingHours = false;
                    alarmInputGroupRoot.updateTimeSelection();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    alarmInputGroupRoot.adjustTimeSegment(true);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    alarmInputGroupRoot.adjustTimeSegment(false);
                    event.accepted = true;
                }
            }

            background: Rectangle {
                color: "black"
                border.width: 2
                border.color: parent.focus ? "yellow" : "#333333"
                radius: 4
            }
        }
    }
}
