import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../../../settings"

ColumnLayout {
    id: root
    required property var panelRoot

    readonly property var settingsManager: panelRoot.settingsManager
    readonly property var shell: panelRoot.shell

    Layout.fillWidth: true
    spacing: 16

    Text {
        text: "🪟 WINDOW SIZING & LIVE PREVIEWS"
        font.pixelSize: panelRoot.liveFontSize + 1
        font.bold: true
        color: panelRoot.liveBase0C
    }

    CyberSlider {
        label: "Lazy Loader Unload Grace Period (Keeps RAM/VRAM warm for fast re-opens)"
        from: 0; to: 120; stepSize: 5; unit: "s"
        value: settingsManager ? settingsManager.overlayGraceTimeoutSec : 10
        fontSize: panelRoot.liveFontSize
        theme: panelRoot.theme
        Layout.fillWidth: true
        valueFormatter: function(v) { return v === 0 ? "Instant (0s)" : Math.round(v) + "s"; }
        onValueModified: (v) => { if (settingsManager) settingsManager.overlayGraceTimeoutSec = Math.round(v); }
    }

    Repeater {
        model: [
            { id: "launcher",   name: "App Launcher",            icon: "🚀" },
            { id: "calc",       name: "Calculator & Units",      icon: "🧮" },
            { id: "clipboard",  name: "Clipboard Manager",       icon: "📋" },
            { id: "dictionary", name: "Dictionary",              icon: "📖" },
            { id: "unicode",    name: "Unicode Search",          icon: "🔣" },
            { id: "notes",      name: "Quick Notes",             icon: "📝" },
            { id: "pass",       name: "Password Store",          icon: "🔑" },
            { id: "power",      name: "Power & Session",         icon: "⚡" },
            { id: "todo",       name: "Todo Task Board",         icon: "✅" },
            { id: "gemini",     name: "Gemini AI Assistant",     icon: "🤖" },
            { id: "settings",   name: "Settings Menu Window",    icon: "⚙" },
            { id: "web",        name: "Web Search",              icon: "🌐" },
            { id: "email",      name: "Email Client",            icon: "✉" },
            { id: "rng",        name: "Random Number Generator", icon: "🎲" },
            { id: "amogus",     name: "Among Us Tracker",        icon: "ඞ" }
        ]

        delegate: Rectangle {
            Layout.fillWidth: true
            height: Math.max(46, panelRoot.liveFontSize * 2.2)
            radius: 8
            color: panelRoot.liveBase00
            border.color: (settingsManager && settingsManager.previewWindow === modelData.id) ? panelRoot.liveBase0C : panelRoot.liveBase03
            border.width: panelRoot.liveBorderWidth

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Text { text: modelData.icon; font.pixelSize: Math.max(14, panelRoot.liveFontSize) }
                Text {
                    text: modelData.name.toUpperCase()
                    font.bold: true
                    font.pixelSize: panelRoot.liveFontSize
                    color: panelRoot.liveBase05
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                    Rectangle {
                        width: openBtnText.implicitWidth + 20
                        height: Math.max(28, panelRoot.liveFontSize * 1.7)
                        radius: 4
                        color: openBtnHover.hovered ? panelRoot.liveBase05 : "transparent"
                        border.color: panelRoot.liveBase05
                        border.width: (settingsManager && settingsManager.controlBorderWidth) ? settingsManager.controlBorderWidth : 2

                        Text {
                            id: openBtnText
                            anchors.centerIn: parent
                            text: "🚀 Open"
                            font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                            font.bold: true
                            color: openBtnHover.hovered ? "#000" : panelRoot.liveBase05
                        }
                        HoverHandler { id: openBtnHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (settingsManager) settingsManager.previewWindow = "";
                                if (!shell) return;
                                switch (modelData.id) {
                                    case "launcher": shell.appLauncherWindow.open(); break;
                                    case "calc": shell.calcWindow.open(); break;
                                    case "clipboard": shell.clipboardWindow.open(); break;
                                    case "dictionary": shell.dictionaryWindow.open(); break;
                                    case "unicode": shell.unicodeWindow.open(); break;
                                    case "notes": shell.notesWindow.open(); break;
                                    case "pass": shell.passWindow.open(); break;
                                    case "power": shell.powerWindow.open(); break;
                                    case "todo": shell.todoWindow.open(); break;
                                    case "gemini": shell.geminiWindow.open(); break;
                                    case "settings": shell.settingsWindow.open(); break;
                                    case "web": shell.startPageWindow.open(); break;
                                    case "email": shell.emailWindow.open(); break;
                                    case "amogus": if (shell.amogusWindowInstance) shell.amogusWindowInstance.toggleWindow(); break;
                                    case "rng": if (shell.diceRollerWindowInstance) shell.diceRollerWindowInstance.openWithTarget(); break;
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: editBtnRow.implicitWidth + 20
                        height: Math.max(28, panelRoot.liveFontSize * 1.7)
                        radius: 4
                        color: (settingsManager && settingsManager.previewWindow === modelData.id) ? panelRoot.liveBase05 : panelRoot.liveBase02
                        border.color: panelRoot.liveBase05
                        border.width: (settingsManager && settingsManager.controlBorderWidth) ? settingsManager.controlBorderWidth : 2

                        Row {
                            id: editBtnRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "📐"
                                font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                                color: (settingsManager && settingsManager.previewWindow === modelData.id) ? panelRoot.liveBase00 : panelRoot.liveBase05
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Edit"
                                font.bold: true
                                font.pixelSize: Math.max(10, panelRoot.liveFontSize - 3)
                                color: (settingsManager && settingsManager.previewWindow === modelData.id) ? panelRoot.liveBase00 : panelRoot.liveBase05
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (settingsManager) {
                                    settingsManager.previewWindow = (settingsManager.previewWindow === modelData.id) ? "" : modelData.id;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
