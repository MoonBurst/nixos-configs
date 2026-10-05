import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import "../../../settings"
import "../../../style" as Style

Item {
    id: root
    required property var panelRoot
    required property var guiColorPicker

    readonly property var settingsManager: panelRoot.settingsManager
    readonly property var shell: panelRoot.shell

    property string pickerTarget: "receive"
    property bool inAppBrowserOpen: false
    property string currentBrowseDir: Quickshell.env("HOME") || "/home"

    Layout.fillWidth: true
    implicitWidth: mainCol.implicitWidth
    implicitHeight: mainCol.implicitHeight

    ListModel { id: dirModel }

    Process {
        id: dirLister
        command: [
            "sh", "-c",
            'D="$1"; [ -d "$D" ] || D="$HOME"; ' +
            'printf "..|dir\n"; ' +
            'find "$D" -maxdepth 1 -mindepth 1 -printf "%f|%y\n" 2>/dev/null | sort -t"|" -k2,2r -k1,1'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                dirModel.clear();
                var lines = (text || "").split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split("|");
                    if (p.length === 2 && p[0] !== "") {
                        var isDir = (p[1] === "d" || p[0] === "..");
                        var isAudio = !isDir && (p[0].endsWith(".wav") || p[0].endsWith(".ogg") || p[0].endsWith(".oga") || p[0].endsWith(".mp3") || p[0].endsWith(".flac"));
                        if (isDir || isAudio) {
                            dirModel.append({ "name": p[0], "isDir": isDir });
                        }
                    }
                }
            }
        }
    }

    function openInAppBrowser(target) {
        pickerTarget = target;
        inAppBrowserOpen = true;
        refreshDir(currentBrowseDir);
    }

    function refreshDir(d) {
        currentBrowseDir = d;
        dirLister.command = [
            "sh", "-c",
            'D="$1"; [ -d "$D" ] || D="$HOME"; ' +
            'printf "..|dir\n"; ' +
            'find "$D" -maxdepth 1 -mindepth 1 -printf "%f|%y\n" 2>/dev/null | sort -t"|" -k2,2r -k1,1',
            "sh", d
        ];
        dirLister.running = false;
        dirLister.running = true;
    }

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        spacing: 18

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
                width: 36; height: 36; radius: 6
                color: (settingsManager && settingsManager.notifBorderColor) ? settingsManager.notifBorderColor : panelRoot.liveBase05
                border.width: panelRoot.liveControlBorderWidth
                border.color: "#ffffff"
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
                height: Math.max(38, panelRoot.liveFontSize * 2.2)
                radius: 8
                color: panelRoot.liveBase00
                border.color: panelRoot.liveBase03
                border.width: panelRoot.liveControlBorderWidth

                TextInput {
                    id: customIconInput
                    anchors.fill: parent
                    anchors.margins: 10
                    color: panelRoot.liveBase05
                    font.pixelSize: panelRoot.liveFontSize - 1
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
                height: Math.max(40, panelRoot.liveFontSize * 2.3)
                radius: 8
                color: panelRoot.liveBase00
                border.color: panelRoot.liveBase03
                border.width: panelRoot.liveControlBorderWidth

                TextInput {
                    id: ttsKeywordsInput
                    anchors.fill: parent
                    anchors.margins: 10
                    color: panelRoot.liveBase05
                    font.pixelSize: panelRoot.liveFontSize - 1
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
                height: Math.max(40, panelRoot.liveFontSize * 2.3)
                radius: 8
                color: panelRoot.liveBase00
                border.color: panelRoot.liveBase03
                border.width: panelRoot.liveControlBorderWidth

                TextInput {
                    id: excludedStrInput
                    anchors.fill: parent
                    anchors.margins: 10
                    color: panelRoot.liveBase05
                    font.pixelSize: panelRoot.liveFontSize - 1
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
                    font.pixelSize: Math.max(13, panelRoot.liveFontSize)
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
                        width: scrText.implicitWidth + 28
                        height: Math.max(34, panelRoot.liveFontSize * 2.0)
                        radius: 6
                        color: isSelected ? panelRoot.liveBase05 : panelRoot.liveBase02
                        border.color: panelRoot.liveBase05
                        border.width: panelRoot.liveControlBorderWidth

                        Text {
                            id: scrText
                            anchors.centerIn: parent
                            text: modelData
                            font.bold: true
                            font.pixelSize: Math.max(12, panelRoot.liveFontSize - 2)
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
                implicitWidth: toastBtnRow.implicitWidth + 32
                implicitHeight: Math.max(36, panelRoot.liveFontSize * 2.1)
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                radius: 8
                color: testNotifHov.hovered ? panelRoot.liveBase0C : "transparent"
                border.color: panelRoot.liveBase0C
                border.width: panelRoot.liveControlBorderWidth

                Row {
                    id: toastBtnRow
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "🔔"
                        font.pixelSize: Math.max(14, panelRoot.liveFontSize)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "3-Toast Preview"
                        font.bold: true
                        font.pixelSize: Math.max(12, panelRoot.liveFontSize - 2)
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

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: panelRoot.liveBase03
        }

        // EMAIL SETTINGS: SOUNDS, LIMITS & CHIMES
        Text {
            text: "✉️ EMAIL OPTIONS: SOUNDS, ALERTS & SYNC LIMITS"
            font.pixelSize: panelRoot.liveFontSize + 2
            font.bold: true
            color: panelRoot.liveBase0C
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Text {
                text: "Max Emails to Download:"
                font.bold: true
                color: panelRoot.liveBase05
                font.pixelSize: panelRoot.liveFontSize
                Layout.alignment: Qt.AlignVCenter
            }

            Row {
                spacing: 10
                Repeater {
                    model: [
                        { id: "50", label: "50" },
                        { id: "100", label: "100" },
                        { id: "500", label: "500" },
                        { id: "all", label: "All" }
                    ]
                    delegate: Rectangle {
                        readonly property bool isSelected: (settingsManager ? settingsManager.emailFetchLimit : "50") === modelData.id
                        width: lText.implicitWidth + 32
                        height: Math.max(36, panelRoot.liveFontSize * 2.2)
                        radius: 8
                        color: isSelected ? panelRoot.liveBase05 : panelRoot.liveBase00
                        border.color: panelRoot.liveBase05
                        border.width: isSelected ? panelRoot.liveControlBorderWidth : 1

                        Text {
                            id: lText
                            anchors.centerIn: parent
                            text: modelData.label
                            font.bold: true
                            font.pixelSize: Math.max(13, panelRoot.liveFontSize)
                            color: isSelected ? panelRoot.liveBase00 : panelRoot.liveBase05
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (settingsManager) settingsManager.emailFetchLimit = modelData.id
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Email Receive Sound File:"
                font.bold: true
                color: panelRoot.liveBase05
                font.pixelSize: panelRoot.liveFontSize - 1
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: Math.max(42, panelRoot.liveFontSize * 2.4)
                    radius: 8
                    color: panelRoot.liveBase00
                    border.color: panelRoot.liveBase03
                    border.width: panelRoot.liveControlBorderWidth

                    TextInput {
                        anchors.fill: parent
                        anchors.margins: 10
                        color: panelRoot.liveBase05
                        font.pixelSize: Math.max(13, panelRoot.liveFontSize - 1)
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        text: settingsManager ? settingsManager.emailReceiveSound : ""
                        onTextEdited: if (settingsManager) settingsManager.emailReceiveSound = text
                    }
                }

                Rectangle {
                    width: browseRText.implicitWidth + 28
                    height: Math.max(42, panelRoot.liveFontSize * 2.4)
                    radius: 8
                    color: bRMouse.containsMouse ? panelRoot.liveBase05 : panelRoot.liveBase02
                    border.color: panelRoot.liveBase05
                    border.width: panelRoot.liveControlBorderWidth

                    Text {
                        id: browseRText
                        anchors.centerIn: parent
                        text: "📁 Browse..."
                        font.bold: true
                        font.pixelSize: Math.max(12, panelRoot.liveFontSize - 2)
                        color: bRMouse.containsMouse ? panelRoot.liveBase00 : panelRoot.liveBase05
                    }
                    MouseArea {
                        id: bRMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.openInAppBrowser("receive")
                    }
                }

                Rectangle {
                    width: testRText.implicitWidth + 28
                    height: Math.max(42, panelRoot.liveFontSize * 2.4)
                    radius: 8
                    color: tRMouse.containsMouse ? panelRoot.liveBase0C : panelRoot.liveBase02
                    border.color: panelRoot.liveBase0C
                    border.width: panelRoot.liveControlBorderWidth

                    Text {
                        id: testRText
                        anchors.centerIn: parent
                        text: "▶ Test Sound"
                        font.bold: true
                        font.pixelSize: Math.max(12, panelRoot.liveFontSize - 2)
                        color: tRMouse.containsMouse ? "#000000" : panelRoot.liveBase0C
                    }
                    MouseArea {
                        id: tRMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            var p = settingsManager ? settingsManager.emailReceiveSound : "";
                            if (p !== "") Quickshell.execDetached(["pw-play", p]);
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Email Send Sound File:"
                font.bold: true
                color: panelRoot.liveBase05
                font.pixelSize: panelRoot.liveFontSize - 1
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: Math.max(42, panelRoot.liveFontSize * 2.4)
                    radius: 8
                    color: panelRoot.liveBase00
                    border.color: panelRoot.liveBase03
                    border.width: panelRoot.liveControlBorderWidth

                    TextInput {
                        anchors.fill: parent
                        anchors.margins: 10
                        color: panelRoot.liveBase05
                        font.pixelSize: Math.max(13, panelRoot.liveFontSize - 1)
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        text: settingsManager ? settingsManager.emailSendSound : ""
                        onTextEdited: if (settingsManager) settingsManager.emailSendSound = text
                    }
                }

                Rectangle {
                    width: browseSText.implicitWidth + 28
                    height: Math.max(42, panelRoot.liveFontSize * 2.4)
                    radius: 8
                    color: bSMouse.containsMouse ? panelRoot.liveBase05 : panelRoot.liveBase02
                    border.color: panelRoot.liveBase05
                    border.width: panelRoot.liveControlBorderWidth

                    Text {
                        id: browseSText
                        anchors.centerIn: parent
                        text: "📁 Browse..."
                        font.bold: true
                        font.pixelSize: Math.max(12, panelRoot.liveFontSize - 2)
                        color: bSMouse.containsMouse ? panelRoot.liveBase00 : panelRoot.liveBase05
                    }
                    MouseArea {
                        id: bSMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.openInAppBrowser("send")
                    }
                }

                Rectangle {
                    width: testSText.implicitWidth + 28
                    height: Math.max(42, panelRoot.liveFontSize * 2.4)
                    radius: 8
                    color: tSMouse.containsMouse ? panelRoot.liveBase0C : panelRoot.liveBase02
                    border.color: panelRoot.liveBase0C
                    border.width: panelRoot.liveControlBorderWidth

                    Text {
                        id: testSText
                        anchors.centerIn: parent
                        text: "▶ Test Sound"
                        font.bold: true
                        font.pixelSize: Math.max(12, panelRoot.liveFontSize - 2)
                        color: tSMouse.containsMouse ? "#000000" : panelRoot.liveBase0C
                    }
                    MouseArea {
                        id: tSMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            var p = settingsManager ? settingsManager.emailSendSound : "";
                            if (p !== "") Quickshell.execDetached(["pw-play", p]);
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: fileBrowserModal
        visible: root.inAppBrowserOpen
        z: 99999
        anchors.fill: parent
        color: "#F0000000"

        MouseArea { anchors.fill: parent }

        Rectangle {
            width: Math.min(parent.width - 40, 680)
            height: Math.min(parent.height - 40, 560)
            anchors.centerIn: parent
            radius: 14
            color: panelRoot.liveBase00
            border.color: panelRoot.liveBase05
            border.width: panelRoot.liveControlBorderWidth

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "📁 Select Sound File (" + root.pickerTarget.toUpperCase() + ")"
                        font.bold: true; font.pixelSize: 17; color: panelRoot.liveBase05
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 32; height: 32; radius: 6; color: "transparent"; border.color: "#ff5555"; border.width: 1.5
                        Text { anchors.centerIn: parent; text: "✕"; color: "#ff5555"; font.bold: true; font.pixelSize: 15 }
                        MouseArea { anchors.fill: parent; onClicked: root.inAppBrowserOpen = false }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "Quick Presets:"; font.bold: true; font.pixelSize: 13; color: panelRoot.liveBase05 }
                    Repeater {
                        model: [
                            { name: "🔔 Bell", path: "/usr/share/sounds/freedesktop/stereo/bell.oga" },
                            { name: "📨 Message", path: "/usr/share/sounds/freedesktop/stereo/message.oga" },
                            { name: "✨ Complete", path: "/usr/share/sounds/freedesktop/stereo/complete.oga" }
                        ]
                        delegate: Rectangle {
                            width: pTxt.implicitWidth + 20; height: 32; radius: 6
                            color: panelRoot.liveBase02; border.color: panelRoot.liveBase0C; border.width: panelRoot.liveControlBorderWidth
                            Text { id: pTxt; anchors.centerIn: parent; text: modelData.name; font.pixelSize: 12; font.bold: true; color: panelRoot.liveBase0C }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (settingsManager) {
                                        if (root.pickerTarget === "receive") settingsManager.emailReceiveSound = modelData.path;
                                        else settingsManager.emailSendSound = modelData.path;
                                    }
                                    Quickshell.execDetached(["pw-play", modelData.path]);
                                    root.inAppBrowserOpen = false;
                                }
                            }
                        }
                    }
                }

                Text {
                    text: "Directory: " + root.currentBrowseDir
                    font.family: "monospace"; font.pixelSize: 12; color: "#aaa"
                    elide: Text.ElideMiddle; Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: panelRoot.liveBase02; radius: 8; border.color: panelRoot.liveBase03; border.width: panelRoot.liveControlBorderWidth
                    clip: true

                    ListView {
                        id: browserList
                        anchors.fill: parent; anchors.margins: 8
                        model: dirModel
                        spacing: 6

                        delegate: Rectangle {
                            width: browserList.width; height: 36; radius: 6
                            color: itemHover.hovered ? panelRoot.liveBase03 : "transparent"

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 8; spacing: 10
                                Text { text: model.isDir ? "📁" : "🎵"; font.pixelSize: 16 }
                                Text {
                                    text: model.name
                                    font.family: "monospace"; font.pixelSize: 13
                                    color: model.isDir ? panelRoot.liveBase05 : panelRoot.liveBase0C
                                    font.bold: model.isDir
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }

                            HoverHandler { id: itemHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (model.isDir) {
                                        if (model.name === "..") {
                                            var parentDir = root.currentBrowseDir.replace(/\/[^\/]+\/?$/, "");
                                            root.refreshDir(parentDir === "" ? "/" : parentDir);
                                        } else {
                                            root.refreshDir(root.currentBrowseDir.replace(/\/$/, "") + "/" + model.name);
                                        }
                                    } else {
                                        var fullPath = root.currentBrowseDir.replace(/\/$/, "") + "/" + model.name;
                                        if (settingsManager) {
                                            if (root.pickerTarget === "receive") settingsManager.emailReceiveSound = fullPath;
                                            else settingsManager.emailSendSound = fullPath;
                                        }
                                        Quickshell.execDetached(["pw-play", fullPath]);
                                        root.inAppBrowserOpen = false;
                                    }
                                }
                            }
                        }
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }
                }
            }
        }
    }
}
