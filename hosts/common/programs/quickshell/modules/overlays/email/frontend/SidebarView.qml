import QtQuick
import QtQuick.Layouts 1.15
import "../../../style" as Style

Item {
    id: sidebarComp

    property color sidebarBgColor: (typeof theme !== 'undefined') ? theme.base00 : "#121212"
    property color itemSelectedBg: (typeof theme !== 'undefined') ? theme.base00 : "#121212"
    property color itemBorderColor: (typeof theme !== 'undefined') ? theme.base01 : "#0f0f0f"
    property color folderTextColor: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"
    property color countTextColor: (typeof theme !== 'undefined') ? theme.base05 : "#ebdbb2"
    property int sidebarPadding: (typeof theme !== 'undefined') ? theme.globalPadding : 16
    property int itemHeight: (typeof theme !== 'undefined' ? theme.defaultCardHeight : 140) - 70
    property int fontSize: (typeof theme !== 'undefined') ? theme.globalFontSize : 18
    property string sidebarFontFamily: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"

    property color outerBorderColor: (typeof theme !== 'undefined') ? theme.outerBorderColor : "#003399"
    property color innerCardActiveBorder: (typeof theme !== 'undefined') ? theme.innerBorderColor : "#fabd2f"
    property int globalBorderWidth: (typeof theme !== 'undefined' && theme && theme.globalBorderWidth) ? theme.globalBorderWidth : 3
    property color badgeAccentColor: (typeof theme !== 'undefined') ? theme.base03 : "#fabd2f"
    property int controlBorderWidth: (typeof theme !== 'undefined' && theme && theme.controlBorderWidth !== undefined) ? theme.controlBorderWidth : 2

    property var folderListModel: []
    property int activeFolderIndex: 0
    property var countsDictionary: ({})
    property var systemFolders: ["inbox", "starred", "all", "sent", "drafts", "trash", "spam"]

    property bool isAddingFolder: false

    signal helpRequested()
    signal settingsRequested()
    signal addFolderRequested(string folderName)
    signal removeFolderRequested(string folderName)

    Column {
        anchors.fill: parent
        anchors.margins: sidebarComp.sidebarPadding
        anchors.rightMargin: sidebarComp.sidebarPadding + 4
        spacing: 10

        // Header with Add Box button
        RowLayout {
            width: parent.width
            height: 28

            Text {
                text: "MAILBOXES"
                font.family: sidebarComp.sidebarFontFamily
                font.pixelSize: sidebarComp.fontSize - 2
                font.bold: true
                color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"
                Layout.fillWidth: true
            }

            Rectangle {
                width: addBtnRow.implicitWidth + 14
                height: 24
                radius: 4
                color: addHov.hovered ? ((typeof theme !== 'undefined') ? theme.base0C : "#04f100") : "transparent"
                border.color: (typeof theme !== 'undefined') ? theme.base0C : "#04f100"
                border.width: 1

                Row {
                    id: addBtnRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "+"; font.bold: true; font.pixelSize: 12; color: addHov.hovered ? "#000" : ((typeof theme !== 'undefined') ? theme.base0C : "#04f100") }
                    Text { text: "Add"; font.bold: true; font.pixelSize: 10; color: addHov.hovered ? "#000" : ((typeof theme !== 'undefined') ? theme.base0C : "#04f100") }
                }

                HoverHandler { id: addHov }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sidebarComp.isAddingFolder = !sidebarComp.isAddingFolder;
                        if (sidebarComp.isAddingFolder) {
                            newFolderInput.text = "";
                            Qt.callLater(() => newFolderInput.forceActiveFocus());
                        }
                    }
                }
            }
        }

        // Taller input container with 48px height so text and descenders never clip
        Item {
            width: parent.width
            height: sidebarComp.isAddingFolder ? Math.max(48, Math.round(sidebarComp.fontSize * 2.4)) : 0
            visible: sidebarComp.isAddingFolder
            clip: true

            Style.ShapeBox {
                anchors.fill: parent
                role: "input"
                slantWidth: 8
                color: sidebarComp.sidebarBgColor
                borderColor: newFolderInput.activeFocus ? sidebarComp.innerCardActiveBorder : sidebarComp.itemBorderColor
                borderWidth: sidebarComp.controlBorderWidth
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                spacing: 8

                TextInput {
                    id: newFolderInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    font.family: sidebarComp.sidebarFontFamily
                    font.pixelSize: Math.max(13, sidebarComp.fontSize - 1)
                    color: sidebarComp.folderTextColor
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    clip: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Keyword / sender / domain..."
                        color: "#777"
                        visible: parent.text === "" && !parent.activeFocus
                        font.pixelSize: Math.max(13, sidebarComp.fontSize - 1)
                        font.family: sidebarComp.sidebarFontFamily
                        elide: Text.ElideRight
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            var clean = text.trim();
                            if (clean !== "") {
                                sidebarComp.addFolderRequested(clean);
                            }
                            sidebarComp.isAddingFolder = false;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            sidebarComp.isAddingFolder = false;
                            event.accepted = true;
                        }
                    }
                }

                Rectangle {
                    width: 26; height: 26; radius: 4
                    color: submitHov.hovered ? ((typeof theme !== 'undefined') ? theme.base0C : "#04f100") : "transparent"
                    border.color: (typeof theme !== 'undefined') ? theme.base0C : "#04f100"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        font.bold: true
                        font.pixelSize: 13
                        color: submitHov.hovered ? "#000" : ((typeof theme !== 'undefined') ? theme.base0C : "#04f100")
                    }

                    HoverHandler { id: submitHov }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (newFolderInput.text.trim() !== "") {
                                sidebarComp.addFolderRequested(newFolderInput.text.trim());
                            }
                            sidebarComp.isAddingFolder = false;
                        }
                    }
                }
            }
        }

        ListView {
            id: folderListView
            width: parent.width
            height: parent.height - (sidebarComp.isAddingFolder ? 160 : 110)
            model: sidebarComp.folderListModel
            spacing: 6
            currentIndex: sidebarComp.activeFolderIndex
            clip: true

            delegate: Item {
                id: folderCard
                width: folderListView.width
                height: sidebarComp.itemHeight

                readonly property bool isCustom: !sidebarComp.systemFolders.includes(modelData.toLowerCase())

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    slantWidth: 8
                    color: (index === sidebarComp.activeFolderIndex) ? sidebarComp.itemSelectedBg : "transparent"
                    borderColor: (index === sidebarComp.activeFolderIndex) ? sidebarComp.innerCardActiveBorder : sidebarComp.itemBorderColor
                    borderWidth: controlBorderWidth
                }

                Text {
                    text: modelData.toUpperCase()
                    font.family: sidebarComp.sidebarFontFamily
                    font.pixelSize: sidebarComp.fontSize - 1
                    font.bold: index === sidebarComp.activeFolderIndex
                    color: sidebarComp.folderTextColor
                    anchors.left: parent.left
                    anchors.leftMargin: 15
                    anchors.right: badgeRow.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                }

                Row {
                    id: badgeRow
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        width: 32; height: 22; radius: 11
                        color: (index === sidebarComp.activeFolderIndex) ? sidebarComp.badgeAccentColor : ((typeof theme !== 'undefined') ? theme.base02 : "#1a1a1a")
                        visible: sidebarComp.countsDictionary && sidebarComp.countsDictionary[modelData] !== undefined && sidebarComp.countsDictionary[modelData] > 0
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: (sidebarComp.countsDictionary && sidebarComp.countsDictionary[modelData]) || "0"
                            font.family: sidebarComp.sidebarFontFamily
                            font.pixelSize: sidebarComp.fontSize - 4
                            font.bold: true
                            color: sidebarComp.countTextColor
                            anchors.centerIn: parent
                        }
                    }

                    // Delete button for custom smart mailboxes
                    Text {
                        visible: folderCard.isCustom
                        text: "✕"
                        font.bold: true
                        font.pixelSize: 12
                        color: delHov.hovered ? "#ff5555" : "#777"
                        anchors.verticalCenter: parent.verticalCenter

                        HoverHandler { id: delHov }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sidebarComp.removeFolderRequested(modelData)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: folderCard.isCustom ? 26 : 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sidebarComp.activeFolderIndex = index;
                        if (typeof viewRoot !== "undefined" && viewRoot.engine) {
                            viewRoot.engine.currentFolderIndex = index;
                            viewRoot.engine.filterEmailsByActiveFolder();
                        }
                    }
                }
            }
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: sidebarComp.sidebarPadding
        anchors.bottom: parent.bottom
        anchors.bottomMargin: sidebarComp.sidebarPadding
        spacing: 10

        Item {
            id: helpButton
            width: 34; height: 34

            Style.ShapeBox {
                anchors.fill: parent
                role: "input"
                slantWidth: 6
                color: sidebarComp.sidebarBgColor
                borderColor: helpMouse.containsMouse ? sidebarComp.innerCardActiveBorder : sidebarComp.itemBorderColor
                borderWidth: helpMouse.containsMouse ? sidebarComp.globalBorderWidth : 1
            }

            Text {
                text: "?"
                font.family: sidebarComp.sidebarFontFamily
                font.pixelSize: sidebarComp.fontSize
                font.bold: true
                color: helpMouse.containsMouse ? sidebarComp.folderTextColor : sidebarComp.countTextColor
                anchors.centerIn: parent
            }
            MouseArea {
                id: helpMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sidebarComp.helpRequested()
            }
        }

        Item {
            id: settingsButton
            width: 34; height: 34

            Style.ShapeBox {
                anchors.fill: parent
                role: "input"
                slantWidth: 6
                color: sidebarComp.sidebarBgColor
                borderColor: setMouse.containsMouse ? sidebarComp.innerCardActiveBorder : sidebarComp.itemBorderColor
                borderWidth: setMouse.containsMouse ? sidebarComp.globalBorderWidth : 1
            }

            Text {
                text: "⚙"
                font.pixelSize: sidebarComp.fontSize - 4
                anchors.centerIn: parent
            }
            MouseArea {
                id: setMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sidebarComp.settingsRequested()
            }
        }
    }
}
