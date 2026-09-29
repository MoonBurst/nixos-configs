import QtQuick
import Quickshell
import "../../style"

Item {
    id: calendarBox
    property var barWindow: null
    property string moduleName: "calendar"
    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: (shell && shell.theme && shell.theme.slantWidth) ? shell.theme.slantWidth : 12

    readonly property color themeBase02: (shell && shell.theme) ? shell.theme.base02 : "#222222"
    readonly property color themeBase05: (shell && shell.theme) ? shell.theme.base05 : "yellow"
    readonly property color themeBase0C: (shell && shell.theme) ? shell.theme.base0C : "#04f100"
    readonly property int themeFontSize: (shell && shell.theme) ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme) ? shell.theme.fontFamily : "monospace"

    property string dateStr: "01/01/0001"
    property var currentDate: new Date()
    property int currentMonth: currentDate.getMonth()
    property int currentYear: currentDate.getFullYear()

    // Interactive Month Browsing State
    property int displayMonth: currentMonth
    property int displayYear: currentYear

    property var daysOfWeek: [ "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" ]
    property bool pinTooltip: false
    property bool isTooltipHovered: false

    function prevMonth() {
        if (displayMonth === 0) { displayMonth = 11; displayYear--; }
        else { displayMonth--; }
    }

    function nextMonth() {
        if (displayMonth === 11) { displayMonth = 0; displayYear++; }
        else { displayMonth++; }
    }

    function resetToToday() {
        displayMonth = currentMonth;
        displayYear = currentYear;
    }

    implicitWidth: calendarText.implicitWidth + bg.leftPadding + bg.rightPadding + 20
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: calendarBox.slantLeft
        slantRight: calendarBox.slantRight
        slantWidth: calendarBox.slantWidth
    }

    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var date = new Date();
            calendarBox.currentDate = date;
            calendarBox.currentMonth = date.getMonth();
            calendarBox.currentYear = date.getFullYear();
            calendarBox.dateStr = date.toLocaleDateString(Qt.locale(), Locale.ShortFormat);
        }
    }

    Text {
        id: calendarText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 4
        anchors.rightMargin: bg.rightPadding + 4
        anchors.topMargin: 2; anchors.bottomMargin: 2
        color: themeBase05
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: calendarBox.dateStr
        elide: Text.ElideRight
        clip: true
    }

    // Clicking the date on the bar toggles the calendar pinned open
    TapHandler {
        onTapped: {
            calendarBox.pinTooltip = !calendarBox.pinTooltip;
        }
    }

    HoverHandler { id: calendarHoverTracker }

    Timer {
        id: closeGraceTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!calendarHoverTracker.hovered && !calendarBox.isTooltipHovered && !calendarBox.pinTooltip) {
                calendarTooltip.tooltipActive = false;
            }
        }
    }

    SlantedTooltip {
        id: calendarTooltip
        moduleItem: calendarBox
        barWindow: calendarBox.barWindow
        tooltipActive: calendarHoverTracker.hovered || calendarBox.isTooltipHovered
        pin: calendarBox.pinTooltip
        alignSide: "Left"
        slantLeft: calendarBox.slantLeft
        slantRight: calendarBox.slantRight

        Item {
            id: containerWrapper
            anchors.fill: parent
            readonly property real slantRatio: calendarTooltip.tooltipSlantWidth / calendarTooltip.tooltipHeight

            // Keeps the calendar open while hovering over the calendar window itself
            HoverHandler {
                id: tpHov
                onHoveredChanged: {
                    calendarBox.isTooltipHovered = hovered;
                    if (!hovered && !calendarHoverTracker.hovered && !calendarBox.pinTooltip) {
                        closeGraceTimer.restart();
                    }
                }
            }

            // Header Controls: Previous Month, Label, Next Month, Today Reset
            Row {
                y: 26
                x: calendarTooltip.slantX(y) + 32
                spacing: 12

                Rectangle {
                    width: 28; height: 28; radius: 4
                    color: prevHov.hovered ? themeBase02 : "transparent"
                    border.color: themeBase05; border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "◀"; color: themeBase05; font.pixelSize: 13 }
                    HoverHandler { id: prevHov }
                    TapHandler { onTapped: calendarBox.prevMonth() }
                }

                Text {
                    text: new Date(calendarBox.displayYear, calendarBox.displayMonth, 1).toLocaleDateString(Qt.locale(), "MMMM yyyy")
                    color: themeBase05; font.family: themeFontFamily; font.pixelSize: 20; font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 28; height: 28; radius: 4
                    color: nextHov.hovered ? themeBase02 : "transparent"
                    border.color: themeBase05; border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "▶"; color: themeBase05; font.pixelSize: 13 }
                    HoverHandler { id: nextHov }
                    TapHandler { onTapped: calendarBox.nextMonth() }
                }

                Rectangle {
                    visible: calendarBox.displayMonth !== calendarBox.currentMonth || calendarBox.displayYear !== calendarBox.currentYear
                    width: 60; height: 26; radius: 4
                    color: todayHov.hovered ? themeBase0C : "transparent"
                    border.color: themeBase0C; border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Today"; color: todayHov.hovered ? "#000000" : themeBase0C; font.pixelSize: 11; font.bold: true }
                    HoverHandler { id: todayHov }
                    TapHandler { onTapped: calendarBox.resetToToday() }
                }
            }

            Row {
                y: 75; x: calendarTooltip.slantX(y) + 24
                width: calendarTooltip.width - calendarTooltip.tooltipSlantWidth - 48
                Repeater {
                    model: calendarBox.daysOfWeek
                    Text { width: parent.width / 7; text: modelData; color: themeBase05; font.family: themeFontFamily; font.pixelSize: 15; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                }
            }

            Item {
                id: daysGridData
                readonly property int firstDayOffset: new Date(calendarBox.displayYear, calendarBox.displayMonth, 1).getDay()
                readonly property int daysInMonth: new Date(calendarBox.displayYear, calendarBox.displayMonth + 1, 0).getDate()
                readonly property int todayDate: calendarBox.currentDate.getDate()
                readonly property int todayMonth: calendarBox.currentDate.getMonth()
                readonly property int todayYear: calendarBox.currentDate.getFullYear()
            }

            Repeater {
                model: 6
                Row {
                    id: weekRow
                    readonly property int weekIndex: index
                    y: 110 + (index * 46); x: calendarTooltip.slantX(y) + 24
                    width: calendarTooltip.width - calendarTooltip.tooltipSlantWidth - 48
                    Repeater {
                        model: 7
                        delegate: Item {
                            id: dayCellItem
                            width: parent.width / 7; height: 42
                            readonly property int dayIndex: (weekRow.weekIndex * 7) + index
                            readonly property int dayNumber: dayIndex - daysGridData.firstDayOffset + 1
                            readonly property bool isValidDay: dayNumber > 0 && dayNumber <= daysGridData.daysInMonth
                            readonly property bool isToday: isValidDay && dayNumber === daysGridData.todayDate && calendarBox.displayMonth === daysGridData.todayMonth && calendarBox.displayYear === daysGridData.todayYear

                            SlantedBox {
                                anchors.fill: parent; visible: dayCellItem.isValidDay; slantLeft: "Left"; slantRight: "Left"
                                slantWidth: parent.height * containerWrapper.slantRatio
                                borderColor: dayCellItem.isToday ? themeBase05 : "transparent"
                                color: dayCellItem.isToday ? themeBase02 : "transparent"
                            }
                            Text {
                                anchors.centerIn: parent
                                text: dayCellItem.isValidDay ? dayCellItem.dayNumber : ""
                                color: dayCellItem.isToday ? themeBase05 : (dayCellItem.isValidDay ? themeBase05 : "transparent")
                                font.family: themeFontFamily; font.pixelSize: 20; font.bold: dayCellItem.isToday
                            }
                        }
                    }
                }
            }
        }
    }
}
