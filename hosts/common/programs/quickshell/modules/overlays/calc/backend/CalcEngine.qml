import QtQuick
import Quickshell
import "../../../common/Utils.js" as Utils

QtObject {
    id: engine

    property string expression: ""
    property string resultString: ""
    property int selectedGridIndex: 0

    onExpressionChanged: evaluate(expression)

    function evaluate(expr) {
        var res = Utils.evaluate(expr, true);
        resultString = (res !== null && res !== undefined) ? res : "";
        selectedGridIndex = 0;
    }

    function copyResult(val) {
        if (!val || val.trim() === "") return;
        Quickshell.clipboardText = val.trim();
        Quickshell.execDetached(["notify-send", "-a", "Calculator", "-i", "accessories-calculator", "🔢 Copied to Clipboard", val.trim()]);
    }
}
