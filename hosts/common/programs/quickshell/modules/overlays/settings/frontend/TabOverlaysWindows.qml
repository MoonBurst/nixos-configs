import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15

Flickable {
    id: root
    required property var panelRoot
    required property var guiColorPicker

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    flickableDirection: Flickable.VerticalFlick
    pressDelay: 120
    contentWidth: width
    contentHeight: tab4Layout.implicitHeight + 160
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

    ColumnLayout {
        id: tab4Layout
        width: parent.width - 16
        spacing: panelRoot.livePadding

        NotificationSettingsSection {
            panelRoot: root.panelRoot
            guiColorPicker: root.guiColorPicker
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: root.panelRoot.liveBase03
        }

        WindowSizingSection {
            panelRoot: root.panelRoot
        }
    }
}
