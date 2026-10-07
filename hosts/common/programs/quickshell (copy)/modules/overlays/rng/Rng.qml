import "../../common" as Common
import QtQuick

Item {
    id: rngBackend

    property var diceWindowInstance: null

    function toggleWindow() {
        if (diceWindowInstance) {
            if (typeof diceWindowInstance.toggleWithTarget === "function") {
                diceWindowInstance.toggleWithTarget();
            } else {
                diceWindowInstance.visible = !diceWindowInstance.visible;
            }
        }
    }

    function showWindow() {
        if (diceWindowInstance) {
            if (typeof diceWindowInstance.openWithTarget === "function") {
                diceWindowInstance.openWithTarget();
            } else {
                diceWindowInstance.visible = true;
            }
        }
    }

    function hideWindow() {
        if (diceWindowInstance) {
            diceWindowInstance.visible = false;
        }
    }
}
