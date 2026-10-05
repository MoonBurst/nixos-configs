import QtQuick
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
    property int fontSize: (typeof theme !== 'undefined') ? theme.globalFontSize : 20
    property string sidebarFontFamily: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"

    property color outerBorderColor: (typeof theme !== 'undefined') ? theme.outerBorderColor : "#003399"
    property color innerCardActiveBorder: (typeof theme !== 'undefined') ? theme.innerBorderColor : "#fabd2f"
    property int globalBorderWidth: (typeof theme !== 'undefined' && theme && theme.globalBorderWidth) ? theme.globalBorderWidth : 3
    property color badgeAccentColor: (typeof theme !== 'undefined') ? theme.base03 : "#fabd2f"

    property var folderListModel: []
    property int activeFolderIndex: 0
    property var countsDictionary: ({})

    signal helpRequested()
    signal settingsRequested()

    Column {
        anchors.fill: parent
        anchors.margins: sidebarComp.sidebarPadding
        anchors.rightMargin: sidebarComp.sidebarPadding + 4
        spacing: 10

        Text {
            text: "MAILBOXES"
            font.family: sidebarComp.sidebarFontFamily
            font.pixelSize: sidebarComp.fontSize - 2
            font.bold: true
            color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"
        }

        ListView {
            id: folderListView
            width: parent.width
            height: parent.height - 110
            model: sidebarComp.folderListModel
            spacing: 6
            currentIndex: sidebarComp.activeFolderIndex
            clip: true

            delegate: Item {
                id: folderCard
                width: folderListView.width
                height: sidebarComp.itemHeight

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    slantWidth: 8
                    color: (index === sidebarComp.activeFolderIndex) ? sidebarComp.itemSelectedBg : "transparent"
                    borderColor: (index === sidebarComp.activeFolderIndex) ? sidebarComp.innerCardActiveBorder : sidebarComp.itemBorderColor
                    borderWidth: (index === sidebarComp.activeFolderIndex) ? sidebarComp.globalBorderWidth : 1
                }

                Text {
                    text: modelData.toUpperCase()
                    font.family: sidebarComp.sidebarFontFamily
                    font.pixelSize: sidebarComp.fontSize
                    font.bold: index === sidebarComp.activeFolderIndex
                    color: sidebarComp.folderTextColor
                    anchors.left: parent.left
                    anchors.leftMargin: 15
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 32; height: 24; radius: 12
                    anchors.right: parent.right; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter
                    color: (index === sidebarComp.activeFolderIndex) ? sidebarComp.badgeAccentColor : ((typeof theme !== 'undefined') ? theme.base02 : "#1a1a1a")
                    visible: sidebarComp.countsDictionary && sidebarComp.countsDictionary[modelData] !== undefined && sidebarComp.countsDictionary[modelData] > 0

                    Text {
                        text: (sidebarComp.countsDictionary && sidebarComp.countsDictionary[modelData]) || "0"
                        font.family: sidebarComp.sidebarFontFamily
                        font.pixelSize: sidebarComp.fontSize - 4
                        font.bold: true
                        color: sidebarComp.countTextColor
                        anchors.centerIn: parent
                    }
                }

                MouseArea {
                    anchors.fill: parent
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

    // Lower-Left Quick Actions
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
