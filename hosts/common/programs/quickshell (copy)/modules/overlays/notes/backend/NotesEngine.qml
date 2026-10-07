import QtQuick
import QtQuick.LocalStorage
import Quickshell
import Quickshell.Io

QtObject {
    id: engine

    property string searchQuery: ""
    property int selectedIndex: 0
    property string notesFilePath: Quickshell.env("HOME") + "/Documents/notes.txt"

    property var filteredModel: ListModel { id: fModel }
    property var notesModel: ListModel { id: nModel }

    Component.onCompleted: {
        initDatabase();
        loadNotes();
    }

    onSearchQueryChanged: filterNotes()

    function getDatabase() {
        return LocalStorage.openDatabaseSync("QNotesDB", "1.0", "Local Quick Notes Storage", 1000000);
    }

    function initDatabase() {
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP)');
                tx.executeSql('CREATE TABLE IF NOT EXISTS meta (key TEXT UNIQUE, val TEXT)');
            });
        } catch (e) {}
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
        } catch (e) {}
        nModel.clear();
        for (var j = 0; j < items.length; j++) nModel.append(items[j]);
        filterNotes();
    }

    function filterNotes() {
        fModel.clear();
        var q = searchQuery.toLowerCase().trim();
        for (var i = 0; i < nModel.count; i++) {
            var item = nModel.get(i);
            if (q === "" || item.content.toLowerCase().indexOf(q) !== -1 || item.timestamp.indexOf(q) !== -1) {
                fModel.append(item);
            }
        }
        if (selectedIndex >= fModel.count) selectedIndex = Math.max(0, fModel.count - 1);
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
        } catch(e) {}
    }

    function deleteNoteAt(idx) {
        if (idx < 0 || idx >= fModel.count) return;
        var item = fModel.get(idx);
        var targetId = item.noteId;
        fModel.remove(idx);
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('DELETE FROM notes WHERE id = ?', [targetId]);
            });
            loadNotes();
        } catch(e) {}
    }

    function copySelected() {
        if (selectedIndex >= 0 && selectedIndex < fModel.count) {
            var item = fModel.get(selectedIndex);
            if (item && item.content) {
                Quickshell.clipboardText = item.content;
                Quickshell.execDetached(["notify-send", "-a", "Notes", "-i", "dialog-information", "📋 Note Copied", item.content]);
                return true;
            }
        }
        return false;
    }
}
