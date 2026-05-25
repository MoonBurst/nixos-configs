import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland

Rectangle {
    id: calendarBox

    anchors.fill: parent
    radius: shell.theme.defaultCardRadius
    border.width: shell.theme.globalBorderWidth
    color: shell.theme.base00
    border.color: shell.theme.base05

    property var barWindow: null
    property string dateStr: "01/01/2026"

    // Custom Properties for our Pure JavaScript Calendar Logic
    property var currentDate: new Date()
    property int currentMonth: currentDate.getMonth()
    property int currentYear: currentDate.getFullYear()
    property var daysOfWeek: [ "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" ]

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

    Text {
        id: calendarText
        anchors.fill: parent
        anchors.margins: 4
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

        screen: calendarBox.barWindow ? calendarBox.barWindow.screen : null
        visible: calendarHoverTracker.hovered

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-calendar-tooltip"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.left: true
        anchors.right: false
        anchors.bottom: false

        implicitWidth: 300
        implicitHeight: 320
        color: "transparent"

        // ============================================================================
        // POSITIONING CALCULATED FROM THE EXPLICIT CONTAINER
        // ============================================================================
        WlrLayershell.margins.left: {
            if (!calendarBox.barWindow) return 0;
            var containerX = calendarContainer.x;
            var calendarCenterAbsolute = containerX + (calendarContainer.width / 2);
            return Math.round(calendarCenterAbsolute - (implicitWidth / 2));
        }

        WlrLayershell.margins.top: {
            if (!calendarBox.barWindow) return 0;
            return shell.theme.globalPadding + mainBarContainer.capsuleHeight + 8;
        }

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

                // Header Showing Month and Year
                Text {
                    width: parent.width
                    text: calendarBox.currentDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                    color: shell.theme.base05
                    font.family: shell.theme.fontFamily
                    font.pixelSize: shell.theme.globalFontSize + 2
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                // Days of the Week Row (Su, Mo, Tu, We...)
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

                // Pure QML Dynamic Days Grid Matrix Loader
                Grid {
                    id: daysGrid
                    width: parent.width
                    columns: 7
                    spacing: 4

                    // JavaScript Helper Calculations
                    function getDaysInMonth(month, year) {
                        return new Date(year, month + 1, 0).getDate();
                    }

                    function getFirstDayOffset(month, year) {
                        return new Date(year, month, 1).getDay();
                    }

                    Repeater {
                        // Max total possible spaces across a monthly grid block row layout
                        model: 42 

                        delegate: Rectangle {
                            // Layout arithmetic properties
                            property int firstDayOffset: daysGrid.getFirstDayOffset(calendarBox.currentMonth, calendarBox.currentYear)
                            property int daysInMonth: daysGrid.getDaysInMonth(calendarBox.currentMonth, calendarBox.currentYear)
                            property int dayNumber: index - firstDayOffset + 1
                            property bool isValidDay: dayNumber > 0 && dayNumber <= daysInMonth
                            property bool isToday: isValidDay && 
                                                   dayNumber === new Date().getDate() && 
                                                   calendarBox.currentMonth === new Date().getMonth() && 
                                                   calendarBox.currentYear === new Date().getFullYear()

                            width: (parent.width - 24) / 7
                            height: width
                            radius: shell.theme.defaultCardRadius / 2
                            
                            // Highlights today using your text base color profile
                            color: isToday ? shell.theme.base05 : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: parent.isValidDay ? parent.dayNumber : ""
                                font.family: shell.theme.fontFamily
                                font.pixelSize: shell.theme.globalFontSize
                                font.bold: parent.isToday
                                
                                // Inverts text coloration mapping if the background block is active
                                color: parent.isToday ? shell.theme.base00 : shell.theme.base05
                                opacity: parent.isValidDay ? 1.0 : 0.0
                            }
                        }
                    }
                }
            }
        }
    }
}
