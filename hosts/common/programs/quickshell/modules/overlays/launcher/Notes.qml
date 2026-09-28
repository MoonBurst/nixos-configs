import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: notesRoot
    anchors.fill: parent

    property var shell: null
    readonly property var theme: (shell && shell.theme) ? shell.theme : null

    property string searchQuery: ""
    property int selectedIndex: 0
    signal actionCompleted()

    ListModel { id: notesModel }
    ListModel { id: filteredModel }

    readonly property string notesFile: (shell && shell.settingsManager && shell.settingsManager.notesFilePath)
        ? shell.settingsManager.notesFilePath
        : (Quickshell.env("HOME") + "/Documents/notes.txt")

    onSearchQueryChanged: filterNotes()

    Component.onCompleted: loadNotes()

    function loadNotes() {
        notesModel.clear();
        notesLoaderProc.running = false;
        notesLoaderProc.command = [
            "sh", "-c",
            'mkdir -p "$(dirname "$1")" && touch "$1" && tac "$1"',
            "sh", notesRoot.notesFile
        ];
        notesLoaderProc.running = true;
    }

    function filterNotes() {
        filteredModel.clear();
        var q = searchQuery.toLowerCase().trim();

        for (var i = 0; i < notesModel.count; i++) {
            var item = notesModel.get(i);
            if (q === "" || item.content.toLowerCase().indexOf(q) !== -1 || item.timestamp.indexOf(q) !== -1) {
                filteredModel.append(item);
            }
        }
        if (selectedIndex >= filteredModel.count) {
            selectedIndex = Math.max(0, filteredModel.count - 1);
        }
    }

    function addNote(text) {
        if (!text || text.trim() === "") return;
        var clean = text.trim();

        addProc.running = false;
        addProc.command = [
            "sh", "-c",
            'mkdir -p "$(dirname "$1")"; ' +
            'ts=$(date "+%Y-%m-%d %H:%M"); ' +
            'printf "%s | %s\n" "$ts" "$2" >> "$1"; ' +
            'notify-send -a Notes -i accessories-text-editor "📝 Note Saved" "$2"',
            "sh", notesRoot.notesFile, clean
        ];
        addProc.running = true;
    }

    function deleteNoteAt(idx) {
        if (idx < 0 || idx >= filteredModel.count) return;
        var item = filteredModel.get(idx);
        filteredModel.remove(idx);
        for (var i = 0; i < notesModel.count; i++) { if (notesModel.get(i).rawLine === item.rawLine) { notesModel.remove(i); break; } }
        for (var i = 0; i < notesModel.count; i++) { if (notesModel.get(i).rawLine === item.rawLine) { notesModel.remove(i); break; } }
        for (var i = 0; i < notesModel.count; i++) { if (notesModel.get(i).rawLine === item.rawLine) { notesModel.remove(i); break; } }

        Quickshell.execDetached([
            "sh", "-c",
            'grep -F -v -x "$1" "$2" > "$2.tmp" && mv -f "$2.tmp" "$2"',
            "sh", item.rawLine, notesRoot.notesFile
        ]);
    }

    function copySelected() {
        if (selectedIndex >= 0 && selectedIndex < filteredModel.count) {
            var item = filteredModel.get(selectedIndex);
            if (item) {
                Quickshell.clipboardText = item.content;
                Quickshell.execDetached(["notify-send", "-a", "Notes", "-i", "dialog-information", "📋 Note Copied", item.content]);
                notesRoot.actionCompleted();
            }
        }
    }

    function selectNext() {
        if (filteredModel.count > 0) selectedIndex = (selectedIndex + 1) % filteredModel.count;
    }

    function selectPrev() {
        if (filteredModel.count > 0) selectedIndex = (selectedIndex - 1 + filteredModel.count) % filteredModel.count;
    }

    Process {
        id: notesLoaderProc
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var l = (line || "").trim();
                if (l.length > 0) {
                    var parts = l.split(" | ");
                    var ts = parts.length > 1 ? parts[0] : "";
                    var txt = parts.length > 1 ? parts.slice(1).join(" | ") : l;
                    notesModel.append({ timestamp: ts, content: txt, rawLine: l });
                }
            }
        }
        onExited: { filterNotes(); }
    }

    Process { id: addProc; onExited: loadNotes() }

    ListView {
        id: notesListView
        anchors.fill: parent
        clip: true
        spacing: 12
        model: filteredModel
        currentIndex: notesRoot.selectedIndex

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 40
            height: 140
            color: "transparent"
            visible: filteredModel.count === 0

            Column {
                anchors.centerIn: parent
                spacing: 8
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "📝"; font.pixelSize: 36 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No notes yet."
                    font.family: theme ? theme.fontFamily : "monospace"
                    font.pixelSize: 18; font.bold: true
                    color: theme ? theme.base05 : "yellow"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Type 'note your text' and press Enter to save!"
                    font.family: "monospace"; font.pixelSize: 13
                    color: theme ? theme.base05 : "yellow"; opacity: 0.6
                }
            }
        }

        delegate: Rectangle {
            id: noteCard
            readonly property bool isSelected: index === notesRoot.selectedIndex
            width: notesListView.width - 16
            height: Math.max(54, noteContentText.implicitHeight + 28)
            radius: theme ? theme.defaultCardRadius : 8
            color: isSelected ? (theme ? theme.base02 : "#222222") : "transparent"
            border.width: isSelected ? 2 : 1
            border.color: isSelected ? (theme ? theme.base05 : "yellow") : (theme ? theme.base03 : "#444444")

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text { text: "📌"; font.pixelSize: 18; Layout.alignment: Qt.AlignVCenter }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        visible: model.timestamp !== ""
                        text: model.timestamp
                        font.family: "monospace"
                        font.pixelSize: 11
                        font.bold: true
                        color: theme ? theme.base09 : "#fe8019"
                    }

                    Text {
                        id: noteContentText
                        text: model.content
                        font.family: theme ? theme.fontFamily : "monospace"
                        font.pixelSize: 15
                        color: theme ? theme.base05 : "yellow"
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    width: 26
                    height: 26
                    radius: 4
                    color: delHover.hovered ? (theme ? theme.base08 : "red") : "transparent"
                    border.color: theme ? theme.base08 : "red"
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.bold: true
                        font.pixelSize: 11
                        color: delHover.hovered ? "#000000" : (theme ? theme.base08 : "red")
                    }

                    HoverHandler { id: delHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notesRoot.deleteNoteAt(index)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    notesRoot.selectedIndex = index;
                    notesRoot.copySelected();
                }
            }
        }

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 6 }
    }
}
