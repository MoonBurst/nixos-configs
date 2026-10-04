import QtQuick
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io

Rectangle {
    id: setupModalRoot
    anchors.fill: parent
    color: "#B0000000"
    z: 300

    required property var engine
    property var theme: null
    property int overlayFontSize: 16

    signal configured()
    signal cancelled()

    property int currentStep: 1
    property string statusMsg: ""
    property bool hasError: false

    property bool hasSops: false
    property bool hasSavedCode: false
    property bool hasSavedAddress: false
    property string savedAddressVal: ""

    property string emailVal: ""
    property string nameVal: ""
    property string passwordVal: ""
    property string imapHostVal: "imap.gmail.com"
    property string imapPortVal: "993"
    property string smtpHostVal: "smtp.gmail.com"
    property string smtpPortVal: "465"
    property bool showPassword: false

    readonly property color base00: (theme && theme.base00) ? theme.base00 : "#121212"
    readonly property color base02: (theme && theme.base02) ? theme.base02 : "#222222"
    readonly property color base03: (theme && theme.base03) ? theme.base03 : "#45475a"
    readonly property color base05: (theme && theme.base05) ? theme.base05 : "yellow"
    readonly property color base06: (theme && theme.base06) ? theme.base06 : "white"
    readonly property color base08: (theme && theme.base08) ? theme.base08 : "#ff5555"
    readonly property color base0C: (theme && theme.base0C) ? theme.base0C : "#04f100"
    readonly property color innerBorderColor: (theme && theme.innerBorderColor) ? theme.innerBorderColor : "#FABD2F"
    readonly property int innerBorderWidth: 4

    Component.onCompleted: inspectExistingCredentials()
    onVisibleChanged: if (visible) inspectExistingCredentials()

    function inspectExistingCredentials() {
        hasError = false;
        statusMsg = "";
        inspectProc.running = false;
        inspectProc.running = true;
    }

    Process {
        id: inspectProc
        running: false
        command: [
            "sh", "-c",
            'HAS_SOPS=0; ' +
            'SOPS_FILE=$(find "$HOME/nix" "$HOME/dotfiles" "$HOME/.config" -maxdepth 3 -name "secrets.yaml" 2>/dev/null | head -n 1); ' +
            '[ -n "$SOPS_FILE" ] && command -v sops >/dev/null 2>&1 && HAS_SOPS=1; ' +
            'HAS_CODE=0; ' +
            'if [ -s /run/secrets/gmail_code_himalaya ] || [ -s /run/secrets/gmail_code ]; then HAS_CODE=1; ' +
            'elif [ -s "$HOME/.config/himalaya/password" ]; then HAS_CODE=1; ' +
            'elif [ $HAS_SOPS -eq 1 ] && grep -q "gmail_code_himalaya" "$SOPS_FILE" 2>/dev/null; then HAS_CODE=1; fi; ' +
            'ADDR=""; ' +
            'if [ -s /run/secrets/gmail_address_himalaya ]; then ADDR=$(cat /run/secrets/gmail_address_himalaya | tr -d "[:space:]"); ' +
            'elif [ -s /run/secrets/gmail_address ]; then ADDR=$(cat /run/secrets/gmail_address | tr -d "[:space:]"); ' +
            'elif [ -s "$HOME/.config/himalaya/email" ]; then ADDR=$(cat "$HOME/.config/himalaya/email" | tr -d "[:space:]"); fi; ' +
            'echo "$HAS_SOPS|$HAS_CODE|$ADDR"'
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                setupModalRoot.hasSops = (parts[0] === "1");
                setupModalRoot.hasSavedCode = (parts[1] === "1");
                if (parts.length > 2 && parts[2] !== "") {
                    setupModalRoot.hasSavedAddress = true;
                    setupModalRoot.savedAddressVal = parts[2];
                    setupModalRoot.emailVal = parts[2];
                }
                Qt.callLater(() => emailField.forceActiveFocus());
            }
        }
    }

    function nextStep() {
        hasError = false;
        statusMsg = "";
        if (currentStep === 1) {
            if (emailVal.trim() === "" || emailVal.indexOf("@") === -1) {
                hasError = true;
                statusMsg = "Please enter a valid Gmail address.";
                return;
            }
            if (nameVal === "") {
                var userPart = emailVal.split("@")[0];
                nameVal = userPart.charAt(0).toUpperCase() + userPart.slice(1);
            }
            currentStep = 2;
            Qt.callLater(() => nameField.forceActiveFocus());
        } else if (currentStep === 2) {
            currentStep = 3;
            Qt.callLater(() => passwordField.forceActiveFocus());
        } else if (currentStep === 3) {
            if (!hasSavedCode && passwordVal.trim() === "") {
                hasError = true;
                statusMsg = "Please enter your 16-character Google App Password.";
                return;
            }
            currentStep = 4;
            Qt.callLater(() => imapHostField.forceActiveFocus());
        } else if (currentStep === 4) {
            currentStep = 5;
            Qt.callLater(() => smtpHostField.forceActiveFocus());
        } else if (currentStep === 5) {
            saveAndDeploy();
        }
    }

    function prevStep() {
        hasError = false;
        statusMsg = "";
        if (currentStep > 1) {
            currentStep--;
            if (currentStep === 1) Qt.callLater(() => emailField.forceActiveFocus());
            else if (currentStep === 2) Qt.callLater(() => nameField.forceActiveFocus());
            else if (currentStep === 3) Qt.callLater(() => passwordField.forceActiveFocus());
            else if (currentStep === 4) Qt.callLater(() => imapHostField.forceActiveFocus());
        } else {
            setupModalRoot.cancelled();
        }
    }

    function saveAndDeploy() {
        statusMsg = setupModalRoot.hasSops ? "Encrypting into SOPS..." : "Configuring Himalaya...";
        deployProc.command = [
            "sh", "-c",
            'EMAIL="$1"; NAME="$2"; PASS="$3"; IMAP_H="$4"; IMAP_P="$5"; SMTP_H="$6"; SMTP_P="$7"; ' +
            'CONFIG_DIR="$HOME/.config/himalaya"; ' +
            'mkdir -p "$CONFIG_DIR"; chmod 700 "$CONFIG_DIR"; ' +
            'SOPS_FILE=$(find "$HOME/nix" "$HOME/dotfiles" "$HOME/.config" -maxdepth 3 -name "secrets.yaml" 2>/dev/null | head -n 1); ' +
            'if [ -n "$SOPS_FILE" ] && command -v sops >/dev/null 2>&1; then ' +
            '  rm -f "$CONFIG_DIR/password" "$CONFIG_DIR/email" 2>/dev/null || true; ' +
            '  grep -q "Quickshell_Email_Info" "$SOPS_FILE" 2>/dev/null || printf "\\n# Quickshell_Email_Info\\n" >> "$SOPS_FILE"; ' +
            '  sops --set \'["gmail_address_himalaya"] "\'"$EMAIL"\'"\' "$SOPS_FILE" 2>/dev/null || true; ' +
            '  if [ -n "$PASS" ]; then sops --set \'["gmail_code_himalaya"] "\'"$PASS"\'"\' "$SOPS_FILE" 2>/dev/null || true; fi; ' +
            'else ' +
            '  if [ -n "$PASS" ]; then printf "%s" "$PASS" > "$CONFIG_DIR/password"; chmod 600 "$CONFIG_DIR/password"; fi; ' +
            '  printf "%s" "$EMAIL" > "$CONFIG_DIR/email"; chmod 600 "$CONFIG_DIR/email"; ' +
            'fi; ' +
            '# Create clean helper script to avoid TOML quoting issues\n' +
            'cat << \'HELPER\' > "$CONFIG_DIR/get-password.sh"\n' +
            '#!/bin/sh\n' +
            'if [ -s /run/secrets/gmail_code_himalaya ]; then\n' +
            '  exec cat /run/secrets/gmail_code_himalaya\n' +
            'elif [ -s /run/secrets/gmail_code ]; then\n' +
            '  exec cat /run/secrets/gmail_code\n' +
            'elif [ -s "$HOME/.config/himalaya/password" ]; then\n' +
            '  exec cat "$HOME/.config/himalaya/password"\n' +
            'else\n' +
            '  SOPS_F=$(find "$HOME/nix" "$HOME/dotfiles" "$HOME/.config" -maxdepth 3 -name "secrets.yaml" 2>/dev/null | head -n 1)\n' +
            '  if [ -n "$SOPS_F" ] && command -v sops >/dev/null 2>&1; then\n' +
            '    exec sops -d --extract \'["gmail_code_himalaya"]\' "$SOPS_F"\n' +
            '  fi\n' +
            'fi\n' +
            'HELPER\n' +
            'chmod 700 "$CONFIG_DIR/get-password.sh"; ' +
            '# Write TOML\n' +
            'printf "[accounts.default]\\ndefault = true\\nemail = \\"%s\\"\\ndisplay-name = \\"%s\\"\\ndownloads-dir = \\"~/Downloads\\"\\n\\nbackend.type = \\"imap\\"\\nbackend.host = \\"%s\\"\\nbackend.port = %s\\nbackend.encryption.type = \\"tls\\"\\nbackend.login = \\"%s\\"\\nbackend.auth.type = \\"password\\"\\nbackend.auth.cmd = \\"%s/.config/himalaya/get-password.sh\\"\\n\\nmessage.send.backend.type = \\"smtp\\"\\nmessage.send.backend.host = \\"%s\\"\\nmessage.send.backend.port = %s\\nmessage.send.backend.encryption.type = \\"tls\\"\\nmessage.send.backend.login = \\"%s\\"\\nmessage.send.backend.auth.type = \\"password\\"\\nmessage.send.backend.auth.cmd = \\"%s/.config/himalaya/get-password.sh\\"\\n" "$EMAIL" "$NAME" "$IMAP_H" "$IMAP_P" "$EMAIL" "$HOME" "$SMTP_H" "$SMTP_P" "$EMAIL" "$HOME" > "$CONFIG_DIR/config.toml"; ' +
            'chmod 600 "$CONFIG_DIR/config.toml"; ' +
            'exit 0',
            "sh",
            emailVal, nameVal, passwordVal, imapHostVal, imapPortVal, smtpHostVal, smtpPortVal
        ];
        deployProc.running = true;
    }

    Process {
        id: deployProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim() !== "") {
                    console.warn("[Himalaya Deploy Error]: " + text);
                }
            }
        }
        onExited: (code) => {
            if (code === 0) {
                Quickshell.execDetached([
                    "notify-send", "-a", "Himalaya",
                    "Email Configured",
                    setupModalRoot.hasSops
                    ? "Encrypted directly into SOPS. Zero plaintext passwords saved on disk."
                    : "Account configured. Saved to user storage."
                ]);
                setupModalRoot.configured();
            } else {
                setupModalRoot.hasError = true;
                setupModalRoot.statusMsg = "Failed to write configuration files.";
            }
        }
    }

    Rectangle {
        id: modalFloatingCard
        width: 620
        height: 460
        anchors.centerIn: parent
        color: setupModalRoot.base00
        border.color: setupModalRoot.innerBorderColor
        border.width: setupModalRoot.innerBorderWidth
        radius: 12

        MouseArea {
            anchors.fill: parent
            drag.target: modalFloatingCard
            drag.minimumX: -parent.width / 2 + 100
            drag.maximumX: parent.width / 2 - 100
            drag.minimumY: -parent.height / 2 + 100
            drag.maximumY: parent.height / 2 - 100
        }

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 12

            RowLayout {
                width: parent.width
                Text {
                    text: {
                        if (setupModalRoot.currentStep === 1) return "📧 GMAIL ADDRESS (1/5)";
                        if (setupModalRoot.currentStep === 2) return "👤 DISPLAY NAME (2/5)";
                        if (setupModalRoot.currentStep === 3) return "🔐 GOOGLE APP PASSWORD (3/5)";
                        if (setupModalRoot.currentStep === 4) return "📥 IMAP SERVER (4/5)";
                        return "📤 SMTP SERVER (5/5)";
                    }
                    font.bold: true
                    font.pixelSize: setupModalRoot.overlayFontSize
                    color: setupModalRoot.base05
                    Layout.fillWidth: true
                }
                Text {
                    text: setupModalRoot.currentStep + " of 5"
                    font.pixelSize: setupModalRoot.overlayFontSize - 3
                    color: "#888"
                }
            }

            Text {
                text: {
                    if (setupModalRoot.currentStep === 1) {
                        return setupModalRoot.hasSavedAddress
                        ? "✅ Found existing email: " + setupModalRoot.savedAddressVal
                        : "Enter your Gmail address:";
                    }
                    if (setupModalRoot.currentStep === 2) return "Enter your name as shown to email recipients:";
                    if (setupModalRoot.currentStep === 3) {
                        return setupModalRoot.hasSavedCode
                        ? "✅ Existing App Password found!"
                        : "Enter your 16-letter Google App Password:";
                    }
                    if (setupModalRoot.currentStep === 4) return "Confirm incoming IMAP server host & port:";
                    return "Confirm outgoing SMTP server host & port:";
                }
                font.pixelSize: setupModalRoot.overlayFontSize - 2
                color: setupModalRoot.base06
            }

            Item {
                width: parent.width; height: setupModalRoot.currentStep === 3 ? 140 : 44

                Rectangle {
                    anchors.fill: parent; visible: setupModalRoot.currentStep === 1
                    color: setupModalRoot.base00; border.color: emailField.activeFocus ? setupModalRoot.innerBorderColor : setupModalRoot.base03; border.width: 1.5; radius: 6
                    TextInput {
                        id: emailField; anchors.fill: parent; anchors.margins: 10
                        font.pixelSize: setupModalRoot.overlayFontSize; color: setupModalRoot.base06
                        verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                        text: setupModalRoot.emailVal
                        onTextChanged: setupModalRoot.emailVal = text
                        Keys.onPressed: (event) => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { setupModalRoot.nextStep(); event.accepted = true; } }
                        Text { text: "e.g. yourname@gmail.com"; color: "#666"; visible: parent.text === ""; font.pixelSize: setupModalRoot.overlayFontSize; verticalAlignment: Text.AlignVCenter; anchors.fill: parent }
                    }
                }

                Rectangle {
                    anchors.fill: parent; visible: setupModalRoot.currentStep === 2
                    color: setupModalRoot.base00; border.color: nameField.activeFocus ? setupModalRoot.innerBorderColor : setupModalRoot.base03; border.width: 1.5; radius: 6
                    TextInput {
                        id: nameField; anchors.fill: parent; anchors.margins: 10
                        font.pixelSize: setupModalRoot.overlayFontSize; color: setupModalRoot.base06
                        verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                        text: setupModalRoot.nameVal
                        onTextChanged: setupModalRoot.nameVal = text
                        Keys.onPressed: (event) => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { setupModalRoot.nextStep(); event.accepted = true; } }
                        Text { text: "e.g. Your Name"; color: "#666"; visible: parent.text === ""; font.pixelSize: setupModalRoot.overlayFontSize; verticalAlignment: Text.AlignVCenter; anchors.fill: parent }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent; visible: setupModalRoot.currentStep === 3; spacing: 8

                    Rectangle {
                        Layout.fillWidth: true; height: 42
                        color: setupModalRoot.base00; border.color: passwordField.activeFocus ? setupModalRoot.innerBorderColor : setupModalRoot.base03; border.width: 1.5; radius: 6
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 8
                            TextInput {
                                id: passwordField; Layout.fillWidth: true; Layout.fillHeight: true
                                font.pixelSize: setupModalRoot.overlayFontSize; color: setupModalRoot.base06
                                echoMode: setupModalRoot.showPassword ? TextInput.Normal : TextInput.Password
                                verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                text: setupModalRoot.passwordVal
                                onTextChanged: setupModalRoot.passwordVal = text
                                Keys.onPressed: (event) => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { setupModalRoot.nextStep(); event.accepted = true; } }
                                Text {
                                    text: setupModalRoot.hasSavedCode ? "Using saved password (or enter new to replace)..." : "Paste 16-character App Password..."
                                    color: "#666"; visible: parent.text === ""; font.pixelSize: setupModalRoot.overlayFontSize - 2; verticalAlignment: Text.AlignVCenter; anchors.fill: parent
                                }
                            }
                            Rectangle {
                                width: 28; height: 28; radius: 4; color: "transparent"
                                Text { anchors.centerIn: parent; text: setupModalRoot.showPassword ? "🙈" : "👁"; font.pixelSize: 15 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: setupModalRoot.showPassword = !setupModalRoot.showPassword }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 78; radius: 6
                        color: setupModalRoot.base02
                        border.color: setupModalRoot.base03; border.width: 1
                        Column {
                            anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text {
                                text: setupModalRoot.hasSops ? "🔒 SOPS Security Active:" : "📁 Local Storage (No SOPS):"
                                font.bold: true; font.pixelSize: 11
                                color: setupModalRoot.base0C
                            }
                            Text {
                                text: setupModalRoot.hasSops
                                ? "Encrypted directly into secrets.yaml with '# Quickshell_Email_Info'.\nNo plaintext passwords will be written to disk in ~/.config."
                                : "Saved to ~/.config/himalaya/password with 0600 user-only permissions."
                                font.pixelSize: 10; color: setupModalRoot.base06
                            }
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent; visible: setupModalRoot.currentStep === 4; spacing: 10
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; color: setupModalRoot.base00
                        border.color: imapHostField.activeFocus ? setupModalRoot.innerBorderColor : setupModalRoot.base03; border.width: 1.5; radius: 6
                        TextInput {
                            id: imapHostField; anchors.fill: parent; anchors.margins: 10
                            font.pixelSize: setupModalRoot.overlayFontSize; color: setupModalRoot.base06
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            text: setupModalRoot.imapHostVal
                            onTextChanged: setupModalRoot.imapHostVal = text
                            Keys.onPressed: (event) => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { setupModalRoot.nextStep(); event.accepted = true; } }
                        }
                    }
                    Rectangle {
                        width: 80; Layout.fillHeight: true; color: setupModalRoot.base00
                        border.color: imapPortField.activeFocus ? setupModalRoot.innerBorderColor : setupModalRoot.base03; border.width: 1.5; radius: 6
                        TextInput {
                            id: imapPortField; anchors.fill: parent; anchors.margins: 10
                            font.pixelSize: setupModalRoot.overlayFontSize; color: setupModalRoot.base06
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            text: setupModalRoot.imapPortVal
                            onTextChanged: setupModalRoot.imapPortVal = text
                            Keys.onPressed: (event) => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { setupModalRoot.nextStep(); event.accepted = true; } }
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent; visible: setupModalRoot.currentStep === 5; spacing: 10
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; color: setupModalRoot.base00
                        border.color: smtpHostField.activeFocus ? setupModalRoot.innerBorderColor : setupModalRoot.base03; border.width: 1.5; radius: 6
                        TextInput {
                            id: smtpHostField; anchors.fill: parent; anchors.margins: 10
                            font.pixelSize: setupModalRoot.overlayFontSize; color: setupModalRoot.base06
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            text: setupModalRoot.smtpHostVal
                            onTextChanged: setupModalRoot.smtpHostVal = text
                            Keys.onPressed: (event) => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { setupModalRoot.nextStep(); event.accepted = true; } }
                        }
                    }
                    Rectangle {
                        width: 80; Layout.fillHeight: true; color: setupModalRoot.base00
                        border.color: smtpPortField.activeFocus ? setupModalRoot.innerBorderColor : setupModalRoot.base03; border.width: 1.5; radius: 6
                        TextInput {
                            id: smtpPortField; anchors.fill: parent; anchors.margins: 10
                            font.pixelSize: setupModalRoot.overlayFontSize; color: setupModalRoot.base06
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            text: setupModalRoot.smtpPortVal
                            onTextChanged: setupModalRoot.smtpPortVal = text
                            Keys.onPressed: (event) => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { setupModalRoot.nextStep(); event.accepted = true; } }
                        }
                    }
                }
            }

            Rectangle {
                visible: setupModalRoot.currentStep === 3
                width: parent.width; height: 30; radius: 6
                color: helpBtnMouse.containsMouse ? setupModalRoot.innerBorderColor : setupModalRoot.base02
                border.color: setupModalRoot.innerBorderColor; border.width: 1

                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text {
                        text: "🔗 Open Google App Passwords Page"
                        font.bold: true; font.pixelSize: 11
                        color: helpBtnMouse.containsMouse ? "#000000" : setupModalRoot.base05
                    }
                }

                MouseArea {
                    id: helpBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("https://myaccount.google.com/apppasswords")
                }
            }

            Text {
                text: {
                    if (setupModalRoot.statusMsg !== "") return setupModalRoot.statusMsg;
                    if (setupModalRoot.currentStep === 3) return "1. Generate an App Password named 'Himalaya' on Google.\n2. Paste it here to save it.";
                    if (setupModalRoot.currentStep === 4) return "Default Gmail IMAP SSL port is 993.";
                    if (setupModalRoot.currentStep === 5) return "Default Gmail SMTP SSL port is 465.";
                    return "Press [Enter] to proceed to the next step.";
                }
                font.pixelSize: 11
                color: setupModalRoot.hasError ? setupModalRoot.base08 : (setupModalRoot.statusMsg !== "" ? setupModalRoot.base0C : "#aaa")
                wrapMode: Text.WordWrap; width: parent.width
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                width: parent.width; height: 34; spacing: 10

                Rectangle {
                    width: 90; height: 32; radius: 6; color: "transparent"
                    border.color: setupModalRoot.base05; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: setupModalRoot.currentStep <= 1 ? "Cancel" : "← Back"
                        color: setupModalRoot.base05; font.bold: true; font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (setupModalRoot.currentStep <= 1) setupModalRoot.cancelled();
                            else setupModalRoot.prevStep();
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 160; height: 32; radius: 6; color: setupModalRoot.base05
                    Text {
                        anchors.centerIn: parent
                        text: setupModalRoot.currentStep === 5 ? "Save & Connect ✔" : "Next ➔"
                        color: "#11111b"; font.bold: true; font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: setupModalRoot.nextStep()
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: setupModalRoot.visible
        onActivated: {
            if (setupModalRoot.currentStep > 1) setupModalRoot.prevStep();
            else setupModalRoot.cancelled();
        }
    }
}
