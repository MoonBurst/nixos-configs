import QtQuick
import Quickshell
import "../../../common/Utils.js" as Utils

Item {
    id: engine
    visible: false

    property string expression: ""
    property string resultString: ""
    property int selectedGridIndex: 0

    property RateCache rateCache: RateCache { }

    // When the async rate fetch completes, re-run the last query so the
    // grid populates without the user having to retype.
    Connections {
        target: engine.rateCache
        function onReadyChanged() {
            if (engine.expression !== "") engine.evaluate(engine.expression);
        }
    }

    onExpressionChanged: evaluate(expression)

    function evaluate(expr) {
        if (!expr || expr.trim() === "") {
            resultString = "";
            selectedGridIndex = 0;
            return;
        }

        // Currency first (has $ prefix or 3-letter code suffix)
        if (rateCache.isCurrencyQuery(expr)) {
            var r = rateCache.buildResult(expr);
            if (r !== null) {
                resultString = r;
                selectedGridIndex = 0;
                return;
            }
        }

        // Units + arithmetic
        var res = Utils.evaluate(expr, true);
        resultString = (res !== null && res !== undefined) ? res : "";
        selectedGridIndex = 0;
    }

    function copyResult(val) {
        if (!val || val.trim() === "") return;
        Quickshell.clipboardText = val.trim();
        Quickshell.execDetached(["notify-send", "-a", "Calculator", "-i", "accessories-calculator", "\ud83d\udd22 Copied to Clipboard", val.trim()]);
    }
}
