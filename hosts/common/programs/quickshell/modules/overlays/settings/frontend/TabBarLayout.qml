import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../../../style"
import "../../../settings"

Flickable {
    id: root
    required property var panelRoot

    readonly property var settingsManager: panelRoot.settingsManager
    readonly property var theme: panelRoot.theme

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    flickableDirection: Flickable.VerticalFlick
    pressDelay: 120
    contentWidth: width
    contentHeight: tab3Layout.implicitHeight + 160
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 8 }

    ColumnLayout {
        id: tab3Layout
        width: parent.width - 16
        spacing: 16

        Text {
            text: "📊 REORDER CAPSULES & SLANT MODES"
            font.pixelSize: panelRoot.liveFontSize + 1
            font.bold: true
            color: panelRoot.liveBase05
        }

        // Global Slant Selector
        Row {
            spacing: 10
            Layout.fillWidth: true

            Text {
                text: "Global Slants:"
                font.bold: true
                color: panelRoot.liveBase05
                font.pixelSize: panelRoot.liveFontSize - 1
                anchors.verticalCenter: parent.verticalCenter
            }

            Repeater {
                model: [
                    { id: "symmetric", label: "Symmetric (\\ /)" },
                    { id: "all-left", label: "All Left (\\ \\)" },
                    { id: "all-right", label: "All Right (/ /)" }
                ]
                delegate: Rectangle {
                    readonly property bool isSelected: settingsManager && settingsManager.slantStyleMode === modelData.id
                    width: modeTxt.implicitWidth + 24
                    height: Math.max(28, panelRoot.liveFontSize * 1.8)
                    radius: 6
                    color: isSelected ? panelRoot.liveBase05 : panelRoot.liveBase00
                    border.color: panelRoot.liveBase05
                    border.width: isSelected ? panelRoot.liveBorderWidth : 1

                    Text {
                        id: modeTxt
                        anchors.centerIn: parent
                        text: modelData.label
                        font.bold: true
                        font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                        color: isSelected ? panelRoot.liveBase00 : panelRoot.liveBase05
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (settingsManager) settingsManager.slantStyleMode = modelData.id
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: panelRoot.liveBase03 }

        Repeater {
            model: [
                { id: "left", label: "LEFT BAR SECTION", list: settingsManager ? settingsManager.getLeftList() : [] },
                { id: "center", label: "CENTER BAR SECTION", list: settingsManager ? settingsManager.getCenterList() : [] },
                { id: "right", label: "RIGHT BAR SECTION", list: settingsManager ? settingsManager.getRightList() : [] }
            ]
            delegate: ColumnLayout {
                id: sectionBlock
                readonly property string currentSection: modelData.id
                readonly property string sectionLabel: modelData.label
                readonly property var sectionList: modelData.list
                readonly property string sectionSlantLeft: panelRoot.slantLeftFor(currentSection)
                readonly property string sectionSlantRight: panelRoot.slantRightFor(currentSection)

                Layout.fillWidth: true
                spacing: 8

                SlantedBox {
                    id: sectionHeader
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(28, panelRoot.liveFontSize * 2.0)
                    slantLeft: sectionBlock.sectionSlantLeft
                    slantRight: sectionBlock.sectionSlantRight
                    slantWidth: panelRoot.liveSlantWidth
                    color: panelRoot.liveBase02
                    borderColor: panelRoot.liveBase0C
                    borderWidth: panelRoot.liveBorderWidth

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: parent.leftPadding
                        anchors.rightMargin: parent.rightPadding
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: sectionBlock.sectionLabel
                            font.family: panelRoot.liveFontFamily
                            font.bold: true; font.pixelSize: Math.max(11, panelRoot.liveFontSize - 2)
                            color: panelRoot.liveBase0C
                        }
                        Text {
                            text: panelRoot.slantGlyphFor(sectionBlock.currentSection)
                            font.family: "monospace"
                            font.bold: true; font.pixelSize: Math.max(11, panelRoot.liveFontSize - 2)
                            color: panelRoot.liveBase05
                        }
                    }
                }

                Repeater {
                    model: sectionBlock.sectionList

                    delegate: SlantedBox {
                        id: cardDelegate
                        readonly property string capsuleId: modelData
                        readonly property bool hasTooltip: (capsuleId !== "audio" && capsuleId !== "mic")
                        readonly property string cardSlantLeft: sectionBlock.sectionSlantLeft
                        readonly property string cardSlantRight: sectionBlock.sectionSlantRight
                        property bool drawerExpanded: false

                        Layout.fillWidth: true
                        Layout.preferredHeight: drawerExpanded ? (headerRow.height + drawerCol.implicitHeight + 28) : (headerRow.height + 14)
                        height: Layout.preferredHeight
                        slantLeft: cardDelegate.cardSlantLeft
                        slantRight: cardDelegate.cardSlantRight
                        slantWidth: panelRoot.liveSlantWidth
                        color: panelRoot.liveBase00
                        borderColor: drawerExpanded ? panelRoot.liveBase05 : panelRoot.liveBase03
                        borderWidth: panelRoot.liveBorderWidth
                        clip: true

                        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: cardDelegate.leftPadding
                            anchors.rightMargin: cardDelegate.rightPadding
                            anchors.topMargin: 6
                            anchors.bottomMargin: 8
                            spacing: 8

                            RowLayout {
                                id: headerRow
                                Layout.fillWidth: true
                                height: Math.max(32, panelRoot.liveFontSize * 2.0)
                                spacing: 8

                                Rectangle {
                                    width: 32; height: 32; radius: 6
                                    color: upBtnHover.hovered ? panelRoot.liveBase05 : panelRoot.liveBase00
                                    border.color: panelRoot.liveBase05
                                    border.width: (settingsManager && settingsManager.controlBorderWidth) ? settingsManager.controlBorderWidth : 2
                                    Text { anchors.centerIn: parent; text: "▲"; font.bold: true; font.pixelSize: 12; color: upBtnHover.hovered ? panelRoot.liveBase00 : panelRoot.liveBase05 }
                                    HoverHandler { id: upBtnHover }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsManager.moveWithinSection(sectionBlock.currentSection, index, index - 1) }
                                }

                                Rectangle {
                                    width: 32; height: 32; radius: 6
                                    color: downBtnHover.hovered ? panelRoot.liveBase05 : panelRoot.liveBase00
                                    border.color: panelRoot.liveBase05
                                    border.width: (settingsManager && settingsManager.controlBorderWidth) ? settingsManager.controlBorderWidth : 2
                                    Text { anchors.centerIn: parent; text: "▼"; font.bold: true; font.pixelSize: 12; color: downBtnHover.hovered ? panelRoot.liveBase00 : panelRoot.liveBase05 }
                                    HoverHandler { id: downBtnHover }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsManager.moveWithinSection(sectionBlock.currentSection, index, index + 1) }
                                }

                                Text {
                                    text: cardDelegate.capsuleId.toUpperCase()
                                    font.bold: true; font.pixelSize: panelRoot.liveFontSize
                                    color: panelRoot.liveBase05
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Row {
                                    spacing: 8
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                    Rectangle {
                                        width: editRow.implicitWidth + 22; height: 30; radius: 6
                                        color: cardDelegate.drawerExpanded ? panelRoot.liveBase05 : panelRoot.liveBase00
                                        border.color: panelRoot.liveBase05
                                        border.width: (settingsManager && settingsManager.controlBorderWidth) ? settingsManager.controlBorderWidth : 2
                                        Row {
                                            id: editRow
                                            anchors.centerIn: parent; spacing: 5
                                            Text { text: cardDelegate.drawerExpanded ? "✓" : "📐"; font.pixelSize: 12; color: cardDelegate.drawerExpanded ? panelRoot.liveBase00 : panelRoot.liveBase05; anchors.verticalCenter: parent.verticalCenter }
                                            Text { text: cardDelegate.drawerExpanded ? "Done" : "Edit"; font.bold: true; font.pixelSize: 11; color: cardDelegate.drawerExpanded ? panelRoot.liveBase00 : panelRoot.liveBase05; anchors.verticalCenter: parent.verticalCenter }
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                cardDelegate.drawerExpanded = !cardDelegate.drawerExpanded;
                                                if (settingsManager && cardDelegate.capsuleId !== "tray") {
                                                    settingsManager.previewCapsule = cardDelegate.drawerExpanded ? cardDelegate.capsuleId : "";
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 66; height: 30; radius: 6
                                        color: settingsManager.isCapsuleVisible(cardDelegate.capsuleId) ? panelRoot.liveBase0C : panelRoot.liveBase08
                                        border.color: settingsManager.isCapsuleVisible(cardDelegate.capsuleId) ? panelRoot.liveBase0C : panelRoot.liveBase08
                                        border.width: (settingsManager && settingsManager.controlBorderWidth) ? settingsManager.controlBorderWidth : 2
                                        Text { anchors.centerIn: parent; text: settingsManager.isCapsuleVisible(cardDelegate.capsuleId) ? "SHOW" : "HIDE"; font.pixelSize: 11; font.bold: true; color: "#000" }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsManager.toggleCapsuleVisibility(cardDelegate.capsuleId) }
                                    }
                                }
                            }

                            // EXPANDED DRAWER CONTENT
                            ColumnLayout {
                                id: drawerCol
                                Layout.fillWidth: true
                                visible: cardDelegate.drawerExpanded
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "Section:"
                                        font.bold: true; font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                                        color: panelRoot.liveBase05
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Repeater {
                                        model: [
                                            { id: "left", label: "Left" },
                                            { id: "center", label: "Center" },
                                            { id: "right", label: "Right" }
                                        ]
                                        delegate: Rectangle {
                                            readonly property bool isCurrentSec: sectionBlock.currentSection === modelData.id
                                            width: secTxt.implicitWidth + 20; height: 26; radius: 6
                                            color: isCurrentSec ? panelRoot.liveBase05 : panelRoot.liveBase00
                                            border.color: panelRoot.liveBase05
                                            border.width: (settingsManager && settingsManager.controlBorderWidth) ? settingsManager.controlBorderWidth : 2

                                            Text {
                                                id: secTxt; anchors.centerIn: parent; text: modelData.label
                                                font.pixelSize: 11; font.bold: true
                                                color: isCurrentSec ? panelRoot.liveBase00 : panelRoot.liveBase05
                                            }

                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (settingsManager && !isCurrentSec) {
                                                        settingsManager.moveToSection(cardDelegate.capsuleId, modelData.id);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Row {
                                    spacing: 8
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Slant:"
                                        font.bold: true; font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                                        color: panelRoot.liveBase05
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Repeater {
                                        model: [
                                            { id: "auto", label: "Auto" },
                                            { id: "left", label: "\\ Left" },
                                            { id: "right", label: "/ Right" },
                                            { id: "center", label: "\\ / Center" }
                                        ]
                                        delegate: Rectangle {
                                            readonly property string targetOption: modelData.id
                                            readonly property bool isCurrent: {
                                                var custom = settingsManager ? settingsManager.capsuleSlants[cardDelegate.capsuleId] : undefined;
                                                if (targetOption === "auto") return !custom || custom === "auto";
                                                return custom === targetOption;
                                            }
                                            width: pillText.implicitWidth + 18; height: 26; radius: 6
                                            color: isCurrent ? panelRoot.liveBase05 : panelRoot.liveBase00
                                            border.color: panelRoot.liveBase05
                                            border.width: (settingsManager && settingsManager.controlBorderWidth) ? settingsManager.controlBorderWidth : 2

                                            Text {
                                                id: pillText; anchors.centerIn: parent
                                                text: modelData.label
                                                font.pixelSize: 10; font.bold: true
                                                color: isCurrent ? panelRoot.liveBase00 : panelRoot.liveBase05
                                            }

                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: if (settingsManager) settingsManager.setModuleSlant(cardDelegate.capsuleId, targetOption)
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    visible: cardDelegate.capsuleId === "music"
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "🎵 Sources:"
                                        font.bold: true; font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                                        color: panelRoot.liveBase05
                                    }

                                    Rectangle {
                                        readonly property bool active: settingsManager ? settingsManager.mprisWatchLocal : true
                                        width: localT.implicitWidth + 18; height: 26; radius: 6
                                        color: active ? panelRoot.liveBase05 : panelRoot.liveBase00
                                        border.color: panelRoot.liveBase05
                                        border.width: (settingsManager && settingsManager.controlBorderWidth) ? settingsManager.controlBorderWidth : 2
                                        Text { id: localT; anchors.centerIn: parent; text: "🖥️ Local"; font.pixelSize: 11; font.bold: true; color: parent.active ? panelRoot.liveBase00 : panelRoot.liveBase05 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsManager.mprisWatchLocal = !settingsManager.mprisWatchLocal }
                                    }

                                    Rectangle {
                                        readonly property bool active: settingsManager ? settingsManager.mprisWatchSpotify : true
                                        width: spotT.implicitWidth + 18; height: 26; radius: 6
                                        color: active ? "#1db954" : panelRoot.liveBase00
                                        border.color: "#1db954"
                                        border.width: (settingsManager && settingsManager.controlBorderWidth) ? settingsManager.controlBorderWidth : 2
                                        Text { id: spotT; anchors.centerIn: parent; text: "🟢 Spotify"; font.pixelSize: 11; font.bold: true; color: parent.active ? "#000" : "#1db954" }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsManager.mprisWatchSpotify = !settingsManager.mprisWatchSpotify }
                                    }

                                    Rectangle {
                                        readonly property bool active: settingsManager ? settingsManager.mprisWatchBrowser : true
                                        width: browT.implicitWidth + 18; height: 26; radius: 6
                                        color: active ? panelRoot.liveBase0C : panelRoot.liveBase00
                                        border.color: panelRoot.liveBase0C
                                        border.width: (settingsManager && settingsManager.controlBorderWidth) ? settingsManager.controlBorderWidth : 2
                                        Text { id: browT; anchors.centerIn: parent; text: "🌐 Browser"; font.pixelSize: 11; font.bold: true; color: parent.active ? "#000" : panelRoot.liveBase0C }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsManager.mprisWatchBrowser = !settingsManager.mprisWatchBrowser }
                                    }
                                }

                                CyberSlider {
                                    visible: cardDelegate.capsuleId === "tray"
                                    label: "Tray Auto-Collapse Timeout"
                                    from: 0; to: 30; stepSize: 1; unit: "s"
                                    value: settingsManager ? settingsManager.trayCollapseTimeoutSec : 3
                                    fontSize: panelRoot.liveFontSize - 2
                                    theme: panelRoot.theme; Layout.fillWidth: true
                                    valueFormatter: function(v) { return v === 0 ? "Disabled (Stay Open)" : Math.round(v) + "s"; }
                                    onValueModified: (v) => { if (settingsManager) settingsManager.trayCollapseTimeoutSec = Math.round(v); }
                                }

                                CyberSlider {
                                    label: "Bar Capsule Width (0 = Auto)"
                                    from: 0; to: 350; stepSize: 10; unit: "px"
                                    value: settingsManager ? settingsManager.getCapsuleBarWidth(cardDelegate.capsuleId) : 0
                                    fontSize: panelRoot.liveFontSize - 2
                                    theme: panelRoot.theme; Layout.fillWidth: true
                                    valueFormatter: function(v) { return Math.round(v) === 0 ? "Auto" : Math.round(v) + "px"; }
                                    onValueModified: (v) => { if (settingsManager) settingsManager.setCapsuleBarWidth(cardDelegate.capsuleId, v); }
                                }

                                CyberSlider {
                                    visible: cardDelegate.hasTooltip && cardDelegate.capsuleId !== "tray"
                                    label: "Tooltip Width"; from: 300; to: 1400; stepSize: 20; unit: "px"
                                    value: settingsManager ? (settingsManager.getCapsuleWidth(cardDelegate.capsuleId) || 500) : 500
                                    fontSize: panelRoot.liveFontSize - 2
                                    theme: panelRoot.theme; Layout.fillWidth: true
                                    onValueModified: (v) => { if (settingsManager) settingsManager.setCapsuleWidth(cardDelegate.capsuleId, v); }
                                }

                                CyberSlider {
                                    visible: cardDelegate.hasTooltip && cardDelegate.capsuleId !== "tray"
                                    label: "Tooltip Height"; from: 180; to: 750; stepSize: 20; unit: "px"
                                    value: settingsManager ? (settingsManager.getCapsuleHeight(cardDelegate.capsuleId) || 460) : 460
                                    fontSize: panelRoot.liveFontSize - 2
                                    theme: panelRoot.theme; Layout.fillWidth: true
                                    onValueModified: (v) => { if (settingsManager) settingsManager.setCapsuleHeight(cardDelegate.capsuleId, v); }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
