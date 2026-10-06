import "../../common/Utils.js" as Utils
import "../../style" as Style
import QtQuick
import QtQuick.Controls 2
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io

Item {
    id: historyEngine

    property bool showHistoryMode: false
    property var rulesLoader: null
    property var rootItem: null
    property var controller: null

    readonly property var safePad: Utils.getSafeCardPadding(shell ? shell.settingsManager : null)

    property var actionTargetsMap: ({})
    property alias historyModel: historyNotificationsModel

    Shortcut {
        sequence: "Escape"
        enabled: historyEngine.showHistoryMode
        onActivated: {
            if (historyEngine.rootItem) {
                historyEngine.rootItem.showHistoryMode = false;
            }
        }
    }

    ListModel {
        id: historyNotificationsModel
    }

    function extractUrl(text) {
        return Utils.extractUrl(text);
    }

    function getCleanHistoryBody(rawBody) {
        if (!rawBody) return "";
        var cleanBody = rawBody.trim();
        var url = historyEngine.extractUrl(cleanBody);
        if (url !== "") {
            var stripped = cleanBody.replace(url, "").trim();
            if (stripped.endsWith(":") || stripped.endsWith(": ")) {
                stripped = stripped.substring(0, stripped.length - 1).trim();
            }
            if (stripped === "" || stripped.toLowerCase() === "uploaded image" || stripped.toLowerCase() === "uploaded") {
                return "Uploaded attachment";
            }
            return stripped;
        }
        return rawBody;
    }

    function recordHistory(expiredEntry) {
        if (!expiredEntry) return;

        let appNameLower = (expiredEntry.appName || "").toLowerCase();
        let summaryLower = (expiredEntry.summary || "").toLowerCase();
        let bodyLower = (expiredEntry.body || "").toLowerCase();
        let avatarVal = expiredEntry.avatarSource || "";

        let avatarSourceLower = avatarVal ? avatarVal.toString().toLowerCase() : "";
        let isMicNotif = appNameLower.includes("microphone") || appNameLower.includes("mic") ||
        summaryLower.includes("microphone") || summaryLower.includes("mic") ||
        bodyLower.includes("microphone") || bodyLower.includes("mic") ||
        avatarSourceLower.includes("microphone") || avatarSourceLower.includes("mic");

        if (!isMicNotif) {
            if (avatarVal === "" && expiredEntry.summary !== "") {
                for (let i = 0; i < historyNotificationsModel.count; i++) {
                    let past = historyNotificationsModel.get(i);
                    if (past && past.summary === expiredEntry.summary && past.avatarSource && past.avatarSource !== "") {
                        avatarVal = past.avatarSource;
                        break;
                    }
                }
            }

            actionTargetsMap[expiredEntry.notifId] = expiredEntry.appName || "";

            historyNotificationsModel.insert(0, {
                "notifId": expiredEntry.notifId,
                "summary": expiredEntry.summary,
                "body": expiredEntry.body,
                "appName": expiredEntry.appName,
                "timestamp": new Date().toLocaleTimeString(Qt.locale(), "hh:mm AP"),
                                             "avatarSource": avatarVal,
                                             "previewSource": expiredEntry.previewSource || ""
            });

            while (historyNotificationsModel.count > 50) {
                let lastItem = historyNotificationsModel.get(historyNotificationsModel.count - 1);
                if (lastItem && lastItem.notifId) {
                    delete actionTargetsMap[lastItem.notifId];
                    if (lastItem.avatarSource && lastItem.avatarSource.startsWith("file:///tmp/qs_avatar_")) {
                        var filePath = lastItem.avatarSource.replace(/^file:\/\//, "");
                        Quickshell.execDetached(["rm", "-f", filePath]);
                    }
                }
                historyNotificationsModel.remove(historyNotificationsModel.count - 1);
            }
        }
    }

    PanelWindow {
        id: historyWindow

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        screen: Quickshell.screens.find(s => s.name === "DP-1")
        || Quickshell.screens.find(s => s.name.startsWith("eDP"))
        || Quickshell.screens[0]

        visible: historyEngine.showHistoryMode
        color: "transparent"

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay

        onVisibleChanged: {
            if (visible) {
                if (typeof historyListView !== "undefined" && historyListView) {
                    Qt.callLater(function() {
                        historyListView.currentIndex = 0;
                        historyListView.positionViewAtIndex(0, ListView.Beginning);
                        historyListView.forceActiveFocus();
                    });
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (historyEngine.rootItem) {
                    historyEngine.rootItem.showHistoryMode = false;
                }
            }
        }

        Style.ShapeBox {
            id: historyPanel
            width: 1500
            height: 900
            anchors.centerIn: parent
            role: "card"
            color: shell.theme.base00 || "#11111b"
            borderColor: shell.theme.base03 || "#45475a"
            borderWidth: shell.theme.globalBorderWidth || 3

            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: false
                onPressed: (mouse) => {
                    mouse.accepted = true;
                    if (typeof historyListView !== "undefined" && historyListView) {
                        historyListView.forceActiveFocus();
                    }
                }
                onReleased: (mouse) => mouse.accepted = true
                onClicked: (mouse) => mouse.accepted = true
            }

            Column {
                anchors.fill: parent
                // Inset safely inside the card's chamfer to prevent clipping "Clear"
                anchors.leftMargin: Math.max(28, historyEngine.safePad.h)
                anchors.rightMargin: Math.max(28, historyEngine.safePad.h)
                anchors.topMargin: Math.max(20, historyEngine.safePad.v)
                anchors.bottomMargin: Math.max(20, historyEngine.safePad.v)
                spacing: 16

                Item {
                    width: parent.width
                    height: 38

                    Text {
                        text: "📜 Notification History"
                        color: shell.theme.base05 || "#cdd6f4"
                        font.family: shell.theme.fontFamily || "monospace"
                        font.pixelSize: 20
                        font.bold: true
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Styled pill button kept inside the safe chamfer boundary
                    Item {
                        id: clearBtnContainer
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: clearBtnText.implicitWidth + 24
                        height: 32

                        Style.ShapeBox {
                            anchors.fill: parent
                            role: "input"
                            slantWidth: 6
                            color: clearMouse.containsMouse ? (shell.theme.base08 || "#ff5555") : "transparent"
                            borderColor: clearMouse.containsMouse ? (shell.theme.base08 || "#ff5555") : (shell.theme.base05 || "#cdd6f4")
                            borderWidth: shell.theme.controlBorderWidth || 2
                        }

                        Text {
                            id: clearBtnText
                            anchors.centerIn: parent
                            text: "Clear"
                            color: clearMouse.containsMouse ? "#000000" : (shell.theme.base05 || "#cdd6f4")
                            font.family: shell.theme.fontFamily || "monospace"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                historyNotificationsModel.clear();
                                historyEngine.actionTargetsMap = {};
                                Quickshell.execDetached(["sh", "-c", 'rm -f "${XDG_RUNTIME_DIR:-/tmp}"/qs_avatar_notif_*.png 2>/dev/null || true']);
                                if (typeof historyListView !== "undefined" && historyListView) {
                                    historyListView.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                ListView {
                    id: historyListView
                    width: parent.width
                    height: parent.height - 60
                    model: historyNotificationsModel
                    spacing: 12
                    clip: true

                    focus: true
                    keyNavigationEnabled: true
                    highlightFollowsCurrentItem: true
                    verticalLayoutDirection: ListView.BottomToTop

                    highlightMoveDuration: 0
                    highlightResizeDuration: 0
                    boundsBehavior: Flickable.StopAtBounds

                    onActiveFocusChanged: {
                        if (!activeFocus && historyEngine.showHistoryMode) {
                            historyListView.forceActiveFocus();
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            if (historyEngine.rootItem) {
                                historyEngine.rootItem.showHistoryMode = false;
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            let targetUp = currentIndex + 1;
                            if (targetUp >= count) targetUp = count - 1;
                            currentIndex = targetUp;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            let targetDown = currentIndex - 1;
                            if (targetDown < 0) targetDown = 0;
                            currentIndex = targetDown;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete) {
                            if (currentIndex !== -1 && currentIndex < count) {
                                let targetItem = historyNotificationsModel.get(currentIndex);
                                if (targetItem) {
                                    delete historyEngine.actionTargetsMap[targetItem.notifId];
                                    if (targetItem.avatarSource && targetItem.avatarSource.startsWith("file://")) {
                                        Quickshell.execDetached(["rm", "-f", targetItem.avatarSource.replace(/^file:\/\//, "")]);
                                    }
                                }
                                historyNotificationsModel.remove(currentIndex);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (currentIndex !== -1 && currentIndex < count) {
                                var item = historyNotificationsModel.get(currentIndex);
                                if (item) {
                                    var url = historyEngine.extractUrl(item.body ? item.body : "");
                                    if (url !== "") {
                                        Qt.openUrlExternally(url);
                                    }

                                    if (historyEngine.controller) {
                                        historyEngine.controller.activate(
                                            null,
                                            item.summary,
                                            item.body,
                                            item.appName,
                                            null
                                        );
                                    }
                                }
                            }
                            event.accepted = true;
                        }
                    }

                    delegate: Item {
                        id: delegateRoot
                        width: historyListView.width
                        property string asyncPreviewSource: ""
                        property bool hasRightPreview: (previewSource && previewSource !== "") || (asyncPreviewSource !== "")

                        property bool isBodyOnlyUrl: {
                            if (!body) return false;
                            var cleanBody = body.trim();
                            var url = historyEngine.extractUrl(cleanBody);
                            return cleanBody === url;
                        }

                        height: hasRightPreview ? 450 : 180

                        // Adopts the selected shape theme (Hexagon, Rounded, etc.)
                        Style.ShapeBox {
                            id: delegateBg
                            anchors.fill: parent
                            role: "input"
                            color: shell.theme.base01 || "#1e1e2e"
                            borderColor: ListView.isCurrentItem
                            ? (shell.theme.base05 || "#cdd6f4")
                            : (shell.theme.base03 || "#45475a")
                            borderWidth: ListView.isCurrentItem
                            ? (shell.theme.globalBorderWidth || 3)
                            : (shell.theme.controlBorderWidth || 1)
                            slantWidth: 10
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                historyListView.currentIndex = index;
                                historyListView.forceActiveFocus();
                            }
                        }

                        function fetchAsyncPreviewNative(url) {
                            if (!url) return;
                            if (url.match(/\.(?:png|jpg|jpeg|gif|svg|webp)\b/i)) {
                                delegateRoot.asyncPreviewSource = url;
                            }
                        }

                        Component.onCompleted: {
                            if (!previewSource || previewSource === "") {
                                var linkUrl = historyEngine.extractUrl(body ? body : "");
                                if (linkUrl !== "") {
                                    delegateRoot.fetchAsyncPreviewNative(linkUrl);
                                }
                            }
                        }

                        // Close button positioned inside safe insets
                        Text {
                            id: deleteItemBtn
                            text: "✕"
                            font.pixelSize: 18
                            font.bold: true
                            color: deleteMouse.containsMouse ? (shell.theme.base08 || "#ff5555") : (shell.theme.base05 || "#cdd6f4")
                            opacity: deleteMouse.containsMouse ? 1.0 : 0.6
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: Math.max(12, delegateBg.topPadding)
                            anchors.rightMargin: Math.max(16, delegateBg.rightPadding)
                            z: 10

                            MouseArea {
                                id: deleteMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    let item = historyNotificationsModel.get(index);
                                    if (item) {
                                        delete historyEngine.actionTargetsMap[item.notifId];
                                        if (item.avatarSource && item.avatarSource.startsWith("file://")) {
                                            Quickshell.execDetached(["rm", "-f", item.avatarSource.replace(/^file:\/\//, "")]);
                                        }
                                    }
                                    historyNotificationsModel.remove(index);
                                    historyListView.forceActiveFocus();
                                }
                            }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Math.max(16, delegateBg.leftPadding)
                            anchors.rightMargin: Math.max(40, delegateBg.rightPadding + 20)
                            anchors.topMargin: Math.max(14, delegateBg.topPadding)
                            anchors.bottomMargin: Math.max(14, delegateBg.bottomPadding)
                            spacing: 20

                            Image {
                                id: delegateAvatar
                                width: 140
                                height: 140
                                anchors.verticalCenter: parent.verticalCenter
                                source: avatarSource ? avatarSource : ""
                                visible: source !== ""
                                fillMode: Image.PreserveAspectFit
                            }

                            Column {
                                width: parent.width - (delegateAvatar.visible ? 160 : 0)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: summary ? summary : ""
                                    color: shell.theme.base05 || "#cdd6f4"
                                    font.bold: true
                                    font.pixelSize: 20
                                    font.family: shell.theme.fontFamily || "monospace"
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    visible: text !== "" && !delegateRoot.isBodyOnlyUrl
                                    text: body ? historyEngine.getCleanHistoryBody(body) : ""
                                    color: shell.theme.base05 || "#cdd6f4"
                                    font.pixelSize: 18
                                    font.family: shell.theme.fontFamily || "monospace"
                                    wrapMode: Text.Wrap
                                    maximumLineCount: delegateRoot.hasRightPreview ? 2 : 3
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Image {
                                    id: delegatePreviewImage
                                    width: parent.width - 40
                                    height: 220
                                    fillMode: Image.PreserveAspectFit
                                    horizontalAlignment: Image.AlignLeft
                                    visible: delegateRoot.hasRightPreview

                                    source: {
                                        if (delegateRoot.asyncPreviewSource && delegateRoot.asyncPreviewSource !== "") {
                                            return delegateRoot.asyncPreviewSource;
                                        }
                                        if (previewSource && previewSource !== "") {
                                            return previewSource;
                                        }
                                        return "";
                                    }
                                }

                                Item {
                                    id: linkPreviewBox
                                    width: parent.width - 40
                                    height: 35
                                    visible: extractedUrl !== "" && !delegateRoot.hasRightPreview

                                    property string extractedUrl: historyEngine.extractUrl(body ? body : "")

                                    Style.ShapeBox {
                                        anchors.fill: parent
                                        role: "input"
                                        color: shell.theme.base02 || "#313244"
                                        borderColor: shell.theme.base03 || "#45475a"
                                        borderWidth: shell.theme.controlBorderWidth || 1
                                        slantWidth: 6
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 8
                                        Text {
                                            text: "🔗"
                                            color: shell.theme.base05 || "#cdd6f4"
                                            font.pixelSize: 18
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: linkPreviewBox.extractedUrl
                                            color: shell.theme.base05 || "#cdd6f4"
                                            font.pixelSize: 16
                                            font.family: shell.theme.fontFamily || "monospace"
                                            elide: Text.ElideRight
                                            width: parent.width - 40
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Qt.openUrlExternally(linkPreviewBox.extractedUrl);
                                            historyListView.forceActiveFocus();
                                        }
                                    }
                                }

                                Text {
                                    text: timestamp ? timestamp : ""
                                    color: shell.theme.base05 || "#cdd6f4"
                                    font.pixelSize: 16
                                    font.family: shell.theme.fontFamily || "monospace"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
