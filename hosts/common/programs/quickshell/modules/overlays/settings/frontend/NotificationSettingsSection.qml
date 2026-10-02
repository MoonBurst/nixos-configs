import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import "../../../settings"

ColumnLayout {
    id: root
    required property var panelRoot
    required property var guiColorPicker

    readonly property var settingsManager: panelRoot.settingsManager
    readonly property var shell: panelRoot.shell

    Layout.fillWidth: true
    spacing: 16

    Text {
        text: "🔔 NOTIFICATIONS, TTS PHRASES & EXCLUSIONS"
        font.pixelSize: panelRoot.liveFontSize + 1
        font.bold: true
        color: panelRoot.liveBase0C
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        CyberToggle {
            Layout.fillWidth: true
            label: "Notifications Enabled"
            checked: settingsManager ? settingsManager.notificationsEnabled : true
            theme: panelRoot.theme
            fontSize: panelRoot.liveFontSize
            onToggled: (st) => { if (settingsManager) settingsManager.notificationsEnabled = st; }
        }
        CyberToggle {
            Layout.fillWidth: true
            label: "Voice TTS Speech"
            checked: settingsManager ? settingsManager.enableTts : true
            theme: panelRoot.theme
            fontSize: panelRoot.liveFontSize
            onToggled: (st) => { if (settingsManager) settingsManager.enableTts = st; }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Text {
            text: "Card Border Color:"
            font.bold: true
            color: panelRoot.liveBase05
            font.pixelSize: panelRoot.liveFontSize - 1
        }
        Rectangle {
            width: 32; height: 32; radius: 6
            color: (settingsManager && settingsManager.notifBorderColor) ? settingsManager.notifBorderColor : panelRoot.liveBase05
            border.width: 2; border.color: "#ffffff"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: guiColorPicker.openPicker("notifBorderColor", parent.color)
            }
        }
        Item { width: 10 }
        Text {
            text: "Default Icon:"
            font.bold: true
            color: panelRoot.liveBase05
            font.pixelSize: panelRoot.liveFontSize - 1
        }
        Rectangle {
            Layout.fillWidth: true
            height: Math.max(34, panelRoot.liveFontSize * 2.0)
            radius: 6
            color: panelRoot.liveBase00
            border.color: panelRoot.liveBase03
            border.width: 1

            TextInput {
                id: customIconInput
                anchors.fill: parent
                anchors.margins: 8
                color: panelRoot.liveBase05
                font.pixelSize: panelRoot.liveFontSize - 2
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                text: settingsManager ? settingsManager.notifCustomIcon : ""
                onTextEdited: if (settingsManager) settingsManager.notifCustomIcon = text
                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Optional fallback icon path / icon name..."
                    color: "#666"
                    visible: parent.text === "" && !parent.activeFocus
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "SageTTS Speech Target Keywords (comma-separated):"
            font.bold: true
            color: panelRoot.liveBase05
            font.pixelSize: panelRoot.liveFontSize - 2
        }
        Rectangle {
            Layout.fillWidth: true
            height: Math.max(36, panelRoot.liveFontSize * 2.2)
            radius: 6
            color: panelRoot.liveBase00
            border.color: panelRoot.liveBase03
            border.width: 1

            TextInput {
                id: ttsKeywordsInput
                anchors.fill: parent
                anchors.margins: 8
                color: panelRoot.liveBase05
                font.pixelSize: panelRoot.liveFontSize - 2
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                text: settingsManager ? settingsManager.ttsKeywordsStr : ""
                onTextEdited: if (settingsManager) settingsManager.ttsKeywordsStr = text
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "Strings & App Names to Exclude from Toasts & History (comma-separated):"
            font.bold: true
            color: panelRoot.liveBase05
            font.pixelSize: panelRoot.liveFontSize - 2
        }
        Rectangle {
            Layout.fillWidth: true
            height: Math.max(36, panelRoot.liveFontSize * 2.2)
            radius: 6
            color: panelRoot.liveBase00
            border.color: panelRoot.liveBase03
            border.width: 1

            TextInput {
                id: excludedStrInput
                anchors.fill: parent
                anchors.margins: 8
                color: panelRoot.liveBase05
                font.pixelSize: panelRoot.liveFontSize - 2
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                text: settingsManager ? settingsManager.notifExcludedStr : ""
                onTextEdited: if (settingsManager) settingsManager.notifExcludedStr = text
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Row {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "Target Screen:"
                color: panelRoot.liveBase05
                font.bold: true
                font.pixelSize: Math.max(12, panelRoot.liveFontSize - 1)
                anchors.verticalCenter: parent.verticalCenter
            }

            Repeater {
                model: {
                    var list = ["Auto"];
                    if (typeof Quickshell !== "undefined" && Quickshell.screens) {
                        for (var i = 0; i < Quickshell.screens.length; i++) {
                            if (Quickshell.screens[i] && Quickshell.screens[i].name) list.push(Quickshell.screens[i].name);
                        }
                    }
                    return list;
                }
                delegate: Rectangle {
                    readonly property bool isSelected: {
                        var cur = settingsManager ? settingsManager.notifScreenName : "";
                        return (modelData === "Auto" && cur === "") || (modelData === cur);
                    }
                    width: scrText.implicitWidth + 24
                    height: Math.max(28, panelRoot.liveFontSize * 1.8)
                    radius: 4
                    color: isSelected ? panelRoot.liveBase05 : panelRoot.liveBase02
                    border.color: panelRoot.liveBase05
                    border.width: 1

                    Text {
                        id: scrText
                        anchors.centerIn: parent
                        text: modelData
                        font.bold: true
                        font.pixelSize: Math.max(11, panelRoot.liveFontSize - 3)
                        color: isSelected ? panelRoot.liveBase00 : panelRoot.liveBase05
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (settingsManager) {
                                settingsManager.notifScreenName = (modelData === "Auto") ? "" : modelData;
                                if (shell && shell.notificationOverlay) shell.notificationOverlay.triggerPreviewNotification();
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            id: toastPreviewBtn
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: toastBtnRow.implicitWidth + 28
            implicitHeight: Math.max(30, panelRoot.liveFontSize * 1.9)
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            radius: 6
            color: testNotifHov.hovered ? panelRoot.liveBase0C : "transparent"
            border.color: panelRoot.liveBase0C
            border.width: 1.5

            Row {
                id: toastBtnRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "🔔"
                    font.pixelSize: Math.max(12, panelRoot.liveFontSize - 2)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "3-Toast Preview"
                    font.bold: true
                    font.pixelSize: Math.max(11, panelRoot.liveFontSize - 3)
                    color: testNotifHov.hovered ? panelRoot.liveBase00 : panelRoot.liveBase0C
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            HoverHandler { id: testNotifHov }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (shell && shell.notificationOverlay) shell.notificationOverlay.triggerPreviewNotification()
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        CyberSlider {
            label: "Toast Stacking Baseline Y"; from: 50; to: 900; stepSize: 10; unit: "px"
            value: settingsManager ? settingsManager.notifBaselineY : 350
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme; Layout.fillWidth: true
            onValueModified: (v) => { if (settingsManager) settingsManager.notifBaselineY = Math.round(v); }
        }
        CyberSlider {
            label: "Card Stacking Overlap"; from: 0; to: 60; stepSize: 5; unit: "px"
            value: settingsManager ? settingsManager.notifStackOverlap : 25
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme; Layout.fillWidth: true
            onValueModified: (v) => { if (settingsManager) settingsManager.notifStackOverlap = Math.round(v); }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        CyberSlider {
            label: "Toast Display Duration"; from: 1; to: 20; stepSize: 1; unit: "s"
            value: settingsManager ? settingsManager.notifHoldDurationSec : 5
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme; Layout.fillWidth: true
            onValueModified: (v) => { if (settingsManager) settingsManager.notifHoldDurationSec = Math.round(v); }
        }
        CyberSlider {
            label: "Screen Margin (Right X)"; from: 0; to: 80; stepSize: 4; unit: "px"
            value: settingsManager ? settingsManager.notifMarginX : 20
            fontSize: panelRoot.liveFontSize
            theme: panelRoot.theme; Layout.fillWidth: true
            onValueModified: (v) => { if (settingsManager) settingsManager.notifMarginX = Math.round(v); }
        }
    }
}
