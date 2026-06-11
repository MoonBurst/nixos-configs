import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: passComp
    anchors.fill: parent

    // Property bindings linked directly to the parent search field
    property string searchQuery: ""
    property int selectedIndex: 0
    readonly property alias targetListView: passListView

    // Dynamic helper properties for launcher autocomplete
    property string firstMatchedKey: ""
    property int filteredModelCount: 0

    // Theme references explicitly resolved and set via the loader context
    property var shell: null
    readonly property var theme: (shell && shell.theme) ? shell.theme : null

    ListModel { id: passModel }
    ListModel { id: filteredModel }

    onSearchQueryChanged: {
        filterModel();
    }

    // Filters decrypted path keys on-the-fly as the user types
    function filterModel() {
        filteredModel.clear();
        var txt = searchQuery.toLowerCase().trim();
        for (var i = 0; i < passModel.count; i++) {
            var item = passModel.get(i);
            if (txt === "" || item.key.toLowerCase().indexOf(txt) !== -1) {
                filteredModel.append(item);
            }
        }
        selectedIndex = 0;

        // Update autocomplete variables
        filteredModelCount = filteredModel.count;
        if (filteredModel.count > 0) {
            firstMatchedKey = filteredModel.get(0).key;
        } else {
            firstMatchedKey = "";
        }
    }

    function selectNext() {
        if (filteredModel.count > 0) {
            selectedIndex = (selectedIndex + 1) % filteredModel.count;
        }
    }

    function selectPrev() {
        if (filteredModel.count > 0) {
            selectedIndex = (selectedIndex - 1 + filteredModel.count) % filteredModel.count;
        }
    }

    function decryptAndCopySelected() {
        if (selectedIndex >= 0 && selectedIndex < filteredModel.count) {
            var item = filteredModel.get(selectedIndex);
            if (item) {
                decryptProcess.keyPath = item.key;
                decryptProcess.running = true;
            }
        }
    }

    // Decrypts selected file from your custom PASSWORD_STORE_DIR and pipes the password directly to your Wayland clipboard
    Process {
        id: decryptProcess
        running: false
        property string keyPath: ""
        command: ["sh", "-c", "PASSWORD_STORE_DIR=$HOME/.local/share/pass pass show \"" + keyPath + "\" | head -n 1 | wl-copy"]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("[Pass] Password for '" + keyPath + "' successfully copied to clipboard.");
            } else {
                console.error("[Pass Error] Failed to decrypt password for '" + keyPath + "'");
            }
        }
    }

    // Asynchronously indexes your custom ~/.local/share/pass directory recursively on startup
    Process {
        id: listKeysProcess
        running: true
        command: ["sh", "-c", "interface_user=$(whoami); find /home/$interface_user/.local/share/pass/ -type f -name '*.gpg' | sed \"s|/home/$interface_user/.local/share/pass/||g\" | sed 's|.gpg$||g'"]

        stdout: SplitParser {
            onRead: data => {
                var lines = data.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line !== "") {
                        passModel.append({ "key": line });
                    }
                }
                filterModel();
            }
        }
    }

    // UI Scrollable List View (Shares your global visual card sizes & border properties)
    ListView {
        id: passListView
        anchors.fill: parent
        clip: true
        cacheBuffer: 800
        spacing: 20
        model: filteredModel
        currentIndex: passComp.selectedIndex

        delegate: Rectangle {
            width: passListView.width - 16
            height: 70
            radius: passComp.theme ? passComp.theme.defaultCardRadius : 10
            color: index === passComp.selectedIndex ? (passComp.theme ? passComp.theme.base02 : "#3c3836") : "transparent"
            border.width: index === passComp.selectedIndex ? (passComp.theme ? passComp.theme.globalBorderWidth + 2 : 5) : 0
            border.color: index === passComp.selectedIndex ? (passComp.theme ? passComp.theme.base08 : "#fb4934") : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 12

                Text {
                    text: "🔑"
                    font.pixelSize: 22
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: model.key
                    font.family: passComp.theme ? passComp.theme.fontFamily : "Fira Sans"
                    font.pixelSize: passComp.theme ? passComp.theme.globalFontSize : 20
                    color: index === passComp.selectedIndex ? (passComp.theme ? passComp.theme.base05 : "#f7f700") : (passComp.theme ? passComp.theme.base06 : "#ebdbb2")
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    passComp.selectedIndex = index;
                    passComp.decryptAndCopySelected();
                    launcherRoot.closeOverlay();
                }
            }
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
    }
}
