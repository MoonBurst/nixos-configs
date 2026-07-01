// modules/overlays/notifications/NotificationHistory.qml
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

    // FIXED: Private JavaScript registry to store raw C++ QObjects securely without triggering ListModel role conflicts
    property var liveNotificationsMap: ({})

    // Expose the history model cleanly to parent bindings
    property alias historyModel: historyNotificationsModel

    // Window-level global shortcut: Guarantees Escape key always closes the history drawer
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

    // Decoupled URL Extraction Utilities
    readonly property var urlRegex: /(https?:\/\/[^\s<]+)/

    function extractUrl(text) {
        if (!text) return "";
        var match = text.match(urlRegex);
        return match ? match[0] : "";
    }

    // Cleans up trailing long raw URLs from body text inside the history list
    function getCleanHistoryBody(rawBody) {
        if (!rawBody) return "";
        var cleanBody = rawBody.trim();
        var url = historyEngine.extractUrl(cleanBody);
        if (url !== "") {
            var stripped = cleanBody.replace(url, "").trim();
            // Clean up trailing colons or remnants
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

    // Resolves and populates history roles immediately while the D-Bus handle is active
    function recordHistory(expiredEntry) {
        if (!expiredEntry) return;

        let appNameLower = (expiredEntry.appName || "").toLowerCase();
        let summaryLower = (expiredEntry.summary || "").toLowerCase();
        let bodyLower = (expiredEntry.body || "").toLowerCase();

        let notification = expiredEntry.cardRef ? expiredEntry.cardRef.notification : null;
        let avatarVal = expiredEntry.avatarSource || "";

        // Check if this is a microphone toggle notification
        let avatarSourceLower = avatarVal ? avatarVal.toString().toLowerCase() : "";
        let isMicNotif = appNameLower.includes("microphone") || appNameLower.includes("mic") ||
        summaryLower.includes("microphone") || summaryLower.includes("mic") ||
        bodyLower.includes("microphone") || bodyLower.includes("mic") ||
        avatarSourceLower.includes("microphone") || avatarSourceLower.includes("mic");

        if (!isMicNotif) {
            // Avatar Inheritance Engine
            if (avatarVal === "" && expiredEntry.summary !== "") {
                for (let i = 0; i < historyNotificationsModel.count; i++) {
                    let past = historyNotificationsModel.get(i);
                    if (past && past.summary === expiredEntry.summary && past.avatarSource && past.avatarSource !== "") {
                        avatarVal = past.avatarSource;
                        break;
                    }
                }
            }

            // FIXED: Store the C++ QObject reference in our private JS map instead of the ListModel
            if (notification) {
                liveNotificationsMap[expiredEntry.notifId] = notification;
            }

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
                historyNotificationsModel.remove(historyNotificationsModel.count - 1);
            }
        }
    }

    /*
     * HISTORICAL NOTIFICATION LIST DRAWER WINDOW (Checks for DP-1, falls back to laptop eDP, or defaults to first available)
     */
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

        // Exclusive focus forces the compositor to route keyboard events here instantly
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay

        onVisibleChanged: {
            if (visible) {
                if (typeof historyListView !== "undefined" && historyListView) {
                    // Deferred execution pass snaps and centers the layout correctly on launch
                    Qt.callLater(function() {
                        historyListView.currentIndex = 0;
                        historyListView.positionViewAtIndex(0, ListView.Beginning);
                        historyListView.forceActiveFocus(); // Focus list directly here safely
                    });
                }
            }
        }

        // Click outside the panel to close history mode via parent reference
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
                            onClicked: {
                                historyNotificationsModel.clear();
                                historyEngine.liveNotificationsMap = {}; // Clear memory mapped QObjects
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

                    // INSTANT KEYBOARD SCROLLING & SNAPPING
                    highlightMoveDuration: 0      // Snaps focused highlight position instantly with zero animation delay
                    highlightResizeDuration: 0    // Snaps focused highlight size instantly with zero animation delay
                    boundsBehavior: Flickable.StopAtBounds // Disables elastic rubber-banding bounce animations at list edges

                    onActiveFocusChanged: {
                        if (!activeFocus && historyEngine.showHistoryMode) {
                            historyListView.forceActiveFocus();
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            if (historyEngine.rootItem) {
                                historyEngine.rootItem.showHistoryMode = false; // Close via parent context binding
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            // Move selection up (older items) by exactly 1 index position (one-at-a-time)
                            let targetUp = currentIndex + 1;
                            if (targetUp >= count) {
                                targetUp = count - 1;
                            }
                            currentIndex = targetUp;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            // Move selection down (newer items) by exactly 1 index position (one-at-a-time)
                            let targetDown = currentIndex - 1;
                            if (targetDown < 0) {
                                targetDown = 0;
                            }
                            currentIndex = targetDown;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete) {
                            if (currentIndex !== -1 && currentIndex < count) {
                                let targetItem = historyNotificationsModel.get(currentIndex);
                                if (targetItem) {
                                    delete historyEngine.liveNotificationsMap[targetItem.notifId];
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

                                    // FIXED: Safely retrieve the notification QObject from the JavaScript mapping dictionary
                                    let activeNotifObject = historyEngine.liveNotificationsMap[item.notifId] || null;

                                    if (historyEngine.controller) {
                                        historyEngine.controller.activate(
                                            null,
                                            item.summary,
                                            item.body,
                                            item.appName,
                                            activeNotifObject
                                        );
                                    }
                                }
                            }
                            event.accepted = true;
                        }
                    }

                    delegate: Rectangle {
                        id: delegateRoot
                        // Guarded parent width to prevent TypeError during destruction when cleared
                        width: parent ? parent.width : 0

                        // Local state for async preview URL loading
                        property string asyncPreviewSource: ""

                        // Check if an uploaded/linked preview image is present in the right column
                        property bool hasRightPreview: (previewSource && previewSource !== "") || (asyncPreviewSource !== "")

                        // Check if the body contains exclusively the link URL to hide the duplicate raw text
                        property bool isBodyOnlyUrl: {
                            if (!body) return false;
                            var cleanBody = body.trim();
                            var url = historyEngine.extractUrl(cleanBody);
                            return cleanBody === url;
                        }

                        // Dynamically scale card height taller if it contains full-sized uploaded/posted images
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

                        // Helper function to extract a URL from the body text
                        function extractUrl(text) {
                            if (!text) return "";
                            var regex = /(https?:\/\/[^\s<]+)/g;
                            var match = text.match(regex);
                            return match ? match[0] : "";
                        }

                        // Non-blocking native shell command executor to bypass CORS sandboxing
                        Process {
                            id: asyncScraper
                            running: false
                        }

                        // Connect directly to the standard output stream of the background process
                        // Handles ArrayBuffer data streams dynamically by converting bytes to string
                        Connections {
                            target: asyncScraper.stdout
                            function onData(data) {
                                var text = "";
                                if (typeof data === "string") {
                                    text = data;
                                } else if (data && data.byteLength !== undefined) {
                                    // Parse ArrayBuffer bytes natively
                                    var arr = new Uint8Array(data);
                                    for (var i = 0; i < arr.length; i++) {
                                        text += String.fromCharCode(arr[i]);
                                    }
                                }

                                if (text !== "") {
                                    var lines = text.split("\n");
                                    for (var j = 0; j < lines.length; j++) {
                                        var trimmed = lines[j].trim();
                                        if (trimmed.startsWith("http")) {
                                            delegateRoot.asyncPreviewSource = trimmed;
                                            break; // Stop parsing after finding the first valid image URL
                                        }
                                    }
                                }
                            }
                        }

                        // Asynchronous webpage scraper to resolve image previews natively
                        // Word boundary matching ensures trailing CDN tokens are preserved
                        function fetchAsyncPreviewNative(url) {
                            if (!url) return;

                            // 1. If it's already a direct file format, map immediately
                            // Word boundary matching ensures trailing CDN tokens are preserved
                            if (url.match(/\.(?:png|jpg|jpeg|gif|svg|webp)\b/i)) {
                                delegateRoot.asyncPreviewSource = url;
                                return;
                            }

                            var cleanUrl = url.trim();

                            // Run an optimized native background scraper using standard CLI tools
                            // Bypasses sandbox blocks and supports full query parameters on output
                            asyncScraper.command = [
                                "bash", "-c",
                                "curl -s -L -A 'Mozilla/5.0' '" + cleanUrl + "' | grep -o -E 'https?://[a-zA-Z0-9./_~%-]+\\.(gif|png|jpg|jpeg|webp)[a-zA-Z0-9./?=&%_-]*' | grep -i -v -E 'avatar|profile|icon|logo' | head -n 1"
                            ];
                            asyncScraper.running = true;
                        }

                        // Trigger the background async parser when the delegate is created
                        Component.onCompleted: {
                            if (!previewSource || previewSource === "") {
                                var linkUrl = historyEngine.extractUrl(body ? body : "");
                                if (linkUrl !== "") {
                                    delegateRoot.fetchAsyncPreviewNative(linkUrl);
                                }
                            }
                        }

                        // Close/Delete Button for individual items (positioned at the top-right)
                        Text {
                            id: deleteItemBtn
                            text: "❌"
                            font.pixelSize: 20 // Sized to 20
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
                                        delete historyEngine.liveNotificationsMap[item.notifId];
                                    }
                                    historyNotificationsModel.remove(index);
                                    historyListView.forceActiveFocus();
                                }
                            }
                        }

                        // Row Layout: User Avatar ALWAYS on the Left, content details on the Right
                        Row {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 20

                            Image {
                                id: delegateAvatar
                                width: 150 // Always locked at 150x150
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
                                    font.pixelSize: 20 // Set font size to 20
                                    font.family: shell.theme.fontFamily || "monospace"
                                    elide: Text.ElideRight
                                    width: parent ? parent.width : 0
                                }
                                Text {
                                    // Hide raw link text when there's an image preview or it's identical to the preview link
                                    visible: text !== "" && !delegateRoot.isBodyOnlyUrl
                                    // Cleans up the long raw URL text inside the history list view
                                    text: body ? historyEngine.getCleanHistoryBody(body) : ""
                                    color: shell.theme.base05 || "#cdd6f4"
                                    font.pixelSize: 20 // Set font size to 20
                                    font.family: shell.theme.fontFamily || "monospace"
                                    wrapMode: Text.Wrap
                                    maximumLineCount: delegateRoot.hasRightPreview ? 2 : 3
                                    elide: Text.ElideRight
                                    width: parent ? parent.width : 0
                                }

                                // Full-sized Image preview displayed underneath the text inside the right column
                                Image {
                                    id: delegatePreviewImage
                                    width: parent ? parent.width - 40 : 0
                                    height: 220
                                    fillMode: Image.PreserveAspectFit
                                    horizontalAlignment: Image.AlignLeft
                                    visible: delegateRoot.hasRightPreview

                                    // Bypasses the strict typeof wrapper checks to prevent native QML list bindings from breaking
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

                                // Interactive Link Preview Box (only visible when a URL is found in body text and no image preview is loaded)
                                Rectangle {
                                    id: linkPreviewBox
                                    width: parent.width - 40
                                    height: 35
                                    color: shell.theme.base02 || "#313244"
                                    radius: 6
                                    border.width: 1
                                    border.color: shell.theme.base03 || "#45475a"
                                    visible: extractedUrl !== "" && !delegateRoot.hasRightPreview

                                    // FIXED: Pointed to the root historyEngine scope to resolve the TypeError
                                    property string extractedUrl: historyEngine.extractUrl(body ? body : "")

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 8
                                        Text {
                                            text: "🔗"
                                            color: shell.theme.base05 || "#cdd6f4"
                                            font.pixelSize: 20 // Changed to base05
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: linkPreviewBox.extractedUrl
                                            color: shell.theme.base05 || "#cdd6f4"
                                            font.pixelSize: 20 // Set font size to 20
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
                                    font.pixelSize: 20 // Set font size to 20
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
