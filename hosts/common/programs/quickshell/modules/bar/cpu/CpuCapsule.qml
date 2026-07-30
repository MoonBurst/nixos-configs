// CpuCapsule.qml
import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../style"

Item {
    id: cpuBox
    property var barWindow: null
    property bool pinTooltip: false
    property string searchQuery: ""

    // Theme Fallbacks
    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property color themeBase00: (shell && shell.theme && typeof shell.theme.base00 !== "undefined") ? shell.theme.base00 : "black"
    readonly property color themeBase02: (shell && shell.theme && typeof shell.theme.base02 !== "undefined") ? shell.theme.base02 : "#222222"
    readonly property color themeBase05: (shell && shell.theme && typeof shell.theme.base05 !== "undefined") ? shell.theme.base05 : "yellow"
    readonly property color themeBase08: (shell && shell.theme && typeof shell.theme.base08 !== "undefined") ? shell.theme.base08 : "red"
    readonly property color themeBase0C: (shell && shell.theme && typeof shell.theme.base0C !== "undefined") ? shell.theme.base0C : "green"
    // =========================================================================

    // =========================================================================
    // EDITABLE TOOLTIP CONFIGURATION
    // =========================================================================
    property int tooltipHeight: 420          // Vertical height of the expanded box
    property int tooltipCollapsedWidth: 134  // Sleek, thin width during the downward unroll
    property int tooltipExpandedWidth: 440   // Final horizontal width once fully open
    property int tooltipTopOffset: -2        // Micro-adjust vertical spacing (px)
    property int tooltipRightOffset: 21      // Micro-adjust horizontal alignment (px)
    // =========================================================================

    // Slant configurations
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: cpuBox.themeSlantWidth

    property string cpuUsageStr: "0%"
    property string cpuTempStr: "0°C"
    property string topProcessesText: "Loading CPU processes..."
    property string textAccumulatorBuffer: ""
    readonly property var processLinesArray: topProcessesText.split("\n").filter(line => line.trim() !== "")

    // Live Filtered Process List
    readonly property var filteredProcessLinesArray: {
        var lines = processLinesArray;
        if (searchQuery.trim() === "") return lines;
        var q = searchQuery.trim().toLowerCase();
        return lines.filter(function(line) {
            return line.toLowerCase().indexOf(q) !== -1;
        });
    }

    width: 175
    Layout.preferredWidth: 175
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: cpuBox.slantLeft
        slantRight: cpuBox.slantRight
        slantWidth: cpuBox.slantWidth
    }

    // Metric Data Collector
    Process {
        id: cpuStatsProc
        running: true
        command: ["sh", "-c", "usage=$(awk '/cpu / {print int(($2+$4)*100/($2+$4+$5))}' /proc/stat); temp=$(cat /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null | head -n 1 || echo '0'); if [ \"$temp\" -gt 0 ]; then temp=$(echo \"scale=0; $temp/1000\" | bc); fi; echo \"$usage%:${temp}°C\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length === 2) {
                    cpuBox.cpuUsageStr = parts[0];
                    cpuBox.cpuTempStr = parts[1];
                }
            }
        }
    }

    // Client Process Scanner (Normalized to total CPU capacity)
    Process {
        id: topProcFetcher
        running: false
        command: ["sh", "-c", "ncpu=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1); ps -eo pid,comm,%cpu --sort=-%cpu | head -n 11 | awk -v ncpu=\"$ncpu\" 'NR>1 { cpu_tot = $3 / ncpu; printf \"%s|%-10s %4.1f%%\\n\", $1, substr($2,1,10), cpu_tot }'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data && data.trim() !== "") cpuBox.textAccumulatorBuffer += data + "\n"; }
        }
        onExited: {
            if (cpuBox.textAccumulatorBuffer.trim() !== "") {
                cpuBox.topProcessesText = cpuBox.textAccumulatorBuffer.trim();
            }
        }
    }

    // Process Killer Helper
    Process {
        id: killProc
        function killPid(pid) {
            if (!pid) return;
            command = ["kill", "-9", pid.toString()];
            running = true;
        }
    }

    // Delayed refresh after killing a process
    Timer {
        id: killRefreshTimer
        interval: 300
        repeat: false
        onTriggered: {
            cpuBox.textAccumulatorBuffer = "";
            topProcFetcher.running = false;
            topProcFetcher.running = true;
        }
    }

    // Main Canvas Display Text
    Text {
        id: cpuText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding
        anchors.rightMargin: bg.rightPadding
        anchors.topMargin: themePadding
        anchors.bottomMargin: themePadding

        textFormat: Text.RichText
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        elide: Text.ElideRight

        text: {
            const greenColor = themeBase0C.toString();
            const yellowColor = themeBase05.toString();
            return "<font color='" + greenColor + "'>CPU:</font> " +
            "<font color='" + yellowColor + "'>" + cpuBox.cpuUsageStr + " " + cpuBox.cpuTempStr + "</font>";
        }
    }

    HoverHandler {
        id: cpuHoverTracker
        onHoveredChanged: {
            if (hovered && !cpuTooltip.isHovered && !searchInput.activeFocus) {
                cpuBox.textAccumulatorBuffer = "";
                topProcFetcher.running = false;
                topProcFetcher.running = true;
            }
        }
    }

    // Click capsule to pin/unpin tooltip open
    TapHandler {
        onTapped: {
            cpuBox.pinTooltip = !cpuBox.pinTooltip;
            if (cpuBox.pinTooltip && !searchInput.activeFocus) {
                cpuBox.textAccumulatorBuffer = "";
                topProcFetcher.running = false;
                topProcFetcher.running = true;
            }
        }
    }

    // Tooltip Window
    SlantedTooltip {
        id: cpuTooltip
        moduleItem: cpuBox
        barWindow: cpuBox.barWindow
        tooltipActive: cpuHoverTracker.hovered
        pin: cpuBox.pinTooltip

        // Request keyboard input from Wayland compositor when search is focused/active
        WlrLayershell.keyboardFocus: (cpuBox.pinTooltip || searchInput.activeFocus) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        readonly property bool isHovered: tooltipHoverTracker.hovered

        tooltipHeight: cpuBox.tooltipHeight
        collapsedCoreWidth: cpuBox.tooltipCollapsedWidth
        expandedCoreWidth: cpuBox.tooltipExpandedWidth
        topOffset: cpuBox.tooltipTopOffset
        rightOffset: cpuBox.tooltipRightOffset

        slantLeft: cpuBox.slantLeft
        slantRight: cpuBox.slantRight

        Item {
            anchors.fill: parent
            HoverHandler {
                id: tooltipHoverTracker
            }
        }

        Text {
            text: "ACTIVE CPU CLIENTS:"
            font.family: themeFontFamily
            font.pixelSize: themeFontSize - 1
            font.bold: true
            color: themeBase05
            y: 24
            x: cpuTooltip.slantX(y) + 20
        }

        // Full-width Slanted Search/Filter Field
        Item {
            id: searchContainer
            y: 50
            x: cpuTooltip.slantX(y) + 20
            width: 345
            height: 26

            SlantedBox {
                anchors.fill: parent
                slantLeft: cpuBox.slantLeft
                slantRight: cpuBox.slantRight
                slantWidth: 12
            }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: cpuBox.themeBase05
                font.family: "monospace"
                font.pixelSize: cpuBox.themeFontSize - 1
                clip: true
                selectByMouse: true
                focus: true
                activeFocusOnPress: true

                onTextChanged: cpuBox.searchQuery = text

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search/Filter processes..."
                    color: cpuBox.themeBase05
                    opacity: 0.4
                    font.family: "monospace"
                    font.pixelSize: cpuBox.themeFontSize - 1
                    visible: searchInput.text === "" && !searchInput.activeFocus
                }
            }
        }

        Rectangle {
            height: 2
            color: themeBase02
            width: 345
            y: 86
            x: cpuTooltip.slantX(y) + 20
        }

        Repeater {
            model: cpuBox.filteredProcessLinesArray.length
            delegate: Item {
                id: processRow
                readonly property string rawLine: cpuBox.filteredProcessLinesArray[index]
                readonly property var parts: rawLine.split("|")
                readonly property string pid: parts.length > 1 ? parts[0] : ""
                readonly property string displayText: parts.length > 1 ? parts[1] : rawLine

                y: 102 + (index * 28)
                x: cpuTooltip.slantX(y) + 20
                width: 345
                height: 22

                HoverHandler {
                    id: rowHoverTracker
                }

                // Slanted Hover Box around entire process row
                SlantedBox {
                    anchors.fill: parent
                    anchors.topMargin: -2
                    anchors.bottomMargin: -2
                    anchors.leftMargin: -4
                    anchors.rightMargin: -2
                    slantLeft: cpuBox.slantLeft
                    slantRight: cpuBox.slantRight
                    slantWidth: 12
                    visible: rowHoverTracker.hovered
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.right: killBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: processRow.displayText
                    font.family: "monospace"
                    font.pixelSize: cpuBox.themeFontSize - 1
                    color: cpuBox.themeBase05
                    elide: Text.ElideRight
                }

                // Slanted Kill Process Button
                Item {
                    id: killBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 50
                    height: 18
                    visible: processRow.pid !== ""

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: cpuBox.slantLeft
                        slantRight: cpuBox.slantRight
                        slantWidth: 12
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: killBtnHover.hovered ? cpuBox.themeBase08 : cpuBox.themeBase08
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler {
                        id: killBtnHover
                    }

                    TapHandler {
                        onTapped: {
                            if (processRow.pid !== "") {
                                killProc.killPid(processRow.pid);
                                killRefreshTimer.start();
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            cpuStatsProc.running = false;
            cpuStatsProc.running = true;
            if ((cpuHoverTracker.hovered || cpuBox.pinTooltip) && !cpuTooltip.isHovered && !searchInput.activeFocus) {
                cpuBox.textAccumulatorBuffer = "";
                topProcFetcher.running = false;
                topProcFetcher.running = true;
            }
        }
    }
}
