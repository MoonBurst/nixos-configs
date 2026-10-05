import "../../common" as Common
import "../../common/Utils.js" as Utils
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

    // Store only lightweight string target names to prevent pinning C++ QObjects in memory
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

            // Store purely string target mapping to prevent C++ QObject leaks
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

            // Strict FIFO limit to prevent unbounded RAM growth
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

        Rectangle {
            id: historyPanel
            width: 1500
            height: 900
            anchors.centerIn: parent
            radius: 16
            color: shell.theme.base00 || "#11111b"
            border.width: shell.theme.globalBorderWidth || 3
            border.color: shell.theme.base03 || "#45475a"
            clip: true

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
                anchors.margins: 24
                spacing: 16

                Item {
                    width: parent.width
                    height: 35

                    Text {
                        text: "📜 Notification History"
                        color: shell.theme.base05 || "#cdd6f4"
                        font.family: shell.theme.fontFamily || "monospace"
                        font.pixelSize: 20
                        font.bold: true
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: clearBtn
                        text: "Clear"
                        color: shell.theme.base05 || "#cdd6f4"
                        font.family: shell.theme.fontFamily || "monospace"
                        font.pixelSize: 20
                        font.bold: true
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                historyNotificationsModel.clear();
                                historyEngine.actionTargetsMap = {};
                                Quickshell.execDetached(["sh", "-c", "rm -f /tmp/qs_avatar_notif_*.png 2>/dev/null || true"]);
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
                    height: parent.height - 55
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
                                    if (targetItem.avatarSource && targetItem.avatarSource.startsWith("file:///tmp/qs_avatar_")) {
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

                    delegate: Rectangle {
                        id: delegateRoot
                        width: parent ? parent.width : 0
                        property string asyncPreviewSource: ""
                        property bool hasRightPreview: (previewSource && previewSource !== "") || (asyncPreviewSource !== "")

                        property bool isBodyOnlyUrl: {
                            if (!body) return false;
                            var cleanBody = body.trim();
                            var url = historyEngine.extractUrl(cleanBody);
                            return cleanBody === url;
                        }

                        height: hasRightPreview ? 450 : 180
                        color: shell.theme.base01 || "#1e1e2e"
                        radius: 10

                        border.width: ListView.isCurrentItem ? 3 : 1
                        border.color: ListView.isCurrentItem ? (shell.theme.base05 || "#cdd6f4") : (shell.theme.base03 || "#45475a")

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

                        Text {
                            id: deleteItemBtn
                            text: "❌"
                            font.pixelSize: 20
                            color: shell.theme.base05 || "#cdd6f4"
                            opacity: 0.6
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 12
                            anchors.rightMargin: 14
                            z: 10

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: deleteItemBtn.opacity = 1.0
                                onExited: deleteItemBtn.opacity = 0.6
                                onClicked: {
                                    let item = historyNotificationsModel.get(index);
                                    if (item) {
                                        delete historyEngine.actionTargetsMap[item.notifId];
                                        if (item.avatarSource && item.avatarSource.startsWith("file:///tmp/qs_avatar_")) {
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
                            anchors.margins: 14
                            spacing: 20

                            Image {
                                id: delegateAvatar
                                width: 150
                                height: 150
                                anchors.verticalCenter: parent.verticalCenter
                                source: avatarSource ? avatarSource : ""
                                visible: source !== ""
                                fillMode: Image.PreserveAspectFit
                            }

                            Column {
                                width: parent ? parent.width - 200 : 0
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: summary ? summary : ""
                                    color: shell.theme.base05 || "#cdd6f4"
                                    font.bold: true
                                    font.pixelSize: 20
                                    font.family: shell.theme.fontFamily || "monospace"
                                    elide: Text.ElideRight
                                    width: parent ? parent.width : 0
                                }
                                Text {
                                    visible: text !== "" && !delegateRoot.isBodyOnlyUrl
                                    text: body ? historyEngine.getCleanHistoryBody(body) : ""
                                    color: shell.theme.base05 || "#cdd6f4"
                                    font.pixelSize: 20
                                    font.family: shell.theme.fontFamily || "monospace"
                                    wrapMode: Text.Wrap
                                    maximumLineCount: delegateRoot.hasRightPreview ? 2 : 3
                                    elide: Text.ElideRight
                                    width: parent ? parent.width : 0
                                }

                                Image {
                                    id: delegatePreviewImage
                                    width: parent ? parent.width - 40 : 0
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

                                Rectangle {
                                    id: linkPreviewBox
                                    width: parent.width - 40
                                    height: 35
                                    color: shell.theme.base02 || "#313244"
                                    radius: 6
                                    border.width: 1
                                    border.color: shell.theme.base03 || "#45475a"
                                    visible: extractedUrl !== "" && !delegateRoot.hasRightPreview

                                    property string extractedUrl: historyEngine.extractUrl(body ? body : "")

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 8
                                        Text {
                                            text: "🔗"
                                            color: shell.theme.base05 || "#cdd6f4"
                                            font.pixelSize: 20
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: linkPreviewBox.extractedUrl
                                            color: shell.theme.base05 || "#cdd6f4"
                                            font.pixelSize: 20
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
                                    font.pixelSize: 20
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
