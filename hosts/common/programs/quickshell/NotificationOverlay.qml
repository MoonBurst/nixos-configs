import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io

Scope {
    id: root

    property int currentTopCardId: -1
    property alias notificationModel: notifModel

    ListModel { id: notifModel }
    Process { id: swayActivator }
    Process { id: pipewireAudioPlayer }

    Timer {
        id: topCardQueueTimer
        interval: 2000
        running: notifModel.count > 0 && !notifModel.get(notifModel.count - 1).removing && !notifModel.get(notifModel.count - 1).isUrgent
        onTriggered: if (notifModel.count > 0) root.animateRemove(notifModel.get(notifModel.count - 1).notifId, false)
    }

    Component.onCompleted: notifModel.countChanged.connect(root.checkTopCardShift)

    function checkTopCardShift() {
        if (notifModel.count > 0) {
            let oldestCard = notifModel.get(notifModel.count - 1);
            if (oldestCard && oldestCard.notifId !== root.currentTopCardId) {
                root.currentTopCardId = oldestCard.notifId;
                if (!oldestCard.isUrgent) topCardQueueTimer.restart();
                else topCardQueueTimer.stop();
            }
        } else {
            root.currentTopCardId = -1;
            topCardQueueTimer.stop();
        }
    }

    function playCustomChimeTrack(absoluteFilePath) {
        try {
            pipewireAudioPlayer.running = false;
            pipewireAudioPlayer.command = ["sh", "-c", "pw-play " + absoluteFilePath + " &"];
            pipewireAudioPlayer.running = true;
        } catch (err) {}
    }

    function executeActionOnTarget(targetId, targetSummary) {
        try {
            if (targetSummary && targetSummary.length > 0) {
                let cleanUser = targetSummary.replace(/['"\\()\[\]]/g, "").trim();
                let channelMatch = cleanUser.match(/#([a-zA-Z0-9_-]+)/);
                let searchTarget = channelMatch ? channelMatch : cleanUser;

                swayActivator.running = false;
                swayActivator.command = [
                    Quickshell.env("NIXOS_SWAYMSG_PATH") || "swaymsg",
                    `[title="(?i)${searchTarget}"] focus`
                ];
                swayActivator.running = true;
            }
            root.animateRemove(targetId, true);
        } catch (err) {}
    }

    IpcHandler {
        id: shellIpc
        target: "global_notif"
        function jumpToLatest() {
            if (notifModel.count === 0) return;
            let topCard = notifModel.get(notifModel.count - 1);
            root.executeActionOnTarget(topCard.notifId, topCard.summary);
        }
        function dismissLatest() {
            if (notifModel.count > 0) root.animateRemove(notifModel.get(notifModel.count - 1).notifId, true)
        }
    }

    Component {
        id: removalTimerComponent
        Timer {
            property int targetId: -1
            interval: 240; running: true
            onTriggered: {
                for (let j = 0; j < notifModel.count; ++j) {
                    if (notifModel.get(j).notifId === targetId) { notifModel.remove(j); break; }
                }
                destroy();
            }
        }
    }

    function handleNotification(n) {
        if (!n) return;
        let iconSource = n.image ? n.image : (n.appIcon ? n.appIcon : "");
        let checkUrgent = (n.urgency === 2 || (n.hints && n.hints.urgency === 2));
        let resourcesPath = Quickshell.env("HOME") + "/nix/hosts/common/programs/quickshell/resources";
        let chosenCharacterColor = "";

        if (n.summary) {
            let sMatch = String(n.summary).toLowerCase().trim();
            const characters = [
                { name: "apogee",        match: "apogee",       color: "#0CD0CD", sound: false },
                { name: "solar_sonata",  match: "solarsonata",  color: "#f7f716", sound: true  },
                { name: "cageheart",     match: "cageheart",    color: "#8ad5a6", sound: true  },
                { name: "olivia",        match: "olivia",       color: "#18FFD5", sound: true  },
                { name: "genesis_frost", match: "genesisfrost", color: "#9ce8ff", sound: false },
                { name: "luster_dawn",   match: "luster",       color: "#e041de", sound: true  }
            ];
            for (let i = 0; i < characters.length; ++i) {
                let char = characters[i];
                if (sMatch.includes(char.match)) {
                    iconSource = `file://${resourcesPath}/${char.name}/${char.name}.png`;
                    chosenCharacterColor = char.color;
                    if (char.sound) root.playCustomChimeTrack(`${resourcesPath}/${char.name}/${char.name}.flac`);
                    break;
                }
            }
        }

        notifModel.insert(0, {
            notifId: Number(n.id),
                          summary: String(n.summary || ""),
                          body: String(n.body || ""),
                          icon: String(iconSource || ""),
                          removing: false,
                          freshArrival: true,
                          isUrgent: checkUrgent,
                          customBorderColor: chosenCharacterColor
        });

        Qt.callLater(() => { if (notifModel.count > 0) notifModel.setProperty(0, "freshArrival", false); });
        root.checkTopCardShift();
    }

    function animateRemove(id, isManualUserEject) {
        for (let i = 0; i < notifModel.count; ++i) {
            if (notifModel.get(i).notifId === id) {
                notifModel.setProperty(i, "removing", true);
                if (isManualUserEject) root.triggerVisualCardActionRed(id);
                removalTimerComponent.createObject(root, { "targetId": id });
                return;
            }
        }
    }

    signal triggerVisualCardActionRed(int targetNotifId)

    PanelWindow {
        id: overlayWindow
        visible: notifModel.count > 0
        implicitWidth: 480; implicitHeight: 500; color: "transparent"
        screen: Quickshell.screens.find(s => s.name === "DP-2") || Quickshell.screens
        anchors { top: true; right: true }
        margins { top: 100; right: 24 }

        Item {
            anchors.fill: parent
            Repeater {
                model: notifModel
                delegate: Rectangle {
                    id: card
                    required property int notifId
                    required property string summary
                    required property string body
                    required property string icon
                    required property bool removing
                    required property bool freshArrival
                    required property bool isUrgent
                    required property string customBorderColor
                    required property int index

                    property bool isUserTerminated: false

                    Connections {
                        target: root
                        function onTriggerVisualCardActionRed(targetNotifId) {
                            if (card.notifId === targetNotifId) card.isUserTerminated = true;
                        }
                    }

                    width: 480; height: 140; radius: 18
                    color: Quickshell.env("STYLIX_BASE00") || "#1a1a1a"
                    border.width: 5
                    border.color: isUserTerminated ? (Quickshell.env("STYLIX_BASE08") || "#FF0000") : (customBorderColor || (isUrgent ? (Quickshell.env("STYLIX_BASE08") || "#FF0000") : (Quickshell.env("STYLIX_BASE03") || "#003399")))
                    clip: true

                    x: removing ? 650 : (freshArrival ? 600 : 0)
                    y: ((notifModel.count - 1) - card.index) === 0 ? 100 : (100 + (((notifModel.count - 1) - card.index) * -(height * 0.1)))
                    z: -((notifModel.count - 1) - card.index)

                    Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        enabled: ((notifModel.count - 1) - card.index) === 0
                        onClicked: root.executeActionOnTarget(card.notifId, card.summary)
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 16
                        Rectangle {
                            id: iconContainer
                            Layout.preferredWidth: 100; Layout.preferredHeight: 100; radius: 50
                            color: Quickshell.env("STYLIX_BASE00") || "#1a1a1a"
                            border.width: 1; border.color: card.border.color; clip: true
                            Image { anchors.fill: parent; source: card.icon; fillMode: Image.PreserveAspectCrop; visible: card.icon !== "" }
                            Text { anchors.centerIn: parent; visible: !card.icon; text: "?"; font.pixelSize: 24; font.bold: true; color: Quickshell.env("STYLIX_BASE05") || "#F7F700" }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: card.summary
                                color: card.customBorderColor || Quickshell.env("STYLIX_BASE05") || "#F7F700"
                                font.pixelSize: 24
                                font.bold: true
                                elide: Text.ElideRight
                                clip: true
                                Layout.fillWidth: true
                            }

                            Text {
                                text: card.body
                                color: Quickshell.env("STYLIX_BASE05") || "#F7F700"
                                font.pixelSize: 20
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                clip: true
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
