import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend"
import "../../../style" as Style
import "../../../common/Utils.js" as Utils

Item {
    id: viewRoot

    required property AppLauncherEngine engine
    property var theme: null
    property var settingsManager: null

    readonly property int fieldHeight: settingsManager
        ? settingsManager.getWindowFieldHeight("launcher", 52) : 52
    readonly property int iconSize: settingsManager
        ? settingsManager.getWindowIconSize("launcher", 38) : 38
    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize : 16
    readonly property int globalBorderWidth: (theme && theme.globalBorderWidth) ? theme.globalBorderWidth : 3

    readonly property var inputPad: Utils.getSafeInputPadding(settingsManager)

    signal completed()
    signal routeRequested(string target, string param)

    function clearAndFocus() {
        searchField.clear();
        engine.refreshFilter("");
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    Component.onCompleted: Qt.callLater(() => searchField.forceActiveFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => searchField.forceActiveFocus())

    function isCalcQuery(raw) {
        if (!raw) return false;
        var trimmed = raw.trim();
        if (trimmed.startsWith("=")) return true;
        var lower = trimmed.toLowerCase();
        if (lower === "calc" || lower.startsWith("calc ")) return true;
        if (!/[\d]/.test(trimmed) && !/[+\-*\/^%]/.test(trimmed)) return false;
        return Utils.evaluate(trimmed, true) !== null;
    }

    function checkRouting(rawText) {
        if (!rawText) return false;
        var raw = rawText.trim();
        var lower = raw.toLowerCase();

        if (lower === "settings" || lower === "setting" || lower === "config" || lower === "cfg" || raw.startsWith("cfg ") || raw.startsWith("set ")) {
            viewRoot.routeRequested("settings", ""); return true;
        }
        if (lower === "clip" || lower === "clipboard" || raw.startsWith("clip ")) {
            viewRoot.routeRequested("clipboard", ""); return true;
        }
        if (lower === "todo" || lower === "td" || raw.startsWith("todo ") || raw.startsWith("td ")) {
            viewRoot.routeRequested("todo", ""); return true;
        }
        if (lower === "em" || lower === "email" || lower === "mail" || raw.startsWith("em ") || raw.startsWith("email ")) {
            viewRoot.routeRequested("email", ""); return true;
        }
        if (lower === "def" || lower === "dict" || lower === "dictionary" || raw.startsWith("def ") || raw.startsWith("dict ")) {
            var defQuery = (raw.indexOf(" ") !== -1) ? raw.slice(raw.indexOf(" ") + 1).trim() : "";
            viewRoot.routeRequested("dictionary", defQuery); return true;
        }
        if (lower === "rng" || lower === "dice" || lower === "roll" || lower === "coin" || raw.startsWith("rng ") || raw.startsWith("roll ")) {
            viewRoot.routeRequested("rng", ""); return true;
        }
        if (lower === "pass" || lower === "password" || raw.startsWith("pass ") || raw.startsWith("password ")) {
            var passQuery = (raw.indexOf(" ") !== -1) ? raw.slice(raw.indexOf(" ") + 1).trim() : "";
            viewRoot.routeRequested("pass", passQuery); return true;
        }
        if (lower === "note" || lower === "notes" || raw.startsWith("note ") || raw.startsWith("notes ")) {
            var noteText = (raw.indexOf(" ") !== -1) ? raw.slice(raw.indexOf(" ") + 1).trim() : "";
            viewRoot.routeRequested("notes", noteText); return true;
        }
        if (lower === "power" || lower === "pwr" || lower === "session" || lower === "sys" || lower === "reboot" || lower === "restart" || lower === "shutdown" || lower === "sleep" || lower === "logout") {
            viewRoot.routeRequested("power", ""); return true;
        }
        if (lower === "ai" || lower === "gemini" || raw.startsWith("ai ") || raw.startsWith("gemini ")) {
            var prompt = (raw.indexOf(" ") !== -1) ? raw.slice(raw.indexOf(" ") + 1).trim() : "";
            viewRoot.routeRequested("gemini", prompt); return true;
        }
        if (raw.startsWith(".")) { viewRoot.routeRequested("unicode", raw.substring(1).trim()); return true; }
        if (raw.startsWith("?")) { viewRoot.routeRequested("web", raw.substring(1).trim()); return true; }

        if (viewRoot.isCalcQuery(raw)) {
            var calcExpr = raw.startsWith("=") ? raw.substring(1).trim() : (lower.startsWith("calc ") ? raw.substring(5).trim() : raw);
            viewRoot.routeRequested("calc", calcExpr);
            return true;
        }

        if (lower === "amogus" || lower === "amongus" || lower === "sus") {
            viewRoot.routeRequested("amogus", ""); return true;
        }
        return false;
    }

    Timer {
        id: routerDebounceTimer
        interval: 60; repeat: false; property string pendingText: ""
        onTriggered: {
            if (!viewRoot.checkRouting(pendingText)) {
                engine.refreshFilter(pendingText);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12

        // Universal Shape Input Box
        Item {
            id: searchBox
            Layout.fillWidth: true
            Layout.preferredHeight: viewRoot.fieldHeight
            Layout.minimumHeight: viewRoot.fieldHeight
            Layout.maximumHeight: viewRoot.fieldHeight
            height: viewRoot.fieldHeight

            Style.ShapeBox {
                anchors.fill: parent
                role: "input"
                color: (theme && theme.base00) ? theme.base00 : "#11111b"
                borderColor: searchField.activeFocus
                    ? ((theme && theme.base05) ? theme.base05 : "yellow")
                    : ((theme && theme.base03) ? theme.base03 : "#45475a")
                borderWidth: viewRoot.globalBorderWidth
                slantWidth: 14
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: viewRoot.inputPad.left
                anchors.rightMargin: viewRoot.inputPad.right
                spacing: 10

                Text {
                    id: searchIcon
                    text: "🚀"
                    font.pixelSize: Math.min(26, Math.max(16, parent.height * 0.42))
                }

                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    font.family: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
                    font.pixelSize: Math.min(viewRoot.overlayFontSize + 2, Math.max(13, parent.height * 0.42))
                    color: (theme && theme.base05) ? theme.base05 : "yellow"
                    selectByMouse: true
                    focus: true
                    clip: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search apps or type tool (settings, clip, todo, em, def, rng, calc, pass)..."
                        color: (theme && theme.base0B) ? theme.base0B : "#666"
                        font.pixelSize: parent.font.pixelSize
                        font.family: parent.font.family
                        visible: parent.text === "" && !parent.activeFocus
                        elide: Text.ElideRight
                    }

                    onTextChanged: {
                        routerDebounceTimer.pendingText = text;
                        routerDebounceTimer.restart();
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (!viewRoot.checkRouting(text)) {
                                if (appsList.currentIndex >= 0 && appsList.currentIndex < engine.filteredAppsModel.count) {
                                    engine.launch(engine.filteredAppsModel.get(appsList.currentIndex).exec);
                                    viewRoot.completed();
                                }
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (appsList.currentIndex < engine.filteredAppsModel.count - 1) {
                                appsList.currentIndex++;
                                appsList.positionViewAtIndex(appsList.currentIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (appsList.currentIndex > 0) {
                                appsList.currentIndex--;
                                appsList.positionViewAtIndex(appsList.currentIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        ListView {
            id: appsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: engine.filteredAppsModel
            highlightMoveDuration: 0
            highlightResizeDuration: 0
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: delegateItem
                readonly property bool isSelected: index === appsList.currentIndex
                width: appsList.width - 12
                height: Math.max(54, viewRoot.iconSize + 16)

                Style.ShapeBox {
                    anchors.fill: parent
                    role: "input"
                    color: delegateItem.isSelected ? ((theme && theme.base02) ? theme.base02 : "#333") : "transparent"
                    borderColor: delegateItem.isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : ((theme && theme.base03) ? theme.base03 : "#555")
                    borderWidth: viewRoot.globalBorderWidth
                    slantWidth: 10
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.max(14, viewRoot.inputPad.left)
                    anchors.rightMargin: Math.max(14, viewRoot.inputPad.right)
                    spacing: 14

                    Image {
                        source: model.icon.startsWith("/") || model.icon.startsWith("file://") ? model.icon : "image://icon/" + model.icon
                        Layout.preferredWidth: viewRoot.iconSize
                        Layout.preferredHeight: viewRoot.iconSize
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        sourceSize.width: viewRoot.iconSize * 2
                        sourceSize.height: viewRoot.iconSize * 2
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: model.name
                            font.bold: true
                            font.pixelSize: viewRoot.overlayFontSize
                            color: delegateItem.isSelected ? ((theme && theme.base05) ? theme.base05 : "yellow") : "#ccc"
                        }
                        Text {
                            text: model.exec
                            font.pixelSize: Math.max(10, viewRoot.overlayFontSize - 4)
                            color: "#777"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        appsList.currentIndex = index;
                        engine.launch(model.exec);
                        viewRoot.completed();
                    }
                }
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }
}
