import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

Item {
    id: calendarBox

    // Styling & Layout
    anchors.fill: parent

    // --- SLANT CONFIGURATION ---
    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: shell.theme.slantWidth

    // Tooltip configuration
    property int tooltipHeight: 420

    // Tooltip slant
    readonly property real tooltipSlantWidth: (calendarBox.height > 0)
    ? (tooltipHeight * (slantWidth / calendarBox.height))
    : 15

    property int tooltipWidth: 410 + (tooltipSlantWidth * 2)

    // Global Widget Properties
    property var barWindow: null
    property string dateStr: "01/01/0001"

    // Calendar State Tracking
    property var currentDate: new Date()
    property int currentMonth: currentDate.getMonth()
    property int currentYear: currentDate.getFullYear()
    property var daysOfWeek: [ "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" ]

    // Toggle to pin the tooltip open for screenshots (Click the Calendar capsule to toggle)
    property bool pinTooltip: false

    // Centralized SlantedBox Background
    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: calendarBox.slantLeft
        slantRight: calendarBox.slantRight
        slantWidth: calendarBox.slantWidth
    }

    // Main Bar Date Update Loop
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var date = new Date()
            calendarBox.dateStr = date.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
        }
    }

    // Main Bar Display Text
    Text {
        id: calendarText
        anchors.fill: parent
        anchors.leftMargin: calendarBox.leftPadding
        anchors.rightMargin: calendarBox.rightPadding
        anchors.topMargin: shell.theme.globalPadding
        anchors.bottomMargin: shell.theme.globalPadding

        color: shell.theme.base05
        font.family: shell.theme.fontFamily
        font.pixelSize: shell.theme.globalFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: calendarBox.dateStr
    }

    HoverHandler {
        id: calendarHoverTracker
    }

    // Click to toggle/pin the tooltip
    TapHandler {
        onTapped: {
            calendarBox.pinTooltip = !calendarBox.pinTooltip
        }
    }

    // Dynamic Panel Renderer
    Loader {
        active: calendarHoverTracker.hovered || calendarBox.pinTooltip

        sourceComponent: Component {
            PanelWindow {
                screen: calendarBox.barWindow ? calendarBox.barWindow.screen : null
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-calendar-tooltip"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                anchors.top: true
                anchors.left: true
                anchors.right: false
                anchors.bottom: false

                implicitWidth: calendarBox.tooltipWidth
                implicitHeight: calendarBox.tooltipHeight
                color: "transparent"

                WlrLayershell.margins.top: shell.theme.globalPadding + 55

                // Centers dropdown aligned under the parent container
                WlrLayershell.margins.left: {
                    if (!calendarBox.barWindow || typeof calendarContainer === "undefined" || !calendarContainer) return 0;
                    var containerX = calendarContainer.x;
                    var calendarCenterAbsolute = containerX + (calendarContainer.width / 2);
                    var targetLeftMargin = Math.round(calendarCenterAbsolute - (calendarBox.tooltipWidth / 2));

                    return Math.max(targetLeftMargin, shell.theme.globalPadding);
                }

                // Tooltip background using SlantedBox
                SlantedBox {
                    id: tooltipBg
                    anchors.fill: parent
                    slantLeft: calendarBox.slantLeft
                    slantRight: calendarBox.slantRight
                    slantWidth: calendarBox.tooltipSlantWidth

                    readonly property color colorBase04: (shell && shell.theme) ? (shell.theme.base04 || "gray") : "gray"
                    readonly property color colorBase02: (shell && shell.theme) ? (shell.theme.base02 || "#222222") : "#222222"
                    readonly property string fontFamily: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"
                    readonly property real slantRatio: (height > 0) ? (slantWidth / height) : 0.35
                }


                Item {
                    anchors.fill: parent

                    // Month/Year Header
                    Text {
                        text: calendarBox.currentDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                        color: shell.theme.base05
                        font.family: tooltipBg.fontFamily
                        font.pixelSize: 22
                        font.bold: true

                        y: 30
                        x: (y * tooltipBg.slantRatio) + 24
                    }

                    // Slanted Days of the Week Headers
                    Row {
                        y: 75
                        x: (y * tooltipBg.slantRatio) + 24
                        width: tooltipBg.width - calendarBox.tooltipSlantWidth - 48
                        spacing: 0

                        Repeater {
                            model: calendarBox.daysOfWeek

                            Text {
                                width: parent.width / 7
                                text: modelData
                                color: tooltipBg.colorBase04
                                font.family: tooltipBg.fontFamily
                                font.pixelSize: 15
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Tooltip Calendar
                    Item {
                        id: daysGridData
                        readonly property int firstDayOffset: new Date(calendarBox.currentYear, calendarBox.currentMonth, 1).getDay()
                        readonly property int daysInMonth: new Date(calendarBox.currentYear, calendarBox.currentMonth + 1, 0).getDate()
                        readonly property int todayDate: new Date().getDate()
                        readonly property int todayMonth: new Date().getMonth()
                        readonly property int todayYear: new Date().getFullYear()
                    }

                    // Slanted Matrix Weeks
                    Repeater {
                        model: 6 // 6 weeks maximum matrix layout

                        Row {
                            id: weekRow
                            readonly property int weekIndex: index

                            y: 110 + (index * 46) // Vertical row spacing
                            x: (y * tooltipBg.slantRatio) + 24
                            width: tooltipBg.width - calendarBox.tooltipSlantWidth - 48
                            spacing: 0

                            Repeater {
                                model: 7 // 7 days per week row

                                delegate: Item {
                                    id: dayCellItem
                                    width: parent.width / 7 // Scales each cell dynamically
                                    height: 42

                                    readonly property int dayIndex: (weekRow.weekIndex * 7) + index
                                    readonly property int dayNumber: dayIndex - daysGridData.firstDayOffset + 1
                                    readonly property bool isValidDay: dayNumber > 0 && dayNumber <= daysGridData.daysInMonth
                                    readonly property bool isToday: isValidDay &&
                                    dayNumber === daysGridData.todayDate &&
                                    calendarBox.currentMonth === daysGridData.todayMonth &&
                                    calendarBox.currentYear === daysGridData.todayYear

                                    // Day Cell Background
                                    SlantedBox {
                                        anchors.fill: parent
                                        visible: dayCellItem.isValidDay
                                        slantLeft: "Left"
                                        slantRight: "Left"
                                        slantWidth: parent.height * tooltipBg.slantRatio
                                        borderColor: dayCellItem.isToday ? shell.theme.base05 : "transparent"
                                        color: dayCellItem.isToday ? tooltipBg.colorBase02 : tooltipBg.color
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCellItem.isValidDay ? dayCellItem.dayNumber : ""
                                        color: shell.theme.base05
                                        font.family: tooltipBg.fontFamily
                                        font.pixelSize: shell.theme.globalFontSize
                                        font.bold: dayCellItem.isToday
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
