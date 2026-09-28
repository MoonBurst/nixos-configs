import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts
import QtQuick.LocalStorage
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

    onSearchQueryChanged: filterNotes()

    Component.onCompleted: {
        initDatabase();
        loadNotes();
    }

    function getDatabase() {
        return LocalStorage.openDatabaseSync("QNotesDB", "1.0", "Local Quick Notes Storage", 1000000);
    }

    function initDatabase() {
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP)');
                
                // Auto-migration: check if text file notes exist and import them on first run
                var checkRs = tx.executeSql('SELECT COUNT(*) AS count FROM notes');
                if (checkRs.rows.item(0).count === 0) {
                    notesImporter.running = true;
                }
            });
        } catch (e) {
            console.error("[Notes DB Init Error]:", e);
        }
    }

    function loadNotes() {
        var items = [];
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                var rs = tx.executeSql("SELECT id, content, strftime('%Y-%m-%d %H:%M', created_at, 'localtime') as ts FROM notes ORDER BY id DESC");
                for (var i = 0; i < rs.rows.length; i++) {
                    var r = rs.rows.item(i);
                    items.push({ noteId: r.id, content: r.content, timestamp: r.ts || "" });
                }
            });
        } catch (e) {
            console.error("[Notes DB Load Error]:", e);
        }

        notesModel.clear();
        for (var j = 0; j < items.length; j++) {
            notesModel.append(items[j]);
        }
        filterNotes();
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
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('INSERT INTO notes (content) VALUES (?)', [clean]);
            });
            loadNotes();
            Quickshell.execDetached(["notify-send", "-a", "Notes", "-i", "accessories-text-editor", "📝 Note Saved", clean]);
        } catch(e) {
            console.error("[Notes DB Insert Error]:", e);
        }
    }

    function deleteNoteAt(idx) {
        if (idx < 0 || idx >= filteredModel.count) return;
        var item = filteredModel.get(idx);
        var targetId = item.noteId;

        filteredModel.remove(idx); // Snappy visual feedback
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('DELETE FROM notes WHERE id = ?', [targetId]);
            });
            loadNotes();
        } catch(e) {
            console.error("[Notes DB Delete Error]:", e);
        }
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

    // Auto-migration process: loads existing notes from ~/Documents/notes.txt on first launch
    Process {
        id: notesImporter
        running: false
        command: ["sh", "-c", "F=\"$HOME/Documents/notes.txt\"; [ -f \"$F\" ] && cat \"$F\" || true"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var l = (line || "").trim();
                if (l.length > 0) {
                    var parts = l.split(" | ");
                    var txt = parts.length > 1 ? parts.slice(1).join(" | ") : l;
                    try {
                        var db = notesRoot.getDatabase();
                        db.transaction(function(tx) {
                            tx.executeSql('INSERT INTO notes (content) VALUES (?)', [txt.trim()]);
                        });
                    } catch(e) {}
                }
            }
        }
        onExited: loadNotes()
    }

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
