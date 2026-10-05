import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Io
import "../style"

Item {
    id: root

    property var tooltip
    property real startY: 100
    property real listWidth: 345
    property var lines: []
    property string slantLeft: "Right"
    property string slantRight: "Right"
    property color textColor: (shell && shell.theme) ? shell.theme.base05 : "yellow"
    property color alertColor: (shell && shell.theme) ? shell.theme.base08 : "#ff0000"
    property color accentColor: (shell && shell.theme) ? shell.theme.base0C : "#04f100"
    property int fontSize: (shell && shell.theme) ? (shell.theme.globalFontSize - 1) : 13

    signal killRequested(string pid)
    signal searchModified(string query)
    signal closeRequested()

    Process {
        id: killProc
        function killPid(pid) {
            if (!pid) return;
            command = ["kill", "-9", pid.toString()];
            running = true;
        }
    }

    Item {
        id: searchContainer
        y: root.startY - 50
        x: root.tooltip.slantX(y) + 20
        width: root.listWidth
        height: 26

        SlantedBox {
            anchors.fill: parent
            slantLeft: root.slantLeft
            slantRight: root.slantRight
            slantWidth: 12
        }

        TextInput {
            id: searchInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: root.textColor
            font.family: "monospace"
            font.pixelSize: root.fontSize
            clip: true
            selectByMouse: true
            focus: true
            activeFocusOnPress: true
            onTextChanged: root.searchModified(text)

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Tab) {
                    searchInput.text = "";
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Escape) {
                    root.closeRequested();
                    event.accepted = true;
                }
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: "Search/Filter processes... [Tab to clear]"
                color: root.textColor
                opacity: 0.4
                font.family: "monospace"
                font.pixelSize: root.fontSize
                visible: searchInput.text === "" && !searchInput.activeFocus
            }
        }
    }

    Repeater {
        model: root.lines.length
        delegate: Item {
            id: processRow
            readonly property string rawLine: (index < root.lines.length) ? root.lines[index] : ""
            readonly property var parts: rawLine.split("|")
            readonly property string pid: parts.length > 1 ? parts[0] : ""
            readonly property bool isRawRam: parts.length > 2 ? (parts[1] === "1") : false
            readonly property string displayText: parts.length > 2 ? (isRawRam ? "⚡ " + parts[2] : parts[2]) : (parts.length > 1 ? parts[1] : rawLine)

            y: root.startY + (index * 28)
            x: root.tooltip.slantX(y) + 20
            width: root.listWidth
            height: 22

            HoverHandler { id: rowHoverTracker }

            SlantedBox {
                anchors.fill: parent
                anchors.topMargin: -2; anchors.bottomMargin: -2
                anchors.leftMargin: -4; anchors.rightMargin: -2
                slantLeft: root.slantLeft; slantRight: root.slantRight
                slantWidth: 12
                visible: rowHoverTracker.hovered
            }

            Text {
                anchors.left: parent.left; anchors.leftMargin: 6
                anchors.right: killBtn.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: processRow.displayText
                font.family: "monospace"
                font.pixelSize: root.fontSize
                color: isRawRam ? root.accentColor : root.textColor
                font.bold: isRawRam
                elide: Text.ElideRight
            }

            Item {
                id: killBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 18
                visible: processRow.pid !== ""

                SlantedBox {
                    anchors.fill: parent
                    slantLeft: root.slantLeft; slantRight: root.slantRight
                    slantWidth: 10
                }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: root.alertColor
                    font.pixelSize: 11
                    font.bold: true
                }

                HoverHandler { id: killBtnHover }
                TapHandler {
                    onTapped: {
                        if (processRow.pid !== "") {
                            killProc.killPid(processRow.pid);
                            root.killRequested(processRow.pid);
                        }
                    }
                }
            }
        }
    }
}
