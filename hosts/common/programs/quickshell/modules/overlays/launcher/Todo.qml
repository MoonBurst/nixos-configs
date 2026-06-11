import QtQuick
import QtQuick.Controls
import QtQuick.LocalStorage
import QtQuick.Layouts

Rectangle {
    id: todoRoot

    // ============================================================================
    // THEME & STYLE SAFE PROPERTY FALLBACKS (MATCHING YOUR LAUNCHER SYSTEM)
    // ============================================================================
    property color modalBoxBg: (typeof shell !== 'undefined' && shell.theme) ? shell.theme.base00 : "#121212"
    property color fieldBg: (typeof shell !== 'undefined' && shell.theme) ? shell.theme.base00 : "#121212"
    property color placeholderTextColor: (typeof shell !== 'undefined' && shell.theme) ? shell.theme.base0B : "#545454"
    property color textWriteColor: (typeof shell !== 'undefined' && shell.theme) ? shell.theme.base06 : "#ebdbb2"

    // Mapped to your active/inactive custom border color slots (base05 / base03)
    property color innerCardActiveBorder: (typeof shell !== 'undefined' && shell.theme) ? shell.theme.innerBorderColor : "#fabd2f"
    property color innerCardInactiveBorder: (typeof shell !== 'undefined' && shell.theme) ? shell.theme.outerBorderColor : "#3c3836"
    property color titleColor: innerCardActiveBorder // Bound to your gold/yellow highlight base05

    property string todoFontFamily: (typeof shell !== 'undefined' && shell.theme) ? shell.theme.fontFamily : "Fira Sans"

    // Centralized Home Manager design variables mapped directly to your requested slots
    property int globalFontSize: (typeof shell !== 'undefined' && shell.theme) ? shell.theme.globalFontSize : 20
    property int globalBorderWidth: (typeof shell !== 'undefined' && shell.theme) ? shell.theme.globalBorderWidth : 3
    property int todoPadding: (typeof shell !== 'undefined' && shell.theme) ? shell.theme.globalPadding : 20
    property int defaultCardRadius: (typeof shell !== 'undefined' && shell.theme) ? shell.theme.defaultCardRadius : 10

    property int innerCardActiveThickness: globalBorderWidth + 2

    // ============================================================================
    // DYNAMIC DERIVED LAYOUT VARIABLES (VARS SCALING WITH THE GLOBAL ENGINES)
    // ============================================================================
    property int fontInputSize: globalFontSize + 4 // Set to exactly 24 pixels
    property int fontBodySize: globalFontSize + 4  // Set to exactly 24 pixels
    property int fontMetaSize: Math.max(12, globalFontSize - 4)
    property int fontButtonSize: globalFontSize

    property int delegateCardHeight: Math.max(45, globalFontSize + 30)
    property int checkboxSize: Math.max(20, globalFontSize + 4)
    property int checkboxCheckmarkSize: checkboxSize / 2

    property int cardRadiusDelegate: Math.max(4, defaultCardRadius - 4)
    property int pillBtnHeight: Math.max(44, globalFontSize + 24)
    property int pillBtnRadius: pillBtnHeight / 2

    // Filter modes: "All" | "Active" | "Completed"
    property string filterMode: "All"

    // Board/Category tracking variables
    property string activeCategory: ""

    // Inline Editing State Trackers
    property int editingTaskId: -1

    // Set background to transparent to seamlessly merge with the launcher's main panel
    color: "transparent"
    anchors.fill: parent

    // Force this root container to be focus-compliant
    focus: true

    // ============================================================================
    // FOCUS DELEGATION ROUTER (FORCES FOCUS TO INPUT FIELD ON WIDGET LAUNCH)
    // ============================================================================
    onActiveFocusChanged: {
        if (activeFocus && activeCategory !== "" && editingTaskId === -1 && !helpOverlay.visible) {
            taskInput.forceActiveFocus();
        }
    }

    // ============================================================================
    // SYSTEM GLOBAL KEYBOARD CONTROLLER (HANDLES BOARDS, FILTERS, & ACTION POPUPS)
    // ============================================================================
    Keys.onPressed: (event) => {
        var isAltPressed = (event.modifiers & Qt.AltModifier) !== 0;
        var isCtrlPressed = (event.modifiers & Qt.ControlModifier) !== 0;

        if (isAltPressed) {
            if (event.key === Qt.Key_Left) {
                todoRoot.cycleCategory(false);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                todoRoot.cycleCategory(true);
                event.accepted = true;
            }
        } else if (isCtrlPressed) {
            if (event.key === Qt.Key_Left) {
                todoRoot.cycleFilterMode(false);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                todoRoot.cycleFilterMode(true);
                event.accepted = true;
            } else if (event.key === Qt.Key_N) { // Ctrl+N opens Create Board Modal
                listNameInput.text = ""; addListOverlay.visible = true; listNameInput.forceActiveFocus(); event.accepted = true;
            } else if (event.key === Qt.Key_D) { // Ctrl+D deletes Active Board List
                todoRoot.deleteActiveCategory(); event.accepted = true;
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            // First-run UX: If no category boards exist, pressing Enter instantly pops open the create-list overlay
            if (todoRoot.activeCategory === "") {
                listNameInput.text = ""; addListOverlay.visible = true; listNameInput.forceActiveFocus(); event.accepted = true;
            }
        } else if (event.text === "?") { // Standard "?" hotkey opens help cheatsheet
            helpOverlay.visible = true; event.accepted = true;
        }
    }

    // Specialized, native QML return handlers guarantees first-run Enter launches Create-List
    Keys.onReturnPressed: (event) => {
        if (todoRoot.activeCategory === "") {
            listNameInput.text = ""; addListOverlay.visible = true; listNameInput.forceActiveFocus(); event.accepted = true;
        }
    }
    Keys.onEnterPressed: (event) => {
        if (todoRoot.activeCategory === "") {
            listNameInput.text = ""; addListOverlay.visible = true; listNameInput.forceActiveFocus(); event.accepted = true;
        }
    }

    // ============================================================================
    // SQLITE DATABASE ENGINE (CASCADING TRANSITION PASSES)
    // ============================================================================
    ListModel { id: todoModel }
    ListModel { id: categoryModel }

    Component.onCompleted: {
        initDatabase();
        loadCategories();
        loadTodos();
    }

    onFilterModeChanged: loadTodos()

    function getDatabase() {
        return LocalStorage.openDatabaseSync("QTodoQueue", "1.0", "Local Todo List Storage", 1000000);
    }

    function initDatabase() {
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                // Core Todo Table Schema (Defaulting category safely to empty string)
                tx.executeSql('CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY AUTOINCREMENT, task TEXT, completed INTEGER DEFAULT 0, category TEXT DEFAULT "", created_at DATETIME DEFAULT CURRENT_TIMESTAMP)');

                // Safety migration runner: safely injects the category column if upgrading from an older database schema
                try {
                    tx.executeSql('ALTER TABLE todos ADD COLUMN category TEXT DEFAULT ""');
                    console.log("[Todo DB] Schema updated. Added 'category' column.");
                } catch (e) {
                    // Column already exists, safe to ignore
                }

                // Core Category Table Schema
                tx.executeSql('CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)');

                // FIRST-RUN SAFEGUARD: Only insert default "Inbox" if the table is completely empty
                var checkRs = tx.executeSql('SELECT COUNT(*) AS count FROM categories');
                if (checkRs.rows.item(0).count === 0) {
                    tx.executeSql('INSERT INTO categories (name) VALUES ("Inbox")');
                }
            });
        } catch (err) {
            console.error("[Todo DB Error] Initialization failed: ", err);
        }
    }

    function loadCategories() {
        var items = [];
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                var rs = tx.executeSql('SELECT name FROM categories ORDER BY id ASC');
                for (var i = 0; i < rs.rows.length; i++) {
                    items.push({ name: rs.rows.item(i).name });
                }
            });
        } catch (err) {
            console.error("[Todo DB Error] Failed to load board categories: ", err);
        }
        categoryModel.clear();
        for (var j = 0; j < items.length; j++) {
            categoryModel.append(items[j]);
        }

        // Auto-select selection router
        if (items.length > 0) {
            var exists = items.some(item => item.name === activeCategory);
            if (!exists || activeCategory === "") { activeCategory = items[0].name; }
        } else { activeCategory = ""; }
    }

    function loadTodos() {
        if (activeCategory === "") { todoModel.clear(); return; }
        var items = [];
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                // Changed sorting order from DESC to ASC so new items append cleanly to the bottom
                var query = 'SELECT id, task, completed, category FROM todos WHERE category = ? ORDER BY id ASC';
            if (filterMode === "Active") {
                query = 'SELECT id, task, completed, category FROM todos WHERE category = ? AND completed = 0 ORDER BY id ASC';
            } else if (filterMode === "Completed") {
                query = 'SELECT id, task, completed, category FROM todos WHERE category = ? AND completed = 1 ORDER BY id ASC';
            }
            var rs = tx.executeSql(query, [activeCategory]);
            for (var i = 0; i < rs.rows.length; i++) {
                items.push({ id: rs.rows.item(i).id, task: rs.rows.item(i).task, completed: rs.rows.item(i).completed === 1 });
            }
            });
        } catch (err) { console.error("[Todo DB Error] Load failed: ", err); }
        todoModel.clear();
        for (var j = 0; j < items.length; j++) { todoModel.append(items[j]); }
        if (todoModel.count === 0 && activeCategory !== "") { taskInput.forceActiveFocus(); }
    }

    function addTodo(taskText) {
        if (!taskText || taskText.trim() === "" || activeCategory === "") return;
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('INSERT INTO todos (task, completed, category) VALUES (?, 0, ?)', [taskText.trim(), activeCategory]);
            });
            taskInput.text = "";
            loadTodos();
        } catch (err) { console.error("[Todo DB Error] Add failed: ", err); }
    }

    // Toggle callback with inline QML list-model re-writing (prevents annoying scroll JUMPS)
    function toggleTodo(id, currentCompleted) {
        var nextVal = currentCompleted ? 0 : 1;
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('UPDATE todos SET completed = ? WHERE id = ?', [nextVal, id]);
            });

            // Loop through model items and update completion state inline without reloading from DB
            for (var i = 0; i < todoModel.count; i++) {
                if (todoModel.get(i).id === id) {
                    if (filterMode === "All") { todoModel.setProperty(i, "completed", !currentCompleted); }
                    else { todoModel.remove(i); if (todoModel.count === 0) taskInput.forceActiveFocus(); }
                    break;
                }
            }
        } catch (err) { console.error("[Todo DB Error] Toggle failed: ", err); loadTodos(); }
    }

    // Deletion callback
    function deleteTodo(id) {
        try {
            var db = getDatabase();
            db.transaction(function(tx) { tx.executeSql('DELETE FROM todos WHERE id = ?', [id]); });
            for (var i = 0; i < todoModel.count; i++) {
                if (todoModel.get(i).id === id) { todoModel.remove(i); break; }
            }
            if (todoModel.count === 0) taskInput.forceActiveFocus();
        } catch (err) { console.error("[Todo DB Error] Deletion failed: ", err); loadTodos(); }
    }

    // Deletion of active board list with cascading todo purge
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
        } catch (err) { console.error("[Todo DB Error] Category delete failed: ", err); }
    }

    // Commits task text edits inline (prevents scroll jumps)
    function saveInlineEdit(id, updatedText) {
        if (updatedText !== "") {
            try {
                var db = getDatabase();
                db.transaction(function(tx) { tx.executeSql('UPDATE todos SET task = ? WHERE id = ?', [updatedText, id]); });
                for (var i = 0; i < todoModel.count; i++) {
                    if (todoModel.get(i).id === editingTaskId) { todoModel.setProperty(i, "task", updatedText); break; }
                }
            } catch (err) { console.error("[Todo DB Error] Task edit failed: ", err); loadTodos(); }
        }
        todoRoot.editingTaskId = -1;
        todoListView.forceActiveFocus();
    }

    // Closes inline editor and returns active focus to list view
    function cancelInlineEdit() {
        todoRoot.editingTaskId = -1;
        todoListView.forceActiveFocus();
    }

    // Cycle Board Lists globally via Alt+Left/Right Arrow keybinds
    function cycleCategory(forward) {
        if (categoryModel.count <= 1) return;
        var idx = -1;
        for (var i = 0; i < categoryModel.count; i++) {
            if (categoryModel.get(i).name === activeCategory) { idx = i; break; }
        }
        if (idx === -1) idx = 0;
        idx = forward ? (idx + 1) % categoryModel.count : (idx - 1 + categoryModel.count) % categoryModel.count;
        activeCategory = categoryModel.get(idx).name;
        loadTodos();
    }

    // Cycle Status Filters globally via Ctrl+Left/Right Arrow keybinds
    function cycleFilterMode(forward) {
        var modes = ["All", "Active", "Completed"];
        var idx = modes.indexOf(filterMode);
        if (idx === -1) idx = 0;
        filterMode = modes[forward ? (idx + 1) % modes.length : (idx - 1 + modes.length) % modes.length];
    }

    // Safe, atomic SQLite Primary Key swapping transaction handles database order swapping cleanly
    function moveTodo(currentIndex, moveUp) {
        if (currentIndex < 0 || currentIndex >= todoModel.count) return;

        var targetIndex = moveUp ? currentIndex - 1 : currentIndex + 1;
        if (targetIndex < 0 || targetIndex >= todoModel.count) return; // Out of bounds safety check

        var itemA = todoModel.get(currentIndex);
        var itemB = todoModel.get(targetIndex);
        if (!itemA || !itemB) return;

        var idA = itemA.id;
        var idB = itemB.id;

        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                // SQLite PK Swapping algorithm (prevents unique constraint failures)
                tx.executeSql('UPDATE todos SET id = -1 WHERE id = ?', [idA]);
                tx.executeSql('UPDATE todos SET id = ? WHERE id = ?', [idA, idB]);
                tx.executeSql('UPDATE todos SET id = ? WHERE id = -1', [idB]);
            });

            // Re-align the model IDs to match the new database primary keys
            todoModel.setProperty(currentIndex, "id", idB);
            todoModel.setProperty(targetIndex, "id", idA);

            // Move the item inline instantly (prevents annoying ScrollView JUMPS)
            todoModel.move(currentIndex, targetIndex, 1);

            // Keep selection focused on the moved card so they can continue sliding it smoothly
            todoListView.currentIndex = targetIndex;
            console.log("[Todo] Task reordered. Swapped ID " + idA + " with " + idB);
        } catch (err) {
            console.error("[Todo DB Error] Task reordering failed: ", err);
            loadTodos(); // Fallback
        }
    }

    // ============================================================================
    // LAYOUT VIEWS
    // ============================================================================
    ColumnLayout {
        anchors.fill: parent
        // Explicitly declared individual margins to override any bottom alignment layout conflicts
        anchors.leftMargin: todoRoot.todoPadding
        anchors.rightMargin: todoRoot.todoPadding
        anchors.topMargin: todoRoot.todoPadding
        anchors.bottomMargin: 0 // Align bar tightly on the bottom edge
        spacing: 15

        // A. HORIZONTAL BOARDS ROW
        Rectangle {
            Layout.fillWidth: true
            height: todoRoot.pillBtnHeight
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                spacing: 10

                ListView {
                    id: categoryListView
                    Layout.fillWidth: true
                    height: todoRoot.pillBtnHeight
                    orientation: ListView.Horizontal
                    spacing: 8
                    model: categoryModel
                    clip: true

                    delegate: Rectangle {
                        width: catText.implicitWidth + todoRoot.globalFontSize
                        height: todoRoot.pillBtnHeight
                        radius: todoRoot.pillBtnRadius
                        color: "transparent"
                        border.color: todoRoot.activeCategory === model.name ? todoRoot.innerCardActiveBorder : todoRoot.innerCardInactiveBorder
                        border.width: todoRoot.activeCategory === model.name ? todoRoot.innerCardActiveThickness : (todoRoot.globalBorderWidth + 1)

                        Text {
                            id: catText
                            text: model.name
                            font.family: todoRoot.todoFontFamily
                            font.pixelSize: todoRoot.fontButtonSize
                            font.bold: true
                            color: todoRoot.activeCategory === model.name ? todoRoot.titleColor : todoRoot.textWriteColor
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { todoRoot.activeCategory = model.name; todoRoot.loadTodos(); }
                        }
                    }
                }

                Rectangle {
                    width: addListText.implicitWidth + todoRoot.globalFontSize
                    height: todoRoot.pillBtnHeight
                    radius: todoRoot.pillBtnRadius
                    color: "transparent"
                    border.color: todoRoot.innerCardActiveBorder
                    border.width: todoRoot.globalBorderWidth

                    Text {
                        id: addListText
                        text: "New List"
                        font.family: todoRoot.todoFontFamily
                        font.pixelSize: todoRoot.fontButtonSize
                        font.bold: true
                        color: todoRoot.innerCardActiveBorder
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { listNameInput.text = ""; addListOverlay.visible = true; listNameInput.forceActiveFocus(); }
                    }
                }

                Rectangle {
                    visible: todoRoot.activeCategory !== ""
                    width: removeListText.implicitWidth + todoRoot.globalFontSize
                    height: todoRoot.pillBtnHeight
                    radius: todoRoot.pillBtnRadius
                    color: "transparent"
                    border.color: (typeof shell !== 'undefined' && shell.theme && shell.theme.base08) ? shell.theme.base08 : "#fb4934"
                    border.width: todoRoot.globalBorderWidth

                    Text {
                        id: removeListText
                        text: "Remove List"
                        font.family: todoRoot.todoFontFamily
                        font.pixelSize: todoRoot.fontButtonSize
                        font.bold: true
                        color: (typeof shell !== 'undefined' && shell.theme && shell.theme.base08) ? shell.theme.base08 : "#fb4934"
                        anchors.centerIn: parent
                    }

                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: todoRoot.deleteActiveCategory() }
                }
            }
        }

        // B. INPUT RECTANGLE
        Rectangle {
            Layout.fillWidth: true
            height: Math.max(58, taskInput.implicitHeight + 16)
            color: todoRoot.fieldBg
            radius: todoRoot.defaultCardRadius
            border.color: taskInput.activeFocus ? todoRoot.innerCardActiveBorder : todoRoot.innerCardInactiveBorder
            border.width: taskInput.activeFocus ? todoRoot.innerCardActiveThickness : (todoRoot.globalBorderWidth + 1)
            visible: todoRoot.activeCategory !== ""

            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: taskInput.forceActiveFocus() }

            Item {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 8; anchors.bottomMargin: 8

                TextEdit {
                    id: taskInput
                    anchors.fill: parent
                    font.family: todoRoot.todoFontFamily
                    font.pixelSize: 20
                    color: todoRoot.titleColor
                    focus: true
                    wrapMode: Text.Wrap
                    selectByMouse: true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            todoRoot.addTodo(text);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (todoModel.count > 0) {
                                todoListView.currentIndex = 0; todoListView.forceActiveFocus(); event.accepted = true;
                            }
                        } else if (event.key === Qt.Key_Delete) {
                            if (text === "" && todoModel.count === 0 && todoRoot.activeCategory !== "") {
                                todoRoot.deleteActiveCategory(); event.accepted = true;
                            }
                        }
                    }

                    Text {
                        text: "Add a task and press [Enter]..."
                        color: todoRoot.placeholderTextColor
                        visible: parent.text === ""
                        anchors.fill: parent
                        font.pixelSize: 20
                        font.family: todoRoot.todoFontFamily
                    }
                }
            }
        }

        // C. SCROLLABLE TASKS LIST
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: todoRoot.activeCategory !== ""

            ListView {
                id: todoListView
                anchors.fill: parent
                model: todoModel
                spacing: 8
                highlightFollowsCurrentItem: false
                focus: true

                // Global list keyboard navigation controller
                Keys.onPressed: (event) => {
                    var isAltShiftPressed = (event.modifiers & Qt.AltModifier) && (event.modifiers & Qt.ShiftModifier);

                    if (isAltShiftPressed) { // Intercept Alt+Shift+Up/Down to shift task orders dynamically
                        if (event.key === Qt.Key_Up) {
                            todoRoot.moveTodo(currentIndex, true);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            todoRoot.moveTodo(currentIndex, false);
                            event.accepted = true;
                        }
                    } else if (event.key === Qt.Key_Up) {
                        if (currentIndex === 0) { taskInput.forceActiveFocus(); event.accepted = true; }
                    } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        // Enter/Return as well as Space toggles the completed state of the selected task card
                        var item = todoModel.get(currentIndex);
                        if (item) { todoRoot.toggleTodo(item.id, item.completed); event.accepted = true; }
                    } else if (event.key === Qt.Key_Delete) {
                        var delItem = todoModel.get(currentIndex);
                        if (delItem) { todoRoot.deleteTodo(delItem.id); event.accepted = true; }
                    } else if (event.key === Qt.Key_E) {
                        var editItem = todoModel.get(currentIndex);
                        if (editItem) { todoRoot.editingTaskId = editItem.id; event.accepted = true; }
                    }
                }

                delegate: Rectangle {
                    id: delegateCard
                    width: todoListView.width - 16
                    height: isThisItemEditing ? Math.max(50, inlineEditLayout.implicitHeight + 16 + 24) : Math.max(50, taskRowLayout.implicitHeight + 16)
                    color: todoRoot.fieldBg
                    radius: Math.max(4, todoRoot.defaultCardRadius - 4)
                    border.color: isThisItemEditing ? ((typeof shell !== 'undefined' && shell.theme && shell.theme.base08) ? shell.theme.base08 : "#fb4934") : ((ListView.isCurrentItem && todoListView.activeFocus) ? todoRoot.innerCardActiveBorder : todoRoot.innerCardInactiveBorder)
                    border.width: (isThisItemEditing || (ListView.isCurrentItem && todoListView.activeFocus)) ? todoRoot.innerCardActiveThickness : (todoRoot.globalBorderWidth + 1)

                    readonly property bool isThisItemEditing: todoRoot.editingTaskId === model.id

                    RowLayout {
                        id: taskRowLayout
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 10
                        visible: !delegateCard.isThisItemEditing

                        Text {
                            text: model.task
                            font.family: todoRoot.todoFontFamily
                            font.pixelSize: 20
                            font.strikeout: model.completed
                            color: model.completed ? todoRoot.placeholderTextColor : todoRoot.titleColor
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            Layout.alignment: Qt.AlignVerticalCenter
                        }
                    }

                    Item {
                        id: inlineEditLayout
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 8; anchors.bottomMargin: 32
                        visible: delegateCard.isThisItemEditing
                        property real implicitHeight: inlineEditInput.implicitHeight

                        TextEdit {
                            id: inlineEditInput
                            anchors.fill: parent
                            font.family: todoRoot.todoFontFamily
                            font.pixelSize: 20
                            color: todoRoot.titleColor
                            wrapMode: Text.Wrap
                            selectByMouse: true
                            focus: delegateCard.isThisItemEditing

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    todoRoot.saveInlineEdit(model.id, text.trim()); event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    todoRoot.cancelInlineEdit(); event.accepted = true;
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        visible: !delegateCard.isThisItemEditing
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { todoListView.currentIndex = index; todoRoot.toggleTodo(model.id, model.completed); }
                    }

                    onIsThisItemEditingChanged: {
                        if (isThisItemEditing) {
                            inlineEditInput.text = model.task; inlineEditInput.forceActiveFocus(); inlineEditInput.cursorPosition = inlineEditInput.text.length;
                        }
                    }
                }
            }
        }

        // D. EMPTY SLATE PLACEHOLDER
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
            visible: todoRoot.activeCategory === ""

            ColumnLayout {
                anchors.centerIn: parent; spacing: 10
                Text { text: "🗂️"; font.pixelSize: todoRoot.globalFontSize * 2; Layout.alignment: Qt.AlignHCenter }
                Text { text: "No Active Boards/Lists Found"; font.family: todoRoot.todoFontFamily; font.pixelSize: todoRoot.globalFontSize; font.bold: true; color: todoRoot.placeholderTextColor; Layout.alignment: Qt.AlignHCenter }
                Text { text: "Click 'New List' at the top to create your first board!"; font.family: todoRoot.todoFontFamily; font.pixelSize: todoRoot.globalFontSize - 4; color: todoRoot.placeholderTextColor; Layout.alignment: Qt.AlignHCenter }
            }
        }

        // E. FILTER CAP BAR (HIGH-PERFORMANCE MODEL REPEATER)
        RowLayout {
            id: bottomFilterBarLayout
            Layout.fillWidth: true
            spacing: 15
            visible: todoRoot.activeCategory !== ""

            Text {
                text: "Filter:"
                font.family: todoRoot.todoFontFamily
                font.pixelSize: 20
                color: (typeof shell !== 'undefined' && shell.theme) ? shell.theme.base05 : "#ebdbb2"
                Layout.alignment: Qt.AlignVerticalCenter
            }

            Repeater {
                model: ["All", "Active", "Completed"]
                delegate: Rectangle {
                    width: filterText.implicitWidth + todoRoot.globalFontSize
                    height: todoRoot.pillBtnHeight
                    radius: todoRoot.pillBtnRadius
                    color: "transparent"
                    border.color: todoRoot.filterMode === modelData ? todoRoot.innerCardActiveBorder : todoRoot.innerCardInactiveBorder
                    border.width: todoRoot.filterMode === modelData ? todoRoot.innerCardActiveThickness : (todoRoot.globalBorderWidth + 1)
                    Layout.alignment: Qt.AlignVerticalCenter

                    Text {
                        id: filterText
                        text: modelData
                        font.family: todoRoot.todoFontFamily
                        font.pixelSize: todoRoot.fontButtonSize
                        font.bold: true
                        color: todoRoot.filterMode === modelData ? todoRoot.titleColor : todoRoot.textWriteColor
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: todoRoot.filterMode = modelData
                    }
                }
            }

            Item { Layout.fillWidth: true } // Spacer

            Rectangle {
                id: helpTriggerBtn
                width: todoRoot.pillBtnHeight; height: todoRoot.pillBtnHeight; radius: width / 2
                color: "transparent"
                border.color: todoRoot.innerCardInactiveBorder; border.width: (todoRoot.globalBorderWidth + 1)
                Layout.alignment: Qt.AlignVerticalCenter

                Text { text: "?"; font.family: todoRoot.todoFontFamily; font.pixelSize: todoRoot.fontButtonSize; font.bold: true; color: todoRoot.textWriteColor; anchors.centerIn: parent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: helpOverlay.visible = true }
            }
        }
    }

    // ============================================================================
    // F. ADD NEW LIST MODAL
    // ============================================================================
    Rectangle {
        id: addListOverlay
        anchors.fill: parent; color: "#F40F0F0F"; visible: false; z: 200

        MouseArea { anchors.fill: parent; onClicked: { addListOverlay.visible = false; if (todoRoot.activeCategory !== "") taskInput.forceActiveFocus(); } }

        Rectangle {
            width: 400; height: Math.max(180, innerColumn.implicitHeight + todoRoot.todoPadding * 2)
            color: todoRoot.modalBoxBg; border.color: todoRoot.innerCardActiveBorder; border.width: todoRoot.innerCardActiveThickness; radius: todoRoot.defaultCardRadius; anchors.centerIn: parent

            MouseArea { anchors.fill: parent }

            Column {
                id: innerColumn
                anchors.fill: parent; anchors.margins: todoRoot.todoPadding; spacing: 15

                Text { text: "CREATE NEW LIST"; font.family: todoRoot.todoFontFamily; font.pixelSize: todoRoot.globalFontSize; font.bold: true; color: todoRoot.titleColor }

                Rectangle {
                    width: parent.width; height: Math.max(40, listNameInput.implicitHeight + 16)
                    color: todoRoot.fieldBg; border.color: listNameInput.activeFocus ? todoRoot.innerCardActiveBorder : todoRoot.innerCardInactiveBorder; border.width: todoRoot.globalBorderWidth; radius: 6

                    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: listNameInput.forceActiveFocus() }

                    Item {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; anchors.topMargin: 8; anchors.bottomMargin: 8

                        TextEdit {
                            id: listNameInput
                            anchors.fill: parent
                            font.family: todoRoot.todoFontFamily; font.pixelSize: todoRoot.globalFontSize - 2; color: todoRoot.textWriteColor; focus: true; wrapMode: Text.Wrap; selectByMouse: true

                            Text { text: "Enter list name..."; color: todoRoot.placeholderTextColor; visible: parent.text === ""; font.pixelSize: parent.font.pixelSize; font.family: parent.font.family }

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    var name = text.trim();
                                    if (name !== "") {
                                        try {
                                            var db = todoRoot.getDatabase();
                                            db.transaction(function(tx) { tx.executeSql('INSERT OR IGNORE INTO categories (name) VALUES (?)', [name]); });
                                            todoRoot.loadCategories(); todoRoot.activeCategory = name; todoRoot.loadTodos();
                                        } catch (e) { console.error("[Todo DB Error] List creation failed: ", e); }
                                    }
                                    addListOverlay.visible = false; taskInput.forceActiveFocus(); event.accepted = true;
                                }
                            }
                        }
                    }
                }

                Text { text: "Press [Enter] to Save  •  [ESC] to Cancel"; font.family: todoRoot.todoFontFamily; font.pixelSize: todoRoot.globalFontSize - 6; color: todoRoot.placeholderTextColor; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }

        Shortcut { sequence: "Escape"; enabled: addListOverlay.visible; onActivated: { addListOverlay.visible = false; if (todoRoot.activeCategory !== "") taskInput.forceActiveFocus(); } }
    }

    // ============================================================================
    // H. HELP CHEATSHEET MODAL
    // ============================================================================
    Rectangle {
        id: helpOverlay
        anchors.fill: parent; color: "#F40F0F0F"; visible: false; z: 220

        MouseArea { anchors.fill: parent; onClicked: { helpOverlay.visible = false; if (todoRoot.activeCategory !== "") taskInput.forceActiveFocus(); } }

        Rectangle {
            width: 500; height: Math.max(420, helpColumn.implicitHeight + todoRoot.todoPadding * 2) // Expanded to fit new re-ordering keys smoothly
            color: todoRoot.modalBoxBg; border.color: todoRoot.innerCardActiveBorder; border.width: todoRoot.innerCardActiveThickness; radius: todoRoot.defaultCardRadius; anchors.centerIn: parent

            MouseArea { anchors.fill: parent }

            Column {
                id: helpColumn
                anchors.fill: parent; anchors.margins: todoRoot.todoPadding; spacing: 15

                Text { text: "TODO KEYBOARD CONTROLS"; font.family: todoRoot.todoFontFamily; font.pixelSize: todoRoot.globalFontSize; font.bold: true; color: todoRoot.titleColor; anchors.horizontalCenter: parent.horizontalCenter }
                Rectangle { width: parent.width; height: 1; color: todoRoot.innerCardInactiveBorder }

                Grid {
                    columns: 2; columnSpacing: 20; rowSpacing: 10; width: parent.width
                    Text { text: "Alt + ← / →"; font.bold: true; color: todoRoot.titleColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Cycle Category Boards"; color: todoRoot.textWriteColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Ctrl + ← / →"; font.bold: true; color: todoRoot.titleColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Cycle Status Filters"; color: todoRoot.textWriteColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Ctrl + N"; font.bold: true; color: todoRoot.titleColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Create New Board List"; color: todoRoot.textWriteColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Ctrl + D"; font.bold: true; color: todoRoot.titleColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Remove Selected Board List"; color: todoRoot.textWriteColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "↓ Arrow (on input)"; font.bold: true; color: todoRoot.titleColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Enter Task Navigation List"; color: todoRoot.textWriteColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "↑ Arrow (on first item)"; font.bold: true; color: todoRoot.titleColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Return Focus to Typing Input"; color: todoRoot.textWriteColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Alt + Shift + ↑ / ↓"; font.bold: true; color: todoRoot.titleColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily } // Added re-ordering keys!
                    Text { text: "Move Task Up / Down in List"; color: todoRoot.textWriteColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Space / Enter"; font.bold: true; color: todoRoot.titleColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily } // Updated to include Enter!
                    Text { text: "Toggle Task Completion State"; color: todoRoot.textWriteColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "E"; font.bold: true; color: todoRoot.titleColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Edit Task Inline (Press Enter/ESC)"; color: todoRoot.textWriteColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Delete"; font.bold: true; color: todoRoot.titleColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                    Text { text: "Remove Selected Task Card"; color: todoRoot.textWriteColor; font.pixelSize: todoRoot.globalFontSize - 5; font.family: todoRoot.todoFontFamily }
                }

                Item { width: 1; height: 10 }
                Text { text: "Press [ESC] or Click Outside to Dismiss"; font.family: todoRoot.todoFontFamily; font.pixelSize: todoRoot.globalFontSize - 6; color: todoRoot.placeholderTextColor; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }

        Shortcut { sequence: "Escape"; enabled: helpOverlay.visible; onActivated: { helpOverlay.visible = false; if (todoRoot.activeCategory !== "") taskInput.forceActiveFocus(); } }
    }
}
