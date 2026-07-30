import QtQuick

Item {
    id: rngBackend

    property var diceWindowInstance: null

    function toggleWindow() {
        if (diceWindowInstance) {
            diceWindowInstance.visible = !diceWindowInstance.visible;
        }
    }

    function showWindow() {
        if (diceWindowInstance) {
            diceWindowInstance.visible = true;
        }
    }

    function hideWindow() {
        if (diceWindowInstance) {
            diceWindowInstance.visible = false;
        }
    }
}
