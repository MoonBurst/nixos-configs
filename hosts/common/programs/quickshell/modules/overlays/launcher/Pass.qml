import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: passComp
    anchors.fill: parent

    property string searchQuery: ""
    property int selectedIndex: 0
    readonly property alias targetListView: passListView

    property string firstMatchedKey: ""
    property int filteredModelCount: 0

    property var shell: null
    readonly property var theme: (shell && shell.theme) ? shell.theme : null

    ListModel { id: passModel }
    ListModel { id: filteredModel }

    onSearchQueryChanged: filterModel()

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
        filteredModelCount = filteredModel.count;
        firstMatchedKey = filteredModelCount > 0 ? filteredModel.get(0).key : "";
    }

    function selectNext() {
        if (filteredModelCount > 0) selectedIndex = (selectedIndex + 1) % filteredModelCount;
    }

    function selectPrev() {
        if (filteredModelCount > 0) selectedIndex = (selectedIndex - 1 + filteredModelCount) % filteredModelCount;
    }

    function decryptAndCopySelected() {
        if (selectedIndex >= 0 && selectedIndex < filteredModelCount) {
            var item = filteredModel.get(selectedIndex);
            if (item) {
                decryptProcess.command = [
                    "sh", "-c",
                    'dir="${PASSWORD_STORE_DIR:-$HOME/.password-store}"; [ ! -d "$dir" ] && dir="$HOME/.local/share/pass"; ' +
                    'pw=$(PASSWORD_STORE_DIR="$dir" pass show "$1" 2>/dev/null | head -n 1 | tr -d "\\r\\n"); ' +
                    'if [ -n "$pw" ]; then ' +
                    '  printf "%s" "$pw" | wl-copy; ' +
                    '  notify-send -a Pass -u normal -i dialog-password "🔑 Password Copied" "Auto-clearing in 45s..."; ' +
                    '  ( sleep 0.4; cliphist list 2>/dev/null | head -n 1 | cliphist delete 2>/dev/null; ' +
                    '    sleep 44.6; cur=$(wl-paste 2>/dev/null); [ "$cur" = "$pw" ] && wl-copy --clear ) & ' +
                    'fi',
                    "sh", item.key
                ];
                decryptProcess.running = true;
            }
        }
    }

    Process { id: decryptProcess; running: false }

    Process {
        id: listKeysProcess
        running: true
        command: [
            "sh", "-c",
            'dir="${PASSWORD_STORE_DIR:-$HOME/.password-store}"; [ ! -d "$dir" ] && dir="$HOME/.local/share/pass"; ' +
            '[ -d "$dir" ] && find "$dir" -type f -name "*.gpg" | sed "s|$dir/||g" | sed "s|\\.gpg$||g"'
        ]
        stdout: SplitParser {
            onRead: data => {
                var lines = data.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line !== "") passModel.append({ "key": line });
                }
                filterModel();
            }
        }
    }

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
                anchors.leftMargin: 15; anchors.rightMargin: 15
                spacing: 12

                Text { text: "🔑"; font.pixelSize: 22; Layout.alignment: Qt.AlignVCenter }

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
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    passComp.selectedIndex = index;
                    passComp.decryptAndCopySelected();
                    launcherRoot.closeOverlay();
                }
            }
        }

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    }
}
