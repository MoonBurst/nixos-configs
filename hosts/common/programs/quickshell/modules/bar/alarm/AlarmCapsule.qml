// AlarmCapsule.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "." as AlarmInput
import "../../style"

Item {
    id: alarmBox
    property var barWindow: null
    property bool pinTooltip: false

    // Theme Fallbacks
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property color themeBase00: (shell && shell.theme && typeof shell.theme.base00 !== "undefined") ? shell.theme.base00 : "black"
    readonly property color themeBase02: (shell && shell.theme && typeof shell.theme.base02 !== "undefined") ? shell.theme.base02 : "#222222"
    readonly property color themeBase03: (shell && shell.theme && typeof shell.theme.base03 !== "undefined") ? shell.theme.base03 : "#333333"
    readonly property color themeBase05: (shell && shell.theme && typeof shell.theme.base05 !== "undefined") ? shell.theme.base05 : "yellow"

    // =========================================================================
    //  EDITABLE TOOLTIP & INPUT LAYOUT CONFIGURATION
    // =========================================================================
    property int tooltipHeight: 350
    property int tooltipCollapsedWidth: 110
    property int tooltipExpandedWidth: 350
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 21

    property int countdownBlockY: 80
    property int targetTimeBlockY: 200

    property int countdownBlockXOffset: 20
    property int targetTimeBlockXOffset: 20

    property int blockHeight: 100
    property int fieldHeight: 50
    property int fieldLabelSpacing: 40

    property int inputLeftPadding: 50
    property int inputRightPadding: 50
    // =========================================================================

    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: alarmBox.themeSlantWidth

    property string alarmDisplayText: "No Alarm"
    property string stateFile: "/tmp/waybar_alarm_state"
    property bool popupVisible: false

    width: 140
    Layout.preferredWidth: 140
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: alarmBox.slantLeft
        slantRight: alarmBox.slantRight
        slantWidth: alarmBox.slantWidth
    }

    // Alarm state check with Real PipeWire 25% Hardware Attenuation & 3-Second Cut-off
    Process {
        id: alarmFetcher
        running: true
        command: [
            "sh", "-c",
            "SF='/tmp/waybar_alarm_state'; [ ! -f \"$SF\" ] && echo \"No Alarm\" && exit 0; " +
            "read start total msg < \"$SF\"; cur=$(date +%s); el=$((cur - start)); rem=$((total - el)); " +
            "if [ $rem -le 0 ]; then " +
            "  /run/current-system/sw/bin/notify-send -t 10000 \"Alarm Alert\" \"$(echo \"$msg\" | sed 's/\"//g')\"; " +
            "  (timeout 3s pw-play --volume 0.25 ~/Documents/communicator.mp3 || mpv --no-video --volume=25 --end=3 ~/Documents/communicator.mp3 || true) & " +
            "  echo \"No Alarm\"; rm -f \"$SF\"; " +
            "else " +
            "  h=$((rem / 3600)); m=$(((rem % 3600) / 60)); s=$((rem % 60)); " +
            "  printf \"%02dh %02dm %02ds\\n\" $h $m $s; " +
            "fi"
        ]
        stdout: SplitParser {
            onRead: data => { alarmBox.alarmDisplayText = data ? data.trim() : "No Alarm" }
        }
    }

    Process { id: alarmCancelEngine; running: false; command: ["rm", "-f", "/tmp/waybar_alarm_state"] }
    Process { id: alarmWriteEngine; running: false }

    function confirmAndSaveAlarm(countdownRaw, timeOfDayRaw) {
        var msg = "Alarm Finished!";
        var totalSeconds = 0;
        var currentEpoch = Math.floor(Date.now() / 1000);
        var now = new Date();

        if (countdownRaw && countdownRaw.trim() !== "") {
            var rawTimer = countdownRaw.trim().toLowerCase();
            var match;
            var regex = /(\d+)([hms])/g;

            while ((match = regex.exec(rawTimer)) !== null) {
                var num = parseInt(match[1], 10);
                var unit = match[2];

                if (unit === 'h') totalSeconds += num * 3600;
                if (unit === 'm') totalSeconds += num * 60;
                if (unit === 's') totalSeconds += num;
            }

            if (totalSeconds === 0 && /^\d+$/.test(rawTimer)) {
                totalSeconds = parseInt(rawTimer, 10) * 60;
            }
        }

        if (totalSeconds === 0 && timeOfDayRaw && timeOfDayRaw.trim() !== "") {
            var timeStr = timeOfDayRaw.trim().toUpperCase().replace(/[:\s]/g, "");
            var cleanMatch = /^(\d{3,4})(AM|PM)?$/.exec(timeStr);

            if (cleanMatch !== null) {
                var digits = cleanMatch[1];
                var ampm = cleanMatch[2];
                var targetHours = 0;
                var targetMinutes = 0;

                if (digits.length === 4) {
                    targetHours = parseInt(digits.substring(0, 2), 10);
                    targetMinutes = parseInt(digits.substring(2, 4), 10);
                } else if (digits.length === 3) {
                    targetHours = parseInt(digits.substring(0, 1), 10);
                    targetMinutes = parseInt(digits.substring(1, 3), 10);
                }

                if (targetHours <= 24 && targetMinutes < 60) {
                    if (targetHours === 12 && !ampm) {
                        targetHours = 12;
                    } else if (ampm) {
                        if (ampm === "PM" && targetHours < 12) targetHours += 12;
                        if (ampm === "AM" && targetHours === 12) targetHours = 0;
                    }

                    var targetTime = new Date(now.getFullYear(), now.getMonth(), now.getDate(), targetHours, targetMinutes, 0, 0);

                    if (!ampm && targetHours <= 12 && targetTime.getTime() <= now.getTime()) {
                        var pmHours = (targetHours === 12) ? 0 : targetHours + 12;
                        var pmTime = new Date(now.getFullYear(), now.getMonth(), now.getDate(), pmHours, targetMinutes, 0, 0);

                        if (pmTime.getTime() > now.getTime()) {
                            targetTime = pmTime;
                        }
                    }

                    if (targetTime.getTime() <= now.getTime()) {
                        targetTime.setDate(targetTime.getDate() + 1);
                    }

                    totalSeconds = Math.floor(targetTime.getTime() / 1000) - currentEpoch;
                }
            }
        }

        if (totalSeconds > 0) {
            var stateString = currentEpoch + " " + totalSeconds + " \"" + msg + "\"";
            alarmWriteEngine.command = ["sh", "-c", "echo '" + stateString + "' > /tmp/waybar_alarm_state"];
            alarmWriteEngine.running = false;
            alarmWriteEngine.running = true;
        }
        cancelAndClosePopup();
    }

    function cancelAndClosePopup() {
        if (typeof timeInput !== "undefined" && timeInput !== null) {
            timeInput.clearInput();
        }
        alarmBox.popupVisible = false;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                alarmBox.popupVisible = !alarmBox.popupVisible;
            } else if (mouse.button === Qt.RightButton) {
                alarmCancelEngine.running = false;
                alarmCancelEngine.running = true;
                alarmBox.alarmDisplayText = "No Alarm";
                cancelAndClosePopup();
            }
        }
    }

    Text {
        id: alarmText
        anchors.fill: parent

        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: themePadding
        anchors.bottomMargin: themePadding

        text: alarmBox.alarmDisplayText
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        color: themeBase05
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    SlantedTooltip {
        id: alarmTooltip
        moduleItem: alarmBox
        barWindow: alarmBox.barWindow
        tooltipActive: alarmBox.popupVisible

        alignSide: "Left"
        keyboardFocus: WlrLayershell.Exclusive

        tooltipHeight: alarmBox.tooltipHeight
        collapsedCoreWidth: alarmBox.tooltipCollapsedWidth
        expandedCoreWidth: alarmBox.tooltipExpandedWidth
        topOffset: alarmBox.tooltipTopOffset
        rightOffset: alarmBox.tooltipRightOffset

        slantLeft: alarmBox.slantLeft
        slantRight: alarmBox.slantRight

        onVisibleChanged: {
            if (visible && typeof timeInput !== "undefined" && timeInput !== null) {
                timeInput.forceInitialFocus();
            }
        }

        Item {
            id: alarmInputWrapper
            anchors.fill: parent

            readonly property real slantRatio: alarmTooltip.tooltipSlantWidth / alarmTooltip.tooltipHeight

            Text {
                id: alarmTitle
                text: "Set Alarm"
                font.family: themeFontFamily
                font.pixelSize: 22
                font.bold: true
                color: themeBase05
                y: 20
                x: alarmTooltip.slantX(y) + 150
            }

            Rectangle {
                id: alarmDivider
                height: 2
                color: themeBase02
                width: 360
                y: 70
                x: alarmTooltip.slantX(y) + 24
            }

            Item {
                id: timeInput
                y: 95
                x: alarmTooltip.slantX(y) + 24
                width: 360

                property bool editingHours: true
                readonly property string countdownText: countdownField.text
                readonly property string targetTimeText: targetTimeField.text

                function clearInput() {
                    countdownField.text = "";
                }

                function forceInitialFocus() {
                    countdownField.text = "";
                    var now = new Date();
                    var currentHours = now.getHours();
                    var currentMinutes = String(now.getMinutes()).padStart(2, '0');
                    var displayHours = currentHours % 12;
                    if (displayHours === 0) displayHours = 12;
                    targetTimeField.text = displayHours + ":" + currentMinutes;
                    timeInput.editingHours = true;
                    countdownField.forceActiveFocus();
                }

                function adjustTimeSegment(isUp) {
                    var parts = targetTimeField.text.split(":");
                    if (parts.length !== 2) return;

                    var h = parseInt(parts[0], 10);
                    var m = parseInt(parts[1], 10);
                    if (isNaN(h)) h = 12;
                    if (isNaN(m)) m = 0;

                    if (timeInput.editingHours) {
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
                    timeInput.updateTimeSelection();
                }

                function updateTimeSelection() {
                    var colonIdx = targetTimeField.text.indexOf(":");
                    if (colonIdx === -1) return;

                    if (timeInput.editingHours) {
                        targetTimeField.select(0, colonIdx);
                    } else {
                        targetTimeField.select(colonIdx + 1, targetTimeField.text.length);
                    }
                }

                Item {
                    id: countdownBlock
                    y: alarmBox.countdownBlockY - 95
                    x: (alarmTooltip.slantX(y + 150) - alarmTooltip.slantX(95)) + alarmBox.countdownBlockXOffset
                    width: parent.width - x - 80
                    height: alarmBox.blockHeight

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        text: "Countdown"
                        color: themeBase05
                        font.family: themeFontFamily
                        font.pixelSize: 24
                        font.bold: true
                    }

                    TextField {
                        id: countdownField
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: alarmBox.fieldLabelSpacing

                        width: parent.width
                        height: alarmBox.fieldHeight
                        font.family: themeFontFamily
                        font.pixelSize: 22
                        font.bold: true

                        color: themeBase05
                        selectionColor: themeBase05
                        selectedTextColor: themeBase00
                        horizontalAlignment: Text.AlignHCenter

                        leftPadding: alarmBox.inputLeftPadding
                        rightPadding: alarmBox.inputRightPadding

                        onTextChanged: {
                            if (activeFocus && text.trim() !== "") {
                                targetTimeField.text = "";
                            }
                        }

                        onAccepted: alarmBox.confirmAndSaveAlarm(countdownField.text, targetTimeField.text)

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                alarmBox.cancelAndClosePopup();
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
                            anchors.fill: parent
                            slantLeft: "Left"
                            slantRight: "Left"
                            slantWidth: parent.height * alarmInputWrapper.slantRatio
                            borderColor: countdownField.focus ? themeBase05 : themeBase03
                            color: themeBase00
                            borderWidth: 2
                        }
                    }
                }

                Item {
                    id: targetTimeBlock
                    y: alarmBox.targetTimeBlockY - 95
                    x: (alarmTooltip.slantX(y + 150) - alarmTooltip.slantX(95)) + alarmBox.targetTimeBlockXOffset
                    width: parent.width - x - 24
                    height: alarmBox.blockHeight

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        text: "What time?"
                        color: themeBase05
                        font.family: themeFontFamily
                        font.pixelSize: 24
                        font.bold: true
                    }

                    TextField {
                        id: targetTimeField
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: alarmBox.fieldLabelSpacing

                        width: parent.width
                        height: alarmBox.fieldHeight
                        font.family: themeFontFamily
                        font.pixelSize: 22
                        font.bold: true

                        color: themeBase05
                        selectionColor: themeBase05
                        selectedTextColor: themeBase00
                        horizontalAlignment: Text.AlignHCenter

                        leftPadding: alarmBox.inputLeftPadding
                        rightPadding: alarmBox.inputRightPadding

                        onTextChanged: {
                            if (activeFocus && text.trim() !== "") {
                                countdownField.text = "";
                            }
                        }

                        onAccepted: alarmBox.confirmAndSaveAlarm(countdownField.text, targetTimeField.text)

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                timeInput.updateTimeSelection();
                            }
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                alarmBox.cancelAndClosePopup();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Left) {
                                timeInput.editingHours = true;
                                timeInput.updateTimeSelection();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Right) {
                                timeInput.editingHours = false;
                                timeInput.updateTimeSelection();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                timeInput.adjustTimeSegment(true);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                timeInput.adjustTimeSegment(false);
                                event.accepted = true;
                            }
                        }

                        background: SlantedBox {
                            anchors.fill: parent
                            slantLeft: "Left"
                            slantRight: "Left"
                            slantWidth: parent.height * alarmInputWrapper.slantRatio
                            borderColor: targetTimeField.focus ? themeBase05 : themeBase03
                            color: themeBase00
                            borderWidth: 2
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            alarmFetcher.running = false;
            alarmFetcher.running = true;
        }
    }
}
