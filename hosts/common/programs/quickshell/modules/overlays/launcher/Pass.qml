import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts
import Quickshell.Io
import "../../common"

Item {
    id: passComp
    anchors.fill: parent

    property string searchQuery: ""
    property int selectedIndex: 0
    readonly property alias targetListView: passListView
    readonly property alias filteredModel: filteredModel

    property string firstMatchedKey: ""
    property int filteredModelCount: 0

    property var shell: null
    readonly property var theme: (shell && shell.theme) ? shell.theme : null
    property bool hasPass: true

    ListModel { id: passModel }
    ListModel { id: filteredModel }

    onSearchQueryChanged: filterModel()

    function getKeyAt(idx) {
        if (idx >= 0 && idx < filteredModel.count) {
            var it = filteredModel.get(idx);
            return it ? (it.key || "") : "";
        }
        return firstMatchedKey || "";
    }

    function reload() {
        passModel.clear();
        filteredModel.clear();
        selectedIndex = 0;
        listKeysProcess.running = false;
        listKeysProcess.running = true;
    }

    Component.onCompleted: reload()

    Process {
        id: passCheckProc
        running: false
        command: ["sh", "-c", "export PATH=\"$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}

    Component.onCompleted: {
        passCheckProc.running = true;
    }/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH\"; command -v pass >/dev/null 2>&1 && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                passComp.hasPass = (data.trim() === "1");
            }
        }
    }

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

    // SAFE CLIPBOARD EXTRACTION: Uses pass -c natively to prevent shell string parameter leaks
    function decryptAndCopySelected() {
        if (selectedIndex >= 0 && selectedIndex < filteredModelCount) {
            var item = filteredModel.get(selectedIndex);
            if (item && item.key) {
                decryptProcess.command = [
                    "sh", "-c",
                    'dir="${PASSWORD_STORE_DIR:-$HOME/.password-store}"; [ ! -d "$dir" ] && dir="$HOME/.local/share/pass"; ' +
                    'PASSWORD_STORE_DIR="$dir" pass -c "$1" >/dev/null 2>&1 && ' +
                    'notify-send -a Pass -u normal -i dialog-password "🔑 Password Copied" "Auto-clearing clipboard..."',
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
            '[ -d "$dir" ] && cd "$dir" && find . -type f -name "*.gpg" | sed "s|^\\./||; s|\\.gpg$||" | sort'
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

    // Uses shared PackageInstallerModal
    Item {
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 40)
        height: 240
        visible: !passComp.hasPass

        PackageInstallerModal {
            anchors.fill: parent
            title: "🔑 PASS REQUIRED"
            description: "Password store requires the standard pass utility:"
            pacmanPkg: "pass"
            aptPkg: "pass"
            dnfPkg: "pass"
            zypperPkg: "password-store"
            nixPkg: "pass"
            onInstalled: {
                passComp.hasPass = true;
                passComp.reload();
            }
        }
    }

    ListView {
        id: passListView
        visible: passComp.hasPass
        anchors.fill: parent
        clip: true
        cacheBuffer: 800
        spacing: 12
        model: filteredModel
        currentIndex: passComp.selectedIndex

        delegate: Rectangle {
            id: passRow
            readonly property bool isSelected: index === passComp.selectedIndex
            readonly property string entryKey: model.key || ""
            readonly property bool isFullyTyped: passComp.searchQuery.trim().toLowerCase() === entryKey.toLowerCase()

            width: passListView.width - 16
            height: 60
            radius: passComp.theme ? passComp.theme.defaultCardRadius : 10
            color: isSelected ? (passComp.theme ? passComp.theme.base02 : "#3c3836") : "transparent"
            border.width: isSelected ? 2 : 1
            border.color: isSelected ? "#00e5ff" : (passComp.theme ? passComp.theme.base03 : "#45475a")

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 12

                Text { text: "🔑"; font.pixelSize: 20; Layout.alignment: Qt.AlignVCenter }

                Text {
                    textFormat: Text.RichText
                    text: {
                        var raw = passRow.entryKey;
                        var q = passComp.searchQuery.trim();
                        if (!q) return raw;
                        var idx = raw.toLowerCase().indexOf(q.toLowerCase());
                        if (idx === -1) return raw;
                        var before = raw.substring(0, idx);
                        var match = raw.substring(idx, idx + q.length);
                        var after = raw.substring(idx + q.length);
                        return before + "<font color='#00e5ff'><b><u>" + match + "</u></b></font>" + after;
                    }
                    font.family: passComp.theme ? passComp.theme.fontFamily : "Fira Sans"
                    font.pixelSize: passComp.theme ? passComp.theme.globalFontSize : 18
                    color: passRow.isSelected ? (passComp.theme ? passComp.theme.base05 : "#f7f700") : (passComp.theme ? passComp.theme.base06 : "#ebdbb2")
                    font.bold: passRow.isSelected
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    visible: passRow.isSelected
                    height: 26
                    width: actionTagText.implicitWidth + 16
                    radius: 4
                    color: passRow.isFullyTyped ? "#04f100" : "#00e5ff"
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: actionTagText
                        anchors.centerIn: parent
                        text: passRow.isFullyTyped ? "↵ Copy" : "↵ Complete"
                        font.pixelSize: 11
                        font.bold: true
                        color: "#0f0f0f"
                    }
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
