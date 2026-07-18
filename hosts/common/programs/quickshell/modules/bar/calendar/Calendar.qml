// CalendarCapsule.qml
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

    anchors.fill: parent

    // =========================================================================
    //  EDITABLE TOOLTIP CONFIGURATION
    // =========================================================================
    property int tooltipHeight: 350          // Vertical height of the expanded box
    property int tooltipCollapsedWidth: 130  // Sleek, thin width during the downward unroll
    property int tooltipExpandedWidth: 430   // Final horizontal width once fully open
    property int tooltipTopOffset: 0         // Micro-adjust vertical spacing (px)
    property int tooltipRightOffset: 22       // Micro-adjust horizontal alignment (px)
    // =========================================================================

    property string slantLeft: "Left"
    property string slantRight: "Left"
    property int slantWidth: shell.theme.slantWidth
    property var barWindow: null
    property string dateStr: "01/01/0001"
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
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
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

    TapHandler {
        onTapped: {
            //uncomment this to allow clicking to lock it on the screen
             calendarBox.pinTooltip = !calendarBox.pinTooltip
        }
    }

    // Panel Window Pop-up Renderer
    Loader {
        id: tooltipLoader
        active: calendarHoverTracker.hovered || calendarBox.pinTooltip || (tooltipLoader.item && tooltipLoader.item.animHeight > 0)

        sourceComponent: Component {
            SlantedTooltip {
                id: calendarTooltip
                moduleItem: calendarBox
                barWindow: calendarBox.barWindow
                tooltipActive: calendarHoverTracker.hovered
                pin: calendarBox.pinTooltip

                // Instruct the template to align left and expand rightwards
                alignSide: "Left"

                // Maps variables defined at the top of the file
                tooltipHeight: calendarBox.tooltipHeight
                collapsedCoreWidth: calendarBox.tooltipCollapsedWidth
                expandedCoreWidth: calendarBox.tooltipExpandedWidth
                topOffset: calendarBox.tooltipTopOffset
                rightOffset: calendarBox.tooltipRightOffset

                // pass capsule slants to keep the window parallel
                slantLeft: calendarBox.slantLeft
                slantRight: calendarBox.slantRight

                // Stationary layout wrapper (maps old theme properties securely to the new scope)
                Item {
                    id: containerWrapper
                    anchors.fill: parent

                    readonly property string fontFamily: (shell && shell.theme) ? (shell.theme.fontFamily || "monospace") : "monospace"
                    readonly property color colorBase05: (shell && shell.theme) ? (shell.theme.base05 || "yellow") : "yellow"
                    readonly property color colorBase02: (shell && shell.theme) ? (shell.theme.base02 || "#222222") : "#222222"
                    readonly property real slantRatio: calendarTooltip.tooltipSlantWidth / calendarTooltip.tooltipHeight

                    // Month/Year Header
                    Text {
                        text: calendarBox.currentDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                        color: shell.theme.base05
                        font.family: containerWrapper.fontFamily
                        font.pixelSize: 22
                        font.bold: true

                        y: 30
                        x: calendarTooltip.slantX(y) + 24
                    }

                    //Days of the Week Headers
                    Row {
                        y: 75
                        x: calendarTooltip.slantX(y) + 24
                        width: calendarTooltip.width - calendarTooltip.tooltipSlantWidth - 48
                        spacing: 0

                        Repeater {
                            model: calendarBox.daysOfWeek

                            Text {
                                width: parent.width / 7
                                text: modelData
                                color: containerWrapper.colorBase05 // Updated to use the standard text color (base05)
                                font.family: containerWrapper.fontFamily
                                font.pixelSize: 15
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Tooltip Calendar Calculations Helper
                    Item {
                        id: daysGridData
                        readonly property int firstDayOffset: new Date(calendarBox.currentYear, calendarBox.currentMonth, 1).getDay()
                        readonly property int daysInMonth: new Date(calendarBox.currentYear, calendarBox.currentMonth + 1, 0).getDate()
                        readonly property int todayDate: new Date().getDate()
                        readonly property int todayMonth: new Date().getMonth()
                        readonly property int todayYear: new Date().getFullYear()
                    }

                    // Matrix Weeks
                    Repeater {
                        model: 6 // 6 weeks maximum matrix layout

                        Row {
                            id: weekRow
                            readonly property int weekIndex: index

                            y: 110 + (index * 46) // Vertical row spacing
                            x: calendarTooltip.slantX(y) + 24
                            width: calendarTooltip.width - calendarTooltip.tooltipSlantWidth - 48
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
                                        slantWidth: parent.height * containerWrapper.slantRatio
                                        borderColor: dayCellItem.isToday ? shell.theme.base05 : "transparent"
                                        color: dayCellItem.isToday ? containerWrapper.colorBase02 : bg.color
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCellItem.isValidDay ? dayCellItem.dayNumber : ""
                                        color: shell.theme.base05
                                        font.family: containerWrapper.fontFamily
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
