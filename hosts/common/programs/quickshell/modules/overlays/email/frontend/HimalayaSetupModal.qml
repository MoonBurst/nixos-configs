import QtQuick
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io

Rectangle {
    id: setupModalRoot
    anchors.fill: parent
    color: "#EE000000"
    z: 300

    required property var engine
    property var theme: null
    property int overlayFontSize: 16

    signal configured()
    signal cancelled()

    property int currentStep: 1
    property string sudoPass: ""
    property bool isInstalling: false
    property string statusMsg: ""
    property bool hasError: false

    property string emailVal: ""
    property string nameVal: ""
    property string passwordVal: ""
    property string imapHostVal: "imap.gmail.com"
    property string imapPortVal: "993"
    property string smtpHostVal: "smtp.gmail.com"
    property string smtpPortVal: "465"
    property bool showPassword: false

    property string providerHelpUrl: ""
    property string providerBtnLabel: ""
    property string providerInstructions: ""

    readonly property color base00: (theme && theme.base00) ? theme.base00 : "#121212"
    readonly property color base02: (theme && theme.base02) ? theme.base02 : "#222222"
    readonly property color base03: (theme && theme.base03) ? theme.base03 : "#45475a"
    readonly property color base05: (theme && theme.base05) ? theme.base05 : "yellow"
    readonly property color base06: (theme && theme.base06) ? theme.base06 : "white"
    readonly property color base08: (theme && theme.base08) ? theme.base08 : "#ff5555"
    readonly property color base0C: (theme && theme.base0C) ? theme.base0C : "#04f100"
    readonly property color innerBorderColor: (theme && theme.innerBorderColor) ? theme.innerBorderColor : "#FABD2F"
    readonly property int innerBorderWidth: 4

    Component.onCompleted: checkSystemBinaries()
    onVisibleChanged: if (visible) checkSystemBinaries()

    function checkSystemBinaries() {
        hasError = false;
        statusMsg = "";
        binaryCheckProc.running = false;
        binaryCheckProc.running = true;
    }

    Process {
        id: binaryCheckProc
        running: false
        command: [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'if command -v himalaya >/dev/null 2>&1 && command -v mbsync >/dev/null 2>&1; then echo "1"; else echo "0"; fi'
        ]
        stdout: SplitParser {
            onRead: data => {
                var hasBinaries = (data.trim() === "1");
                if (hasBinaries) {
                    setupModalRoot.currentStep = 1;
                    Qt.callLater(() => emailField.forceActiveFocus());
                } else {
                    setupModalRoot.currentStep = 0;
                    Qt.callLater(() => sudoField.forceActiveFocus());
                }
            }
        }
    }

    function runInstallCheck(pass) {
        if (!pass || pass.trim() === "" || isInstalling) return;
        isInstalling = true;
        hasError = false;
        statusMsg = "Verifying password & installing packages...";

        installProc.command = [
            "bash", "-c",
            "export PATH=\"/run/wrappers/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH\"\n" +
            "printf '%s\\n' \"$1\" | sudo -S -k -p '' -v || exit 1\n" +
            "if ! (command -v himalaya >/dev/null 2>&1 && command -v mbsync >/dev/null 2>&1); then\n" +
            "  if command -v pacman >/dev/null 2>&1; then sudo pacman -Sy --noconfirm himalaya isync libnotify;\n" +
            "  elif command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y himalaya isync libnotify-bin;\n" +
            "  elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y himalaya isync libnotify;\n" +
            "  elif command -v zypper >/dev/null 2>&1; then zypper install -y himalaya isync libnotify;\n" +
            "  elif command -v nix-env >/dev/null 2>&1; then nix-env -iA nixpkgs.himalaya nixpkgs.isync nixpkgs.libnotify;\n" +
            "  elif command -v nix >/dev/null 2>&1; then nix profile install nixpkgs#himalaya nixpkgs#isync nixpkgs#libnotify;\n" +
            "  else curl -sSL https://raw.githubusercontent.com/pimalaya/himalaya/master/install.sh | sudo sh; fi\n" +
            "fi\n" +
            "command -v himalaya >/dev/null 2>&1 || exit 1",
            "bash", pass
        ];
        installProc.running = true;
    }

    Process {
        id: installProc
        running: false
        onExited: (code) => {
            setupModalRoot.isInstalling = false;
            if (code === 0) {
                setupModalRoot.hasError = false;
                setupModalRoot.currentStep = 1;
                Qt.callLater(() => emailField.forceActiveFocus());
            } else {
                setupModalRoot.hasError = true;
                setupModalRoot.statusMsg = "Incorrect password or installation failed.";
                sudoField.text = "";
                Qt.callLater(() => sudoField.forceActiveFocus());
            }
        }
    }

    function guessProviderDefaults(email) {
        var domain = (email.split("@")[1] || "").toLowerCase().trim();
        if (domain === "gmail.com" || domain === "googlemail.com") {
            imapHostVal = "imap.gmail.com"; imapPortVal = "993";
            smtpHostVal = "smtp.gmail.com"; smtpPortVal = "465";
            providerHelpUrl = "https://myaccount.google.com/apppasswords";
            providerBtnLabel = "🔗 Open Google App Passwords Page";
            providerInstructions = "1. Enable 2-Step Verification in Google.\n2. Create an App Password named 'Himalaya' and paste the 16-letter code.";
        } else if (domain === "outlook.com" || domain === "hotmail.com" || domain === "live.com" || domain === "office365.com") {
            imapHostVal = "outlook.office365.com"; imapPortVal = "993";
            smtpHostVal = "smtp.office365.com"; smtpPortVal = "587";
            providerHelpUrl = "https://account.live.com/proofs/manage/additional";
            providerBtnLabel = "🔗 Open Microsoft App Passwords Page";
            providerInstructions = "Create an App Password under Advanced Security Options in your Microsoft account.";
        } else if (domain === "yahoo.com") {
            imapHostVal = "imap.mail.yahoo.com"; imapPortVal = "993";
            smtpHostVal = "smtp.mail.yahoo.com"; smtpPortVal = "465";
            providerHelpUrl = "https://login.yahoo.com/account/security";
            providerBtnLabel = "🔗 Open Yahoo App Passwords Page";
            providerInstructions = "Generate an App Password under Account Security in your Yahoo profile.";
        } else if (domain === "icloud.com" || domain === "me.com" || domain === "mac.com") {
            imapHostVal = "imap.mail.me.com"; imapPortVal = "993";
            smtpHostVal = "smtp.mail.me.com"; smtpPortVal = "587";
            providerHelpUrl = "https://appleid.apple.com/account/manage";
            providerBtnLabel = "🔗 Open Apple ID App Passwords";
            providerInstructions = "Generate an App-Specific Password under Sign-In & Security on appleid.apple.com.";
        } else if (domain === "fastmail.com") {
            imapHostVal = "imap.fastmail.com"; imapPortVal = "993";
            smtpHostVal = "smtp.fastmail.com"; smtpPortVal = "465";
            providerHelpUrl = "https://app.fastmail.com/settings/security/tokens";
            providerBtnLabel = "🔗 Open Fastmail App Passwords";
            providerInstructions = "Generate an App Password under Settings → Password & Security in Fastmail.";
        } else if (domain !== "") {
            imapHostVal = "imap." + domain; imapPortVal = "993";
            smtpHostVal = "smtp." + domain; smtpPortVal = "587";
            providerHelpUrl = "";
            providerBtnLabel = "";
            providerInstructions = "Enter your mailbox password or server access token.";
        }
        if (nameVal === "" && email.indexOf("@") !== -1) {
            var userPart = email.split("@")[0];
            nameVal = userPart.charAt(0).toUpperCase() + userPart.slice(1);
        }
    }

    function nextStep() {
        hasError = false;
        statusMsg = "";
        if (currentStep === 1) {
            if (emailVal.trim() === "" || emailVal.indexOf("@") === -1) {
                hasError = true;
                statusMsg = "Please enter a valid email address.";
                return;
            }
            guessProviderDefaults(emailVal.trim());
            currentStep = 2;
            Qt.callLater(() => nameField.forceActiveFocus());
        } else if (currentStep === 2) {
            currentStep = 3;
            Qt.callLater(() => passwordField.forceActiveFocus());
        } else if (currentStep === 3) {
            if (passwordVal.trim() === "") {
                hasError = true;
                statusMsg = "Password cannot be empty.";
                return;
            }
            currentStep = 4;
            Qt.callLater(() => imapHostField.forceActiveFocus());
        } else if (currentStep === 4) {
            if (imapHostVal.trim() === "") {
                hasError = true;
                statusMsg = "IMAP server host is required.";
                return;
            }
            currentStep = 5;
            Qt.callLater(() => smtpHostField.forceActiveFocus());
        } else if (currentStep === 5) {
            if (smtpHostVal.trim() === "") {
                hasError = true;
                statusMsg = "SMTP server host is required.";
                return;
            }
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
        statusMsg = "Deploying Himalaya configuration...";
        deployProc.command = [
            "sh", "-c",
            'SCR="' + Quickshell.shellDir + '/modules/overlays/email/backend/HimalayaEngine.lua"; ' +
            'CMD="lua"; command -v luajit >/dev/null 2>&1 && CMD="luajit"; ' +
            '"$CMD" "$SCR" "$1" "$2" "$3" "$4" "$5" "$6" "$7"',
            "sh",
            emailVal, nameVal, passwordVal, imapHostVal, imapPortVal, smtpHostVal, smtpPortVal
        ];
        deployProc.running = true;
    }

    Process {
        id: deployProc
        running: false
        onExited: (code) => {
            if (code === 0) {
                Quickshell.execDetached([
                    "notify-send", "-a", "Himalaya",
                    "Himalaya Configured",
                    "Account " + setupModalRoot.emailVal + " configured successfully!"
                ]);
                setupModalRoot.configured();
            } else {
                setupModalRoot.hasError = true;
                setupModalRoot.statusMsg = "Failed to write configuration files.";
            }
        }
    }

    MouseArea { anchors.fill: parent }

    Rectangle {
        width: 530; height: 350
        color: setupModalRoot.base00
        border.color: setupModalRoot.innerBorderColor
        border.width: setupModalRoot.innerBorderWidth
        radius: 10
        anchors.centerIn: parent

        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                width: parent.width
                Text {
                    text: {
                        if (setupModalRoot.currentStep === 0) return "🔑 INSTALL HIMALAYA & SYNC ENGINE";
                        if (setupModalRoot.currentStep === 1) return "📧 EMAIL ADDRESS (1/5)";
                        if (setupModalRoot.currentStep === 2) return "👤 DISPLAY NAME (2/5)";
                        if (setupModalRoot.currentStep === 3) return "🔑 APP PASSWORD (3/5)";
                        if (setupModalRoot.currentStep === 4) return "📥 INCOMING SERVER (4/5)";
                        return "📤 OUTGOING SERVER (5/5)";
                    }
                    font.bold: true
                    font.pixelSize: setupModalRoot.overlayFontSize
                    color: setupModalRoot.base05
                    Layout.fillWidth: true
                }
                Text {
                    visible: setupModalRoot.currentStep > 0
                    text: setupModalRoot.currentStep + " of 5"
                    font.pixelSize: setupModalRoot.overlayFontSize - 3
                    color: "#888"
                }
            }

            Text {
                text: {
                    if (setupModalRoot.currentStep === 0) return "Enter your sudo password to install packages:";
                    if (setupModalRoot.currentStep === 1) return "Enter your primary email address:";
                    if (setupModalRoot.currentStep === 2) return "Enter your name as shown to email recipients:";
                    if (setupModalRoot.currentStep === 3) return "Enter your generated App Password:";
                    if (setupModalRoot.currentStep === 4) return "Confirm your incoming IMAP server host & port:";
                    return "Confirm your outgoing SMTP server host & port:";
                }
                font.pixelSize: setupModalRoot.overlayFontSize - 2
                color: setupModalRoot.base06
            }

            Item {
                width: parent.width; height: 44

                Rectangle {
                    anchors.fill: parent; visible: setupModalRoot.currentStep === 0
                    color: setupModalRoot.base00; border.color: sudoField.activeFocus ? setupModalRoot.innerBorderColor : setupModalRoot.base03; border.width: 1.5; radius: 6
                    TextInput {
                        id: sudoField; anchors.fill: parent; anchors.margins: 10
                        font.pixelSize: setupModalRoot.overlayFontSize; color: setupModalRoot.base06
                        echoMode: TextInput.Password; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                        enabled: !setupModalRoot.isInstalling
                        Keys.onPressed: (event) => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { setupModalRoot.runInstallCheck(text); event.accepted = true; } }
                        Text { text: "Enter sudo password..."; color: "#666"; visible: parent.text === ""; font.pixelSize: setupModalRoot.overlayFontSize; verticalAlignment: Text.AlignVCenter; anchors.fill: parent }
                    }
                }

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
                        Text { text: "e.g. user@gmail.com"; color: "#666"; visible: parent.text === ""; font.pixelSize: setupModalRoot.overlayFontSize; verticalAlignment: Text.AlignVCenter; anchors.fill: parent }
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
                        Text { text: "e.g. Alice Smith"; color: "#666"; visible: parent.text === ""; font.pixelSize: setupModalRoot.overlayFontSize; verticalAlignment: Text.AlignVCenter; anchors.fill: parent }
                    }
                }

                Rectangle {
                    anchors.fill: parent; visible: setupModalRoot.currentStep === 3
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
                            Text { text: "16-character App Password..."; color: "#666"; visible: parent.text === ""; font.pixelSize: setupModalRoot.overlayFontSize; verticalAlignment: Text.AlignVCenter; anchors.fill: parent }
                        }
                        Rectangle {
                            width: 30; height: 30; radius: 4; color: "transparent"
                            Text { anchors.centerIn: parent; text: setupModalRoot.showPassword ? "🙈" : "👁"; font.pixelSize: 15 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: setupModalRoot.showPassword = !setupModalRoot.showPassword }
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
                visible: setupModalRoot.currentStep === 3 && setupModalRoot.providerHelpUrl !== ""
                width: parent.width; height: 30; radius: 6
                color: helpBtnMouse.containsMouse ? setupModalRoot.innerBorderColor : setupModalRoot.base02
                border.color: setupModalRoot.innerBorderColor; border.width: 1

                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text {
                        text: setupModalRoot.providerBtnLabel
                        font.bold: true; font.pixelSize: 11
                        color: helpBtnMouse.containsMouse ? "#000000" : setupModalRoot.base05
                    }
                }

                MouseArea {
                    id: helpBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally(setupModalRoot.providerHelpUrl)
                }
            }

            Text {
                text: {
                    if (setupModalRoot.statusMsg !== "") return setupModalRoot.statusMsg;
                    if (setupModalRoot.currentStep === 0) return "Sudo access verifies credentials and installs required packages.";
                    if (setupModalRoot.currentStep === 3) return setupModalRoot.providerInstructions;
                    if (setupModalRoot.currentStep === 4) return "💡 Default IMAP SSL port is 993.";
                    if (setupModalRoot.currentStep === 5) return "💡 Default SMTP SSL port is 465 (or 587 for STARTTLS).";
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
                    width: 120; height: 32; radius: 6; color: setupModalRoot.base05
                    enabled: !setupModalRoot.isInstalling
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (setupModalRoot.currentStep === 0) return setupModalRoot.isInstalling ? "Installing..." : "Confirm";
                            if (setupModalRoot.currentStep === 5) return "Finish & Save ✔";
                            return "Next ➔";
                        }
                        color: "#11111b"; font.bold: true; font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (setupModalRoot.currentStep === 0) setupModalRoot.runInstallCheck(sudoField.text);
                            else setupModalRoot.nextStep();
                        }
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
