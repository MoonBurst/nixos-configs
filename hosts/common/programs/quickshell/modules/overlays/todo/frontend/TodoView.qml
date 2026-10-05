import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend"
import "../../../style" as Style
import "../../../common/Utils.js" as Utils

Item {
    id: viewRoot

    required property TodoEngine engine
    property var theme: null
    property var settingsManager: null

    readonly property color modalBoxBg: (theme && theme.base00) ? theme.base00 : "#11111b"
    readonly property color fieldBg: (theme && theme.base00) ? theme.base00 : "#11111b"
    readonly property color placeholderTextColor: (theme && theme.base0B) ? theme.base0B : "#545454"
    readonly property color textWriteColor: (theme && theme.base06) ? theme.base06 : "#ebdbb2"
    readonly property color innerCardActiveBorder: (theme && theme.innerBorderColor) ? theme.innerBorderColor : "#fabd2f"
    readonly property color innerCardInactiveBorder: (theme && theme.outerBorderColor) ? theme.outerBorderColor : "#003399"
    readonly property color titleColor: innerCardActiveBorder
    readonly property string todoFontFamily: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
    readonly property int globalFontSize: (theme && theme.globalFontSize) ? theme.globalFontSize : 14
    readonly property int defaultCardRadius: (theme && theme.defaultCardRadius) ? theme.defaultCardRadius : 10

    readonly property int controlBorderWidth: (settingsManager && settingsManager.controlBorderWidth)
        ? settingsManager.controlBorderWidth
        : ((theme && theme.controlBorderWidth) ? theme.controlBorderWidth : 2)

    readonly property int fieldHeight: settingsManager
        ? settingsManager.getWindowFieldHeight("todo", 58) : 58
    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize : 18

    readonly property var inputPad: Utils.getSafeInputPadding(settingsManager)

    property int pillBtnHeight: Math.max(44, globalFontSize + 24)
    property int todoRowHeight: Math.max(48, overlayFontSize + 22)

    focus: true

    function clearAndFocus() {
        if (engine.activeCategory !== "") {
            todoListView.currentIndex = -1;
            Qt.callLater(() => taskInput.forceActiveFocus());
        }
    }

    function forceExitEdit(savedIndex) {
        engine.editingTaskId = -1;
        todoListView.currentIndex = -1;
        todoListView.forceActiveFocus();
        Qt.callLater(() => {
            todoListView.currentIndex = savedIndex;
        });
    }

    Component.onCompleted: Qt.callLater(() => clearAndFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => clearAndFocus())

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 14

        // Boards Row
        Item {
            Layout.fillWidth: true
            height: viewRoot.pillBtnHeight

            RowLayout {
                anchors.fill: parent
                spacing: 10

                ListView {
                    id: categoryListView
                    Layout.fillWidth: true
                    height: viewRoot.pillBtnHeight
                    orientation: ListView.Horizontal
                    spacing: 8
                    model: engine.categoryModel
                    clip: true
                    cacheBuffer: 200

                    delegate: Item {
                        width: catText.implicitWidth + 28
                        height: viewRoot.pillBtnHeight

                        Style.ShapeBox {
                            anchors.fill: parent
                            role: "input"
                            color: "transparent"
                            borderColor: engine.activeCategory === model.name ? viewRoot.innerCardActiveBorder : viewRoot.innerCardInactiveBorder
                            borderWidth: viewRoot.controlBorderWidth
                            slantWidth: 10
                        }

                        Text {
                            id: catText
                            text: model.name
                            font.family: viewRoot.todoFontFamily
                            font.pixelSize: viewRoot.overlayFontSize - 2
                            font.bold: true
                            color: engine.activeCategory === model.name ? viewRoot.titleColor : viewRoot.textWriteColor
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                engine.activeCategory = model.name;
                                todoListView.currentIndex = -1;
                                taskInput.forceActiveFocus();
                            }
                        }
                    }
                }

                Item {
                    width: addListText.implicitWidth + 28
                    height: viewRoot.pillBtnHeight

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        color: "transparent"
                        borderColor: viewRoot.innerCardActiveBorder
                        borderWidth: viewRoot.controlBorderWidth
                        slantWidth: 10
                    }

                    Text {
                        id: addListText
                        text: "New List"
                        font.family: viewRoot.todoFontFamily
                        font.pixelSize: viewRoot.overlayFontSize - 2
                        font.bold: true
                        color: viewRoot.innerCardActiveBorder
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            listNameInput.text = "";
                            addListOverlay.visible = true;
                            listNameInput.forceActiveFocus();
                        }
                    }
                }

                Item {
                    visible: engine.activeCategory !== ""
                    width: removeListText.implicitWidth + 28
                    height: viewRoot.pillBtnHeight

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        color: "transparent"
                        borderColor: (theme && theme.base08) ? theme.base08 : "#ff5555"
                        borderWidth: viewRoot.controlBorderWidth
                        slantWidth: 10
                    }

                    Text {
                        id: removeListText
                        text: "Remove List"
                        font.family: viewRoot.todoFontFamily
                        font.pixelSize: viewRoot.overlayFontSize - 2
                        font.bold: true
                        color: (theme && theme.base08) ? theme.base08 : "#ff5555"
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: engine.deleteActiveCategory()
                    }
                }
            }
        }

        // Input Field Box
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: viewRoot.fieldHeight
            Layout.minimumHeight: viewRoot.fieldHeight
            Layout.maximumHeight: viewRoot.fieldHeight
            height: viewRoot.fieldHeight
            visible: engine.activeCategory !== ""

            Style.ShapeBox {
                anchors.fill: parent
                role: "input"
                color: viewRoot.fieldBg
                borderColor: taskInput.activeFocus ? viewRoot.innerCardActiveBorder : viewRoot.innerCardInactiveBorder
                borderWidth: viewRoot.controlBorderWidth
                slantWidth: 14
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: viewRoot.inputPad.left
                anchors.rightMargin: viewRoot.inputPad.right
                anchors.topMargin: 10
                anchors.bottomMargin: 10

                TextEdit {
                    id: taskInput
                    anchors.fill: parent
                    font.family: viewRoot.todoFontFamily
                    font.pixelSize: viewRoot.overlayFontSize
                    color: viewRoot.titleColor
                    wrapMode: Text.Wrap
                    selectByMouse: true
                    verticalAlignment: TextEdit.AlignVCenter

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            engine.addTodo(text);
                            text = "";
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (engine.todoModel.count > 0) {
                                todoListView.currentIndex = 0;
                                todoListView.forceActiveFocus();
                            }
                            event.accepted = true;
                        }
                    }

                    Text {
                        text: "Add a task and press [Enter]..."
                        color: viewRoot.placeholderTextColor
                        visible: parent.text === ""
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: viewRoot.overlayFontSize
                    }
                }
            }
        }

        // Task List — ListView handles its own scrolling and clipping.
        // The per-delegate TextEdit for inline editing is now lazily
        // instantiated via a Loader so scrolling cost stays flat regardless
        // of how many tasks exist.
        ListView {
            id: todoListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: engine.activeCategory !== ""
            model: engine.todoModel
            spacing: 8
            focus: engine.editingTaskId === -1
            cacheBuffer: 600
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Keys.onPressed: (event) => {
                if (engine.editingTaskId !== -1) return;
                var isAltShiftPressed = (event.modifiers & Qt.AltModifier) && (event.modifiers & Qt.ShiftModifier);
                if (isAltShiftPressed) {
                    if (event.key === Qt.Key_Up) { engine.moveTodo(currentIndex, true); event.accepted = true; }
                    else if (event.key === Qt.Key_Down) { engine.moveTodo(currentIndex, false); event.accepted = true; }
                } else if (event.key === Qt.Key_Up) {
                    if (currentIndex <= 0) {
                        todoListView.currentIndex = -1;
                        taskInput.forceActiveFocus();
                    } else {
                        currentIndex--;
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    if (currentIndex < count - 1) currentIndex++;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    var item = engine.todoModel.get(currentIndex);
                    if (item) { engine.toggleTodo(item.id, item.completed); event.accepted = true; }
                } else if (event.key === Qt.Key_Delete) {
                    var delItem = engine.todoModel.get(currentIndex);
                    if (delItem) { engine.deleteTodo(delItem.id); event.accepted = true; }
                } else if (event.key === Qt.Key_E) {
                    var editItem = engine.todoModel.get(currentIndex);
                    if (editItem) { engine.editingTaskId = editItem.id; event.accepted = true; }
                }
            }

            // Delegate is now a plain positioned Item with no Row / no
            // anchors.fill Row that would force a second layout pass per
            // scroll frame. The row height is derived directly from the
            // wrapped Text contentHeight, so boxes grow to fit every line.
            readonly property int scrollbarGutter: 16

            delegate: Item {
                id: delegateCard
                readonly property bool isSelected: (index === todoListView.currentIndex) && todoListView.activeFocus
                readonly property bool isThisItemEditing: engine.editingTaskId === model.id

                // Width is a plain function of list width and a constant
                // gutter — no dependency on ScrollBar.visible, which used to
                // cause a full relayout every time the bar faded in or out.
                width: todoListView.width - todoListView.scrollbarGutter
                height: isThisItemEditing
                    ? Math.max(viewRoot.todoRowHeight, editLoader.item ? editLoader.item.implicitHeight + 24 : 60)
                    : Math.max(viewRoot.todoRowHeight, taskText.contentHeight + 20)

                Style.ShapeBox {
                    id: delegateBg
                    anchors.fill: parent
                    role: "input"
                    color: viewRoot.fieldBg
                    borderColor: delegateCard.isThisItemEditing
                        ? ((theme && theme.base08) ? theme.base08 : "#ff5555")
                        : (delegateCard.isSelected ? viewRoot.innerCardActiveBorder : viewRoot.innerCardInactiveBorder)
                    borderWidth: viewRoot.controlBorderWidth
                    slantWidth: 10
                }

                // Checkbox — positioned by the ShapeBox's own padding so it
                // always clears the hexagon chamfer and any thick border.
                Rectangle {
                    id: checkbox
                    x: delegateBg.leftPadding + 4
                    y: delegateCard.isThisItemEditing ? (delegateCard.height - height) / 2 : delegateBg.topPadding + 2
                    width: 24
                    height: 24
                    radius: 4
                    visible: !delegateCard.isThisItemEditing
                    color: model.completed ? viewRoot.innerCardActiveBorder : "transparent"
                    border.color: model.completed ? viewRoot.innerCardActiveBorder : viewRoot.placeholderTextColor
                    border.width: 1.5

                    Text {
                        anchors.centerIn: parent
                        visible: model.completed
                        text: "✔"
                        font.bold: true
                        font.pixelSize: 13
                        color: (theme && theme.base00) ? theme.base00 : "#000"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            todoListView.currentIndex = index;
                            todoListView.forceActiveFocus();
                            engine.toggleTodo(model.id, model.completed);
                        }
                    }
                }

                // Task text — width is set before contentHeight is queried,
                // and the delegate height above reads contentHeight so the
                // box always fits the wrapped text exactly.
                Text {
                    id: taskText
                    x: checkbox.x + checkbox.width + 12
                    y: delegateBg.topPadding + 2
                    width: delegateCard.width - x - delegateBg.rightPadding - 4
                    visible: !delegateCard.isThisItemEditing
                    text: model.task
                    font.family: viewRoot.todoFontFamily
                    font.pixelSize: viewRoot.overlayFontSize
                    font.strikeout: model.completed
                    color: model.completed ? viewRoot.placeholderTextColor : viewRoot.titleColor
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                }

                Loader {
                    id: editLoader
                    anchors.fill: parent
                    anchors.margins: 8
                    active: delegateCard.isThisItemEditing
                    visible: active
                    sourceComponent: editFieldComponent
                }

                Component {
                    id: editFieldComponent
                    TextEdit {
                        id: inlineEditInput
                        anchors.fill: parent
                        font.pixelSize: viewRoot.overlayFontSize
                        font.family: viewRoot.todoFontFamily
                        color: viewRoot.titleColor
                        text: model.task
                        wrapMode: Text.Wrap
                        selectByMouse: true
                        verticalAlignment: TextEdit.AlignVCenter

                        Component.onCompleted: Qt.callLater(() => {
                            inlineEditInput.forceActiveFocus();
                            inlineEditInput.cursorPosition = inlineEditInput.text.length;
                        });

                        onActiveFocusChanged: {
                            if (!activeFocus && engine.editingTaskId === model.id) {
                                viewRoot.forceExitEdit(index);
                            }
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                engine.saveInlineEdit(model.id, text);
                                viewRoot.forceExitEdit(index);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                viewRoot.forceExitEdit(index);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                engine.saveInlineEdit(model.id, text);
                                engine.editingTaskId = -1;
                                todoListView.forceActiveFocus();
                                if (index > 0) todoListView.currentIndex = index - 1;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                engine.saveInlineEdit(model.id, text);
                                engine.editingTaskId = -1;
                                todoListView.forceActiveFocus();
                                if (index < todoListView.count - 1) todoListView.currentIndex = index + 1;
                                event.accepted = true;
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    visible: !delegateCard.isThisItemEditing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        todoListView.currentIndex = index;
                        todoListView.forceActiveFocus();
                    }
                    onDoubleClicked: {
                        todoListView.currentIndex = index;
                        todoListView.forceActiveFocus();
                        engine.editingTaskId = model.id;
                    }
                }
            }
        }

        // Bottom Filter Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 15
            visible: engine.activeCategory !== ""

            Text { text: "Filter:"; font.bold: true; color: (theme && theme.base05) ? theme.base05 : "yellow" }

            Repeater {
                model: ["All", "Active", "Completed"]
                delegate: Item {
                    width: filterText.implicitWidth + 28
                    height: viewRoot.pillBtnHeight

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        color: "transparent"
                        borderColor: engine.filterMode === modelData ? viewRoot.innerCardActiveBorder : viewRoot.innerCardInactiveBorder
                        borderWidth: viewRoot.controlBorderWidth
                        slantWidth: 10
                    }

                    Text {
                        id: filterText; text: modelData; font.bold: true
                        color: engine.filterMode === modelData ? viewRoot.titleColor : viewRoot.textWriteColor
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            engine.filterMode = modelData;
                            todoListView.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }

    // Modal: Add New List
    Rectangle {
        id: addListOverlay
        anchors.fill: parent
        color: "#EE000000"
        visible: false
        z: 200

        MouseArea { anchors.fill: parent }

        Item {
            width: 420; height: 190
            anchors.centerIn: parent

            Style.ShapeBox {
                anchors.fill: parent
                role: "card"
                color: viewRoot.modalBoxBg
                borderColor: viewRoot.innerCardActiveBorder
                borderWidth: (theme && theme.globalBorderWidth) ? theme.globalBorderWidth : 3
            }

            Column {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 15

                Text { text: "CREATE NEW LIST"; font.bold: true; font.pixelSize: 16; color: viewRoot.titleColor }

                Item {
                    width: parent.width; height: 42

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        color: viewRoot.fieldBg
                        borderColor: viewRoot.innerCardActiveBorder
                        borderWidth: viewRoot.controlBorderWidth
                        slantWidth: 10
                    }

                    TextInput {
                        id: listNameInput
                        anchors.fill: parent
                        anchors.margins: 8
                        font.pixelSize: 16
                        color: viewRoot.textWriteColor
                        verticalAlignment: TextInput.AlignVCenter

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                var name = text.trim();
                                if (name !== "") {
                                    var db = engine.getDatabase();
                                    db.transaction(function(tx) { tx.executeSql('INSERT OR IGNORE INTO categories (name) VALUES (?)', [name]); });
                                    engine.loadCategories(); engine.activeCategory = name;
                                }
                                addListOverlay.visible = false;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                addListOverlay.visible = false;
                                event.accepted = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
