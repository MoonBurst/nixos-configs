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

    readonly property int controlBorderWidth: (settingsManager && settingsManager.controlBorderWidth)
        ? settingsManager.controlBorderWidth
        : ((theme && theme.controlBorderWidth) ? theme.controlBorderWidth : 2)

    readonly property int fieldHeight: settingsManager
        ? settingsManager.getWindowFieldHeight("todo", 58) : 58
    readonly property int overlayFontSize: (settingsManager && settingsManager.overlayFontSize > 0)
        ? settingsManager.overlayFontSize : 18

    readonly property var inputPad: Utils.getSafeInputPadding(settingsManager)

    readonly property int pillPaddingH: 80
    property int rowHeight: Math.max(46, overlayFontSize + 26)
    readonly property int rowSpacing: 8

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
        Qt.callLater(() => { todoListView.currentIndex = savedIndex; });
    }

    Component.onCompleted: Qt.callLater(() => clearAndFocus())
    onVisibleChanged: if (visible) Qt.callLater(() => clearAndFocus())

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 14

        // Category pill row
        Item {
            Layout.fillWidth: true
            height: viewRoot.rowHeight

            RowLayout {
                anchors.fill: parent
                spacing: 10

                ListView {
                    id: categoryListView
                    Layout.fillWidth: true
                    height: viewRoot.rowHeight
                    orientation: ListView.Horizontal
                    spacing: 8
                    model: engine.categoryModel
                    clip: true

                    delegate: Item {
                        width: catText.implicitWidth + viewRoot.pillPaddingH
                        height: viewRoot.rowHeight

                        Style.ShapeBox {
                            anchors.fill: parent
                            role: "input"
                            color: "transparent"
                            borderColor: engine.activeCategory === model.name
                                ? viewRoot.innerCardActiveBorder
                                : viewRoot.innerCardInactiveBorder
                            borderWidth: viewRoot.controlBorderWidth
                            slantWidth: 10
                        }

                        Text {
                            id: catText
                            anchors.centerIn: parent
                            text: model.name
                            font.family: viewRoot.todoFontFamily
                            font.pixelSize: viewRoot.overlayFontSize - 2
                            font.bold: true
                            color: engine.activeCategory === model.name ? viewRoot.titleColor : viewRoot.textWriteColor
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
                    width: addListText.implicitWidth + viewRoot.pillPaddingH
                    height: viewRoot.rowHeight

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
                        anchors.centerIn: parent
                        text: "New List"
                        font.family: viewRoot.todoFontFamily
                        font.pixelSize: viewRoot.overlayFontSize - 2
                        font.bold: true
                        color: viewRoot.innerCardActiveBorder
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
                    width: removeListText.implicitWidth + viewRoot.pillPaddingH
                    height: viewRoot.rowHeight

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
                        anchors.centerIn: parent
                        text: "Remove List"
                        font.family: viewRoot.todoFontFamily
                        font.pixelSize: viewRoot.overlayFontSize - 2
                        font.bold: true
                        color: (theme && theme.base08) ? theme.base08 : "#ff5555"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: engine.deleteActiveCategory()
                    }
                }
            }
        }

        // Task input
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: viewRoot.fieldHeight
            Layout.minimumHeight: viewRoot.fieldHeight
            Layout.maximumHeight: viewRoot.fieldHeight
            height: viewRoot.fieldHeight
            visible: engine.activeCategory !== ""

            Style.ShapeBox {
                id: taskInputBg
                anchors.fill: parent
                role: "input"
                color: viewRoot.fieldBg
                borderColor: taskInput.activeFocus ? viewRoot.innerCardActiveBorder : viewRoot.innerCardInactiveBorder
                borderWidth: viewRoot.controlBorderWidth
                slantWidth: 14
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin:   taskInputBg.leftPadding
                anchors.rightMargin:  taskInputBg.rightPadding
                anchors.topMargin:    taskInputBg.topPadding
                anchors.bottomMargin: taskInputBg.bottomPadding

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

        // Task list — snapMode makes scroll move one row at a time, no animation.
        ListView {
            id: todoListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: engine.activeCategory !== ""
            clip: true
            model: engine.todoModel
            spacing: viewRoot.rowSpacing
            focus: engine.editingTaskId === -1

            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            // The key: snap to whole items instead of animating pixel scroll.
            snapMode: ListView.SnapOneItem
            highlightMoveDuration: 0
            highlightResizeDuration: 0

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

            delegate: Item {
                id: delegateCard
                readonly property bool isSelected: (index === todoListView.currentIndex) && todoListView.activeFocus
                readonly property bool isThisItemEditing: engine.editingTaskId === model.id
                width: todoListView.width - 12
                height: viewRoot.rowHeight

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

                Item {
                    id: normalRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin:   delegateBg.leftPadding + 4
                    anchors.rightMargin:  delegateBg.rightPadding + 4
                    visible: !delegateCard.isThisItemEditing

                    Rectangle {
                        id: checkbox
                        width: 22
                        height: 22
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 4
                        color: model.completed ? viewRoot.innerCardActiveBorder : "transparent"
                        border.color: model.completed ? viewRoot.innerCardActiveBorder : viewRoot.placeholderTextColor
                        border.width: 1.5

                        Text {
                            anchors.centerIn: parent
                            visible: model.completed
                            text: "\u2714"
                            font.bold: true
                            font.pixelSize: 12
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

                    Text {
                        id: taskText
                        anchors.left: checkbox.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.task
                        font.family: viewRoot.todoFontFamily
                        font.pixelSize: viewRoot.overlayFontSize
                        font.strikeout: model.completed
                        color: model.completed ? viewRoot.placeholderTextColor : viewRoot.titleColor
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                Loader {
                    id: editLoader
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin:   delegateBg.leftPadding + 4
                    anchors.rightMargin:  delegateBg.rightPadding + 4
                    anchors.topMargin:    6
                    anchors.bottomMargin: 6
                    active: delegateCard.isThisItemEditing
                    visible: active
                    sourceComponent: inlineEditFieldComponent
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

            Component {
                id: inlineEditFieldComponent
                TextEdit {
                    anchors.fill: parent
                    font.pixelSize: viewRoot.overlayFontSize
                    font.family: viewRoot.todoFontFamily
                    color: viewRoot.titleColor
                    text: model.task
                    wrapMode: TextEdit.NoWrap
                    selectByMouse: true
                    verticalAlignment: TextEdit.AlignVCenter
                    clip: true

                    Component.onCompleted: Qt.callLater(() => {
                        forceActiveFocus();
                        cursorPosition = text.length;
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
        }

        // Filter bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 15
            visible: engine.activeCategory !== ""

            Text {
                text: "Filter:"
                font.bold: true
                color: (theme && theme.base05) ? theme.base05 : "yellow"
            }

            Repeater {
                model: ["All", "Active", "Completed"]
                delegate: Item {
                    width: filterText.implicitWidth + viewRoot.pillPaddingH
                    height: viewRoot.rowHeight

                    Style.ShapeBox {
                        anchors.fill: parent
                        role: "input"
                        color: "transparent"
                        borderColor: engine.filterMode === modelData ? viewRoot.innerCardActiveBorder : viewRoot.innerCardInactiveBorder
                        borderWidth: viewRoot.controlBorderWidth
                        slantWidth: 10
                    }

                    Text {
                        id: filterText
                        anchors.centerIn: parent
                        text: modelData
                        font.bold: true
                        color: engine.filterMode === modelData ? viewRoot.titleColor : viewRoot.textWriteColor
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

                Text {
                    text: "CREATE NEW LIST"
                    font.bold: true
                    font.pixelSize: 16
                    color: viewRoot.titleColor
                }

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
                                    db.transaction(function(tx) {
                                        tx.executeSql('INSERT OR IGNORE INTO categories (name) VALUES (?)', [name]);
                                    });
                                    engine.loadCategories();
                                    engine.activeCategory = name;
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
