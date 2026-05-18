import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

Item {
    id: root

    required property Notification notif
    property string assetDir: "/home/moonburst/nix/hosts/common/programs/quickshell"

    // Force strict layout boundaries to prevent polish loops
    implicitWidth: 240
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: 0

        Image {
            id: trumpetTop
            Layout.fillWidth: true
            // Setting fillMode preserves the retro aspect ratio cleanly without breaking layouts
            fillMode: Image.PreserveAspectFit
            source: root.assetDir + "/trumpet-top.png"
            smooth: false
        }

        Rectangle {
            id: bannerRect

            color: "#3B253F"
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            // Fixed margin widths to prevent layout recalculation traps
            Layout.leftMargin: 5
            Layout.rightMargin: 5

            ColumnLayout {
                id: textColumn
                anchors.fill: parent
                anchors.margins: 8

                Text {
                    Layout.fillWidth: true
                    text: root.notif.summary + (root.notif.body ? "\n=======" : "")
                    font.family: "BigBlueTermPlusNerdFont"
                    wrapMode: Text.Wrap
                    font.pointSize: 18
                    font.bold: true
                    color: "#9292B6"
                }

                Text {
                    Layout.fillWidth: true
                    text: root.notif.body
                    font.family: "BigBlueTermPlusNerdFont"
                    wrapMode: Text.Wrap
                    font.pointSize: 14
                    font.bold: false
                    color: "#9292B6"
                }
            }
        }
    }
}
