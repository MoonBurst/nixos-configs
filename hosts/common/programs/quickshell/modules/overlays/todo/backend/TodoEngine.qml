import QtQuick
import QtQuick.LocalStorage

QtObject {
    id: engine

    property string filterMode: "All"
    property string activeCategory: ""
    property int editingTaskId: -1

    property var categoryModel: ListModel { id: catModel }
    property var todoModel: ListModel { id: tModel }

    Component.onCompleted: {
        initDatabase();
        loadCategories();
        loadTodos();
    }

    onFilterModeChanged: loadTodos()
    onActiveCategoryChanged: loadTodos()

    function getDatabase() {
        return LocalStorage.openDatabaseSync("QTodoQueue", "1.0", "Local Todo List Storage", 1000000);
    }

    function initDatabase() {
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY AUTOINCREMENT, task TEXT, completed INTEGER DEFAULT 0, category TEXT DEFAULT "", created_at DATETIME DEFAULT CURRENT_TIMESTAMP)');
                try { tx.executeSql('ALTER TABLE todos ADD COLUMN category TEXT DEFAULT ""'); } catch (e) {}
                tx.executeSql('CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)');
                var checkRs = tx.executeSql('SELECT COUNT(*) AS count FROM categories');
                if (checkRs.rows.item(0).count === 0) tx.executeSql('INSERT INTO categories (name) VALUES ("Inbox")');
            });
        } catch (err) {}
    }

    function loadCategories() {
        var items = [];
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                var rs = tx.executeSql('SELECT name FROM categories ORDER BY id ASC');
                for (var i = 0; i < rs.rows.length; i++) items.push({ name: rs.rows.item(i).name });
            });
        } catch (err) {}
        catModel.clear();
        for (var j = 0; j < items.length; j++) catModel.append(items[j]);
        if (items.length > 0) {
            var exists = items.some(item => item.name === activeCategory);
            if (!exists || activeCategory === "") activeCategory = items[0].name;
        } else activeCategory = "";
    }

    function loadTodos() {
        if (activeCategory === "") { tModel.clear(); return; }
        var items = [];
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                var query = 'SELECT id, task, completed, category FROM todos WHERE category = ? ORDER BY id ASC';
                if (filterMode === "Active") query = 'SELECT id, task, completed, category FROM todos WHERE category = ? AND completed = 0 ORDER BY id ASC';
                else if (filterMode === "Completed") query = 'SELECT id, task, completed, category FROM todos WHERE category = ? AND completed = 1 ORDER BY id ASC';
                var rs = tx.executeSql(query, [activeCategory]);
                for (var i = 0; i < rs.rows.length; i++) items.push({ id: rs.rows.item(i).id, task: rs.rows.item(i).task, completed: rs.rows.item(i).completed === 1 });
            });
        } catch (err) {}
        tModel.clear();
        for (var j = 0; j < items.length; j++) tModel.append(items[j]);
    }

    function addTodo(taskText) {
        if (!taskText || taskText.trim() === "" || activeCategory === "") return;
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('INSERT INTO todos (task, completed, category) VALUES (?, 0, ?)', [taskText.trim(), activeCategory]);
            });
            loadTodos();
        } catch (err) {}
    }

    function toggleTodo(id, currentCompleted) {
        var nextVal = currentCompleted ? 0 : 1;
        try {
            var db = getDatabase();
            db.transaction(function(tx) { tx.executeSql('UPDATE todos SET completed = ? WHERE id = ?', [nextVal, id]); });
            for (var i = 0; i < tModel.count; i++) {
                if (tModel.get(i).id === id) {
                    if (filterMode === "All") tModel.setProperty(i, "completed", !currentCompleted);
                    else tModel.remove(i);
                    break;
                }
            }
        } catch (err) { loadTodos(); }
    }

    function deleteTodo(id) {
        try {
            var db = getDatabase();
            db.transaction(function(tx) { tx.executeSql('DELETE FROM todos WHERE id = ?', [id]); });
            for (var i = 0; i < tModel.count; i++) {
                if (tModel.get(i).id === id) { tModel.remove(i); break; }
            }
        } catch (err) { loadTodos(); }
    }

    function deleteActiveCategory() {
        if (activeCategory === "") return;
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('DELETE FROM categories WHERE name = ?', [activeCategory]);
                tx.executeSql('DELETE FROM todos WHERE category = ?', [activeCategory]);
            });
            activeCategory = "";
            loadCategories();
            loadTodos();
        } catch (err) {}
    }

    function saveInlineEdit(id, updatedText) {
        var cleanText = (updatedText !== undefined && updatedText !== null) ? updatedText.trim() : "";
        if (cleanText !== "") {
            try {
                var db = getDatabase();
                db.transaction(function(tx) { tx.executeSql('UPDATE todos SET task = ? WHERE id = ?', [cleanText, id]); });
                for (var i = 0; i < tModel.count; i++) {
                    if (tModel.get(i).id === id) {
                        tModel.setProperty(i, "task", cleanText);
                        break;
                    }
                }
                // Force layout list update
                loadTodos();
            } catch (err) { loadTodos(); }
        }
        editingTaskId = -1;
    }


    function moveTodo(currentIndex, moveUp) {
        if (currentIndex < 0 || currentIndex >= tModel.count) return;
        var targetIndex = moveUp ? currentIndex - 1 : currentIndex + 1;
        if (targetIndex < 0 || targetIndex >= tModel.count) return;
        var itemA = tModel.get(currentIndex);
        var itemB = tModel.get(targetIndex);
        if (!itemA || !itemB) return;
        var idA = itemA.id; var idB = itemB.id;
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('UPDATE todos SET id = -1 WHERE id = ?', [idA]);
                tx.executeSql('UPDATE todos SET id = ? WHERE id = ?', [idA, idB]);
                tx.executeSql('UPDATE todos SET id = ? WHERE id = -1', [idB]);
            });
            tModel.setProperty(currentIndex, "id", idB);
            tModel.setProperty(targetIndex, "id", idA);
            tModel.move(currentIndex, targetIndex, 1);
        } catch (err) { loadTodos(); }
    }

    function cycleCategory(forward) {
        if (catModel.count <= 1) return;
        var idx = -1;
        for (var i = 0; i < catModel.count; i++) {
            if (catModel.get(i).name === activeCategory) { idx = i; break; }
        }
        if (idx === -1) idx = 0;
        idx = forward ? (idx + 1) % catModel.count : (idx - 1 + catModel.count) % catModel.count;
        activeCategory = catModel.get(idx).name;
    }

    function cycleFilterMode(forward) {
        var modes = ["All", "Active", "Completed"];
        var idx = modes.indexOf(filterMode);
        if (idx === -1) idx = 0;
        filterMode = modes[forward ? (idx + 1) % modes.length : (idx - 1 + modes.length) % modes.length];
    }
}
