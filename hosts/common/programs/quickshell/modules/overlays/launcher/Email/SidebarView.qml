import QtQuick

Rectangle {
    id: sidebarComp

    // ============================================================================
    // SAFE VARIABLE CHECKS AGAINST THE CENTRAL THEME OBJECT
    // ============================================================================
    property color sidebarBgColor: (typeof theme !== 'undefined') ? theme.base00 : "#121212"
    property color itemSelectedBg: (typeof theme !== 'undefined') ? theme.base00 : "#121212"
    property color itemBorderColor: (typeof theme !== 'undefined') ? theme.base01 : "#0f0f0f"
    property color folderTextColor: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"
    property color countTextColor: (typeof theme !== 'undefined') ? theme.base05 : "#ebdbb2"
    property int sidebarPadding: (typeof theme !== 'undefined') ? theme.globalPadding : 20
    property int itemHeight: (typeof theme !== 'undefined' ? theme.defaultCardHeight : 140) - 70
    property int fontSize: (typeof theme !== 'undefined') ? theme.globalFontSize : 20
    property string sidebarFontFamily: (typeof theme !== 'undefined') ? theme.fontFamily : "Fira Sans"

    // Custom Border Configuration Bindings
    property color outerBorderColor: (typeof theme !== 'undefined') ? theme.outerBorderColor : "#003399"
    property int outerBorderThickness: (typeof theme !== 'undefined') ? theme.globalBorderWidth : 3
    property color innerCardActiveBorder: (typeof theme !== 'undefined') ? theme.innerBorderColor : "#fabd2f"
    property int innerCardActiveThickness: 5
    property color badgeAccentColor: (typeof theme !== 'undefined') ? theme.base03 : "#fabd2f"

    property var folderListModel: []
    property int activeFolderIndex: 0
    property var countsDictionary: ({})

    signal helpRequested()

    color: sidebarBgColor
    border.color: outerBorderColor
    border.width: outerBorderThickness
    radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10

    Column {
        anchors.fill: parent; anchors.margins: sidebarComp.sidebarPadding; spacing: 10

        Text {
            text: "MAILBOXES"; font.family: sidebarComp.sidebarFontFamily; font.pixelSize: sidebarComp.fontSize - 2
            font.bold: true; color: (typeof theme !== 'undefined') ? theme.base05 : "#f7f700"
        }

        ListView {
            id: folderListView; width: parent.width; height: parent.height - 120; model: sidebarComp.folderListModel
            spacing: 6; currentIndex: sidebarComp.activeFolderIndex; clip: true

            delegate: Rectangle {
                id: folderCard; width: folderListView.width; height: sidebarComp.itemHeight; radius: (typeof theme !== 'undefined') ? theme.defaultCardRadius : 10
                color: (index === sidebarComp.activeFolderIndex) ? sidebarComp.itemSelectedBg : "transparent"
                border.color: (index === sidebarComp.activeFolderIndex) ? sidebarComp.innerCardActiveBorder : sidebarComp.itemBorderColor
                border.width: (index === sidebarComp.activeFolderIndex) ? sidebarComp.innerCardActiveThickness : 1

                Text {
                    text: modelData.toUpperCase(); font.family: sidebarComp.sidebarFontFamily; font.pixelSize: sidebarComp.fontSize
                    font.bold: index === sidebarComp.activeFolderIndex; color: sidebarComp.folderTextColor
                    anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 32; height: 24; radius: 12; anchors.right: parent.right; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter
                    color: (index === sidebarComp.activeFolderIndex) ? sidebarComp.badgeAccentColor : ((typeof theme !== 'undefined') ? theme.base02 : "#1a1a1a")
                    visible: sidebarComp.countsDictionary && sidebarComp.countsDictionary[modelData] !== undefined && sidebarComp.countsDictionary[modelData] > 0

                    Text {
                        text: (sidebarComp.countsDictionary && sidebarComp.countsDictionary[modelData]) || "0"
                        font.family: sidebarComp.sidebarFontFamily; font.pixelSize: sidebarComp.fontSize - 4; font.bold: true; color: sidebarComp.countTextColor; anchors.centerIn: parent
                    }
                }
            }
        }
    }

    // ============================================================================
    // DYNAMIC LOWER-LEFT HELP BUTTON
    // ============================================================================
    Rectangle {
        id: helpButton; width: 34; height: 34; radius: 17; color: sidebarComp.sidebarBgColor
        border.color: mouseArea.containsMouse ? sidebarComp.innerCardActiveBorder : sidebarComp.itemBorderColor; border.width: mouseArea.containsMouse ? 2 : 1
        anchors.left: parent.left; anchors.leftMargin: sidebarComp.sidebarPadding; anchors.bottom: parent.bottom; anchors.bottomMargin: sidebarComp.sidebarPadding

        Text { text: "?"; font.family: sidebarComp.sidebarFontFamily; font.pixelSize: sidebarComp.fontSize; font.bold: true; color: mouseArea.containsMouse ? sidebarComp.folderTextColor : sidebarComp.countTextColor; anchors.centerIn: parent }
        MouseArea { id: mouseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sidebarComp.helpRequested() }
    }
}
