import QtQuick
import QtQuick.Controls 2
import QtQuick.Layouts 1.15
import "../backend"

Item {
    id: viewRoot

    required property TodoEngine engine
    property var theme: null

    readonly property color modalBoxBg: (theme && theme.base00) ? theme.base00 : "#11111b"
    readonly property color fieldBg: (theme && theme.base00) ? theme.base00 : "#11111b"
    readonly property color placeholderTextColor: (theme && theme.base0B) ? theme.base0B : "#545454"
    readonly property color textWriteColor: (theme && theme.base06) ? theme.base06 : "#ebdbb2"
    readonly property color innerCardActiveBorder: (theme && theme.innerBorderColor) ? theme.innerBorderColor : "#fabd2f"
    readonly property color innerCardInactiveBorder: (theme && theme.outerBorderColor) ? theme.outerBorderColor : "#003399"
    readonly property color titleColor: innerCardActiveBorder
    readonly property string todoFontFamily: (theme && theme.fontFamily) ? theme.fontFamily : "monospace"
    readonly property int globalFontSize: (theme && theme.globalFontSize) ? theme.globalFontSize : 14
    readonly property int globalBorderWidth: (theme && theme.globalBorderWidth) ? theme.globalBorderWidth : 2
    readonly property int defaultCardRadius: (theme && theme.defaultCardRadius) ? theme.defaultCardRadius : 10
    readonly property int innerCardActiveThickness: globalBorderWidth + 2

    readonly property int fieldHeight: (shell && shell.settingsManager)
        ? shell.settingsManager.getWindowFieldHeight("todo", 58) : 58
    readonly property int overlayFontSize: (shell && shell.settingsManager && shell.settingsManager.overlayFontSize > 0)
        ? shell.settingsManager.overlayFontSize : 18

    property int pillBtnHeight: Math.max(44, globalFontSize + 24)
    property int pillBtnRadius: pillBtnHeight / 2

    focus: true

    function clearAndFocus() {
        if (engine.activeCategory !== "") {
            Qt.callLater(() => taskInput.forceActiveFocus());
        }
    }

    Component.onCompleted: Qt.callLater(() => clearAndFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => clearAndFocus())

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: (viewRoot.theme && viewRoot.theme.globalPadding) ? viewRoot.theme.globalPadding : 16
        spacing: 14

        // Boards Row
        Rectangle {
            Layout.fillWidth: true
            height: viewRoot.pillBtnHeight
            color: "transparent"

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

                    delegate: Rectangle {
                        width: catText.implicitWidth + 24
                        height: viewRoot.pillBtnHeight
                        radius: viewRoot.pillBtnRadius
                        color: "transparent"
                        border.color: engine.activeCategory === model.name ? viewRoot.innerCardActiveBorder : viewRoot.innerCardInactiveBorder
                        border.width: engine.activeCategory === model.name ? viewRoot.innerCardActiveThickness : 1

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
                                todoListView.forceActiveFocus();
                            }
                        }
                    }
                }

                Rectangle {
                    width: addListText.implicitWidth + 24
                    height: viewRoot.pillBtnHeight
                    radius: viewRoot.pillBtnRadius
                    color: "transparent"
                    border.color: viewRoot.innerCardActiveBorder
                    border.width: 1

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

                Rectangle {
                    visible: engine.activeCategory !== ""
                    width: removeListText.implicitWidth + 24
                    height: viewRoot.pillBtnHeight
                    radius: viewRoot.pillBtnRadius
                    color: "transparent"
                    border.color: (theme && theme.base08) ? theme.base08 : "#ff5555"
                    border.width: 1

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
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: viewRoot.fieldHeight
            Layout.minimumHeight: viewRoot.fieldHeight
            Layout.maximumHeight: viewRoot.fieldHeight
            height: viewRoot.fieldHeight
            color: viewRoot.fieldBg
            radius: viewRoot.defaultCardRadius
            border.color: taskInput.activeFocus ? viewRoot.innerCardActiveBorder : viewRoot.innerCardInactiveBorder
            border.width: taskInput.activeFocus ? viewRoot.innerCardActiveThickness : 1
            visible: engine.activeCategory !== ""

            Item {
                anchors.fill: parent
                anchors.margins: 12
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

        // Task List View with Discrete Mouse Checkbox
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: engine.activeCategory !== ""

            ListView {
                id: todoListView
                anchors.fill: parent
                model: engine.todoModel
                spacing: 8
                focus: engine.editingTaskId === -1

                Keys.onPressed: (event) => {
                    if (engine.editingTaskId !== -1) return;
                    var isAltShiftPressed = (event.modifiers & Qt.AltModifier) && (event.modifiers & Qt.ShiftModifier);
                    if (isAltShiftPressed) {
                        if (event.key === Qt.Key_Up) { engine.moveTodo(currentIndex, true); event.accepted = true; }
                        else if (event.key === Qt.Key_Down) { engine.moveTodo(currentIndex, false); event.accepted = true; }
                    } else if (event.key === Qt.Key_Up) {
                        if (currentIndex <= 0) taskInput.forceActiveFocus();
                        else currentIndex--;
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

                delegate: Rectangle {
                    id: delegateCard
                    readonly property bool isSelected: index === todoListView.currentIndex
                    readonly property bool isThisItemEditing: engine.editingTaskId === model.id

                    width: todoListView.width - 12
                    height: isThisItemEditing ? Math.max(54, inlineEditLayout.implicitHeight + 16) : Math.max(50, taskRowLayout.implicitHeight + 16)
                    color: viewRoot.fieldBg
                    radius: Math.max(4, viewRoot.defaultCardRadius - 4)
                    border.color: isThisItemEditing ? ((theme && theme.base08) ? theme.base08 : "#ff5555") : (isSelected ? viewRoot.innerCardActiveBorder : viewRoot.innerCardInactiveBorder)
                    border.width: isSelected || isThisItemEditing ? viewRoot.innerCardActiveThickness : 1

                    onIsThisItemEditingChanged: {
                        if (isThisItemEditing) {
                            Qt.callLater(() => {
                                inlineEditInput.forceActiveFocus();
                                inlineEditInput.cursorPosition = inlineEditInput.text.length;
                            });
                        }
                    }

                    RowLayout {
                        id: taskRowLayout
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12
                        visible: !delegateCard.isThisItemEditing

                        // 1. Interactive Checkbox (Mouse click only toggles when clicking this box)
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 4
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
                                    engine.toggleTodo(model.id, model.completed);
                                }
                            }
                        }

                        // 2. Task Text (Clicking selects the item without toggling)
                        Text {
                            text: model.task
                            font.family: viewRoot.todoFontFamily
                            font.pixelSize: viewRoot.overlayFontSize
                            font.strikeout: model.completed
                            color: model.completed ? viewRoot.placeholderTextColor : viewRoot.titleColor
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                    }

                    // Inline Editor
                    Item {
                        id: inlineEditLayout
                        anchors.fill: parent
                        anchors.margins: 8
                        visible: delegateCard.isThisItemEditing
                        property real implicitHeight: inlineEditInput.implicitHeight

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

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    engine.saveInlineEdit(model.id, text);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    engine.editingTaskId = -1;
                                    todoListView.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // Card Selection Click Area (Does NOT toggle completion)
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
                            engine.editingTaskId = model.id;
                        }
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
                delegate: Rectangle {
                    width: filterText.implicitWidth + 24
                    height: viewRoot.pillBtnHeight
                    radius: viewRoot.pillBtnRadius
                    color: "transparent"
                    border.color: engine.filterMode === modelData ? viewRoot.innerCardActiveBorder : viewRoot.innerCardInactiveBorder
                    border.width: engine.filterMode === modelData ? viewRoot.innerCardActiveThickness : 1
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

        Rectangle {
            width: 400; height: 180
            color: viewRoot.modalBoxBg
            border.color: viewRoot.innerCardActiveBorder
            border.width: viewRoot.innerCardActiveThickness
            radius: viewRoot.defaultCardRadius
            anchors.centerIn: parent

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                Text { text: "CREATE NEW LIST"; font.bold: true; font.pixelSize: 16; color: viewRoot.titleColor }
                Rectangle {
                    width: parent.width; height: 40
                    color: viewRoot.fieldBg
                    border.color: viewRoot.innerCardActiveBorder
                    border.width: 1; radius: 6
                    TextInput {
                        id: listNameInput
                        anchors.fill: parent
                        anchors.margins: 8
                        font.pixelSize: 16
                        color: viewRoot.textWriteColor
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
