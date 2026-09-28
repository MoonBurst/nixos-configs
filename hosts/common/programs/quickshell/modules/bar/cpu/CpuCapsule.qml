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
    property string moduleName: "cpu"
    property bool pinTooltip: false
    property string searchQuery: ""

    readonly property int themePadding: (shell && shell.theme && typeof shell.theme.globalPadding !== "undefined") ? shell.theme.globalPadding : 12
    readonly property int themeFontSize: (shell && shell.theme && typeof shell.theme.globalFontSize !== "undefined") ? shell.theme.globalFontSize : 14
    readonly property string themeFontFamily: (shell && shell.theme && typeof shell.theme.fontFamily !== "undefined") ? shell.theme.fontFamily : "monospace"
    readonly property int themeSlantWidth: (shell && shell.theme && typeof shell.theme.slantWidth !== "undefined") ? shell.theme.slantWidth : 12
    readonly property color themeBase00: (shell && shell.theme && typeof shell.theme.base00 !== "undefined") ? shell.theme.base00 : "black"
    readonly property color themeBase02: (shell && shell.theme && typeof shell.theme.base02 !== "undefined") ? shell.theme.base02 : "#222222"
    readonly property color themeBase05: (shell && shell.theme && typeof shell.theme.base05 !== "undefined") ? shell.theme.base05 : "yellow"
    readonly property color themeBase08: (shell && shell.theme && typeof shell.theme.base08 !== "undefined") ? shell.theme.base08 : "red"
    readonly property color themeBase0C: (shell && shell.theme && typeof shell.theme.base0C !== "undefined") ? shell.theme.base0C : "#04f100"

    property int tooltipHeight: 460
    property int tooltipCollapsedWidth: 150
    property int tooltipExpandedWidth: 520
    property int tooltipTopOffset: -2
    property int tooltipRightOffset: 0

    property string slantLeft: "Right"
    property string slantRight: "Right"
    property int slantWidth: cpuBox.themeSlantWidth

    property string cpuUsageStr: "0%"
    property string cpuTempStr: "0°C"
    property string topProcessesText: "Loading CPU processes..."
    property string textAccumulatorBuffer: ""
    readonly property var processLinesArray: topProcessesText.split("\n").filter(line => line.trim() !== "")

    readonly property var filteredProcessLinesArray: {
        var lines = processLinesArray;
        if (searchQuery.trim() === "") return lines;
        var q = searchQuery.trim().toLowerCase();
        return lines.filter(function(line) { return line.toLowerCase().indexOf(q) !== -1; });
    }

    implicitWidth: cpuText.implicitWidth + bg.leftPadding + bg.rightPadding + 20
    width: implicitWidth
    height: parent ? parent.height : 40

    SlantedBox {
        id: bg
        anchors.fill: parent
        slantLeft: cpuBox.slantLeft
        slantRight: cpuBox.slantRight
        slantWidth: cpuBox.slantWidth
    }

    Process {
        id: cpuStatsProc
        running: true
        command: [
            "sh", "-c",
            "s1=$(awk '/^cpu / {print $2+$3+$4, $2+$3+$4+$5+$6+$7+$8}' /proc/stat); " +
            "sleep 0.4; " +
            "s2=$(awk '/^cpu / {print $2+$3+$4, $2+$3+$4+$5+$6+$7+$8}' /proc/stat); " +
            "temp=$(awk '{print int($1/1000); exit}' /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null || echo 0); " +
            "echo \"$s1 $s2 $temp\" | awk '{b=$3-$1; t=$4-$2; pct=(t>0)?int((b*100)/t):0; printf \"%d%%:%d°C\\n\", pct, $5}'"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var raw = (data || "").trim();
                var parts = raw.split(":");
                if (parts.length === 2) {
                    cpuBox.cpuUsageStr = parts[0];
                    cpuBox.cpuTempStr = parts[1];
                }
            }
        }
    }

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

    Process {
        id: killProc
        function killPid(pid) {
            if (!pid) return;
            command = ["kill", "-9", pid.toString()];
            running = true;
        }
    }

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

    Text {
        id: cpuText
        anchors.fill: parent
        anchors.leftMargin: bg.leftPadding + 4
        anchors.rightMargin: bg.rightPadding + 4
        anchors.topMargin: 2
        anchors.bottomMargin: 2

        textFormat: Text.RichText
        font.family: themeFontFamily
        font.pixelSize: themeFontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        clip: true

        text: "<font color='" + themeBase0C.toString() + "'>CPU:</font> " +
              "<font color='" + themeBase05.toString() + "'>" + cpuBox.cpuUsageStr + " " + cpuBox.cpuTempStr + "</font>"
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

    SlantedTooltip {
        id: cpuTooltip
        moduleItem: cpuBox
        barWindow: cpuBox.barWindow
        tooltipActive: cpuHoverTracker.hovered
        pin: cpuBox.pinTooltip

        keyboardFocus: (cpuBox.pinTooltip || searchInput.activeFocus) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
            HoverHandler { id: tooltipHoverTracker }
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

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        if (searchInput.text !== "") {
                            searchInput.text = "";
                        } else {
                            cpuBox.pinTooltip = false;
                        }
                        event.accepted = true;
                    }
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search/Filter processes... [Esc to close]"
                    color: cpuBox.themeBase05
                    opacity: 0.4
                    font.family: "monospace"
                    font.pixelSize: cpuBox.themeFontSize - 1
                    visible: searchInput.text === "" && !searchInput.activeFocus
                }
            }
        }

        Repeater {
            model: cpuBox.filteredProcessLinesArray.length
            delegate: Item {
                id: processRow
                readonly property string rawLine: (index < cpuBox.filteredProcessLinesArray.length) ? cpuBox.filteredProcessLinesArray[index] : ""
                readonly property var parts: rawLine.split("|")
                readonly property string pid: parts.length > 1 ? parts[0] : ""
                readonly property string displayText: parts.length > 1 ? parts[1] : rawLine

                y: 102 + (index * 28)
                x: cpuTooltip.slantX(y) + 20
                width: 345
                height: 22

                HoverHandler { id: rowHoverTracker }

                SlantedBox {
                    anchors.fill: parent
                    anchors.topMargin: -2; anchors.bottomMargin: -2
                    anchors.leftMargin: -4; anchors.rightMargin: -2
                    slantLeft: cpuBox.slantLeft; slantRight: cpuBox.slantRight
                    slantWidth: 12
                    visible: rowHoverTracker.hovered
                }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 6
                    anchors.right: killBtn.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: processRow.displayText
                    font.family: "monospace"
                    font.pixelSize: cpuBox.themeFontSize - 1
                    color: cpuBox.themeBase05
                    elide: Text.ElideRight
                }

                Item {
                    id: killBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 50
                    height: 18
                    visible: processRow.pid !== ""

                    SlantedBox {
                        anchors.fill: parent
                        slantLeft: cpuBox.slantLeft; slantRight: cpuBox.slantRight
                        slantWidth: 12
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: cpuBox.themeBase08
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: killBtnHover }
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
        interval: (shell && shell.settingsManager && shell.settingsManager.hardwarePollInterval > 0) ? shell.settingsManager.hardwarePollInterval : 2000; running: true; repeat: true; triggeredOnStart: true
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
