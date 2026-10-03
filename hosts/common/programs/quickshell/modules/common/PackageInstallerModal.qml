import QtQuick
import QtQuick.Layouts 1.15
import Quickshell.Io

Item {
    id: root

    property string title: "INSTALL PACKAGE"
    property string description: "Enter your sudo password to install from official repos:"
    property string pacmanPkg: ""
    property string aptPkg: ""
    property string dnfPkg: ""
    property string zypperPkg: ""
    property string nixPkg: ""
    property var customCommand: null

    property color themeBase00: (shell && shell.theme && shell.theme.base00) ? shell.theme.base00 : "#11111b"
    property color themeBase02: (shell && shell.theme && shell.theme.base02) ? shell.theme.base02 : "#313244"
    property color themeBase03: (shell && shell.theme && shell.theme.base03) ? shell.theme.base03 : "#45475a"
    property color themeBase05: (shell && shell.theme && shell.theme.base05) ? shell.theme.base05 : "yellow"
    property color themeBase08: (shell && shell.theme && shell.theme.base08) ? shell.theme.base08 : "#ff5555"
    property color themeBase0C: (shell && shell.theme && shell.theme.base0C) ? shell.theme.base0C : "#04f100"
    property string themeFontFamily: (shell && shell.theme && shell.theme.fontFamily) ? shell.theme.fontFamily : "monospace"

    property bool isPromptingSudo: false
    property bool isInstalling: false
    property bool installError: false
    property string statusMsg: ""

    signal installed()
    signal cancelled()

    function openPrompt() {
        isPromptingSudo = true;
        isInstalling = false;
        installError = false;
        statusMsg = "";
        sudoField.text = "";
        Qt.callLater(() => sudoField.forceActiveFocus());
    }

    function runInstall(pass) {
        if (!pass || pass.trim() === "" || isInstalling) return;
        isInstalling = true;
        installError = false;
        statusMsg = "Installing Himalaya...";

        if (customCommand) {
            installerProc.command = typeof customCommand === "function" ? customCommand(pass) : customCommand;
            installerProc.running = true;
        } else {
            installerProc.command = [
                "sudo", "-S", "-k", "bash", "-c",
                "if command -v pacman >/dev/null 2>&1; then pacman -Sy --noconfirm " + pacmanPkg + "; " +
                "elif command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install -y " + aptPkg + "; " +
                "elif command -v dnf >/dev/null 2>&1; then dnf install -y " + dnfPkg + "; " +
                "elif command -v zypper >/dev/null 2>&1; then zypper install -y " + zypperPkg + "; " +
                "else echo 'No supported package manager found' >&2; exit 1; fi"
            ];
            installerProc.running = true;
            installerProc.write(pass + "\n");
        }
    }

    Process {
        id: installerProc
        running: false
        onExited: (code) => {
            root.isInstalling = false;
            if (code === 0) {
                root.installError = false;
                root.isPromptingSudo = false;
                root.statusMsg = "Installed successfully!";
                root.installed();
            } else {
                root.installError = true;
                root.statusMsg = "Install failed or incorrect password.";
                sudoField.text = "";
                Qt.callLater(() => sudoField.forceActiveFocus());
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 10

        Text {
            text: root.title
            font.family: root.themeFontFamily
            font.bold: true
            font.pixelSize: 15
            color: root.installError ? root.themeBase08 : root.themeBase05
        }

        Text {
            text: root.description
            font.family: root.themeFontFamily
            font.pixelSize: 12
            color: root.themeBase05
            opacity: 0.8
            width: parent.width
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: parent.width
            height: 36
            radius: 6
            color: root.themeBase00
            border.color: root.installError ? root.themeBase08 : root.themeBase05
            border.width: 1.5

            TextInput {
                id: sudoField
                anchors.fill: parent
                anchors.margins: 8
                echoMode: TextInput.Password
                color: root.themeBase05
                font.pixelSize: 14
                verticalAlignment: TextInput.AlignVCenter
                enabled: !root.isInstalling

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.runInstall(text);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.isPromptingSudo = false;
                        root.cancelled();
                        event.accepted = true;
                    }
                }
            }
        }

        Text {
            visible: root.statusMsg !== ""
            text: root.statusMsg
            font.pixelSize: 12
            color: root.installError ? root.themeBase08 : root.themeBase0C
        }

        Row {
            spacing: 10

            Rectangle {
                width: 90
                height: 30
                radius: 4
                color: "transparent"
                border.color: root.themeBase05
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: root.themeBase05
                    font.bold: true
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isPromptingSudo = false;
                        root.cancelled();
                    }
                }
            }

            Rectangle {
                width: 110
                height: 30
                radius: 4
                color: root.themeBase05

                Text {
                    anchors.centerIn: parent
                    text: root.isInstalling ? "Installing..." : "Confirm"
                    color: "#11111b"
                    font.bold: true
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.isInstalling
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runInstall(sudoField.text)
                }
            }
        }
    }
}
