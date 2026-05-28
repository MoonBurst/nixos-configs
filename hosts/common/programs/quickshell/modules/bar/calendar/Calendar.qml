import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland

Rectangle {
    id: calendarBox

    // Styling & Layout
    anchors.fill: parent
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth
    color: shell.theme.base00
    border.color: shell.theme.base05

    // Global Widget Properties
    property var barWindow: null
    property string dateStr: "01/01/2026"

    // Calendar State Tracking
    property var currentDate: new Date()
    property int currentMonth: currentDate.getMonth()
    property int currentYear: currentDate.getFullYear()
    property var daysOfWeek: [ "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" ]

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
        anchors.margins: shell.theme.globalPadding
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

    // ============================================================================
    // THE CALENDAR POPOVER PANEL WINDOW
    // ============================================================================
    PanelWindow {
        id: calendarTooltipWindow

        // Wayland Display Settings
        screen: calendarBox.barWindow ? calendarBox.barWindow.screen : null
        visible: calendarHoverTracker.hovered
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-calendar-tooltip"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Sizing & Positioning Constraints
        anchors.top: true
        anchors.left: true
        anchors.right: false
        anchors.bottom: false
        implicitWidth: 300
        implicitHeight: 320
        color: "transparent"

        // Dynamic Relative Alignment Logic
        WlrLayershell.margins.left: {
            if (!calendarBox.barWindow) return 0;

            var containerX = calendarContainer.x;
            var calendarCenterAbsolute = containerX + (calendarContainer.width / 2);
            var targetLeftMargin = Math.round(calendarCenterAbsolute - (implicitWidth / 2));

            return Math.max(targetLeftMargin, shell.theme.globalPadding);
        }

        WlrLayershell.margins.top: {
            if (!calendarBox.barWindow) return 0;
            return shell.theme.globalPadding + mainBarContainer.capsuleHeight + 8;
        }

        // Tooltip Window Content Wrapper
        Rectangle {
            anchors.fill: parent
            radius: shell.theme.defaultCardRadius
            border.width: shell.theme.globalBorderWidth
            color: shell.theme.base00
            border.color: shell.theme.base05

            Column {
                anchors.fill: parent
                anchors.margins: shell.theme.globalPadding
                spacing: 12

                // Header Component (Month & Year Title)
                Text {
                    width: parent.width
                    text: calendarBox.currentDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                    color: shell.theme.base05
                    font.family: shell.theme.fontFamily
                    font.pixelSize: shell.theme.globalFontSize + 2
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                // Days of the Week Row (Header Labels)
                Grid {
                    width: parent.width
                    columns: 7
                    spacing: 4

                    Repeater {
                        model: calendarBox.daysOfWeek

                        Text {
                            width: (parent.width - 24) / 7
                            text: modelData
                            color: shell.theme.base04
                            font.family: shell.theme.fontFamily
                            font.pixelSize: shell.theme.globalFontSize - 2
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Interactive Days Grid Matrix Area
                Grid {
                    id: daysGrid
                    width: parent.width
                    columns: 7
                    spacing: 4

                    // Optimized Calendar Structural State Metrics
                    readonly property int firstDayOffset: new Date(calendarBox.currentYear, calendarBox.currentMonth, 1).getDay()
                    readonly property int daysInMonth: new Date(calendarBox.currentYear, calendarBox.currentMonth + 1, 0).getDate()
                    readonly property int todayDate: new Date().getDate()
                    readonly property int todayMonth: new Date().getMonth()
                    readonly property int todayYear: new Date().getFullYear()

                    Repeater {
                        model: 42 // Max standard layout slots for a month matrix

                        delegate: Item {
                            // Layout Sizing Metrics
                            width: (parent.width - 24) / 7
                            height: width

                            // Positional Grid Flags
                            readonly property int dayNumber: index - daysGrid.firstDayOffset + 1
                            readonly property bool isValidDay: dayNumber > 0 && dayNumber <= daysGrid.daysInMonth
                            readonly property bool isToday: isValidDay &&
                            dayNumber === daysGrid.todayDate &&
                            calendarBox.currentMonth === daysGrid.todayMonth &&
                            calendarBox.currentYear === daysGrid.todayYear

                            // Highlight System Bubble Container
                            Rectangle {
                                width: parent.width * 0.95
                                height: parent.height * 0.95
                                anchors.centerIn: parent
                                visible: parent.isValidDay

                                // Inherited System Styles
                                radius: shell.theme.defaultCardRadius
                                border.width: shell.theme.globalBorderWidth
                                color: shell.theme.base00
                                border.color: parent.isToday ? shell.theme.base05 : "transparent"
                            }

                            // Day Number Typography Display
                            Text {
                                anchors.centerIn: parent
                                text: parent.isValidDay ? parent.dayNumber : ""
                                color: shell.theme.base05
                                opacity: parent.isValidDay ? 1.0 : 0.0
                                font.family: shell.theme.fontFamily
                                font.pixelSize: shell.theme.globalFontSize
                                font.bold: parent.isToday
                            }
                        }
                    }
                }
            }
        }
    }
}
