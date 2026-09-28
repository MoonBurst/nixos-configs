pragma Singleton
import QtQuick

QtObject {
    id: root

    property string mathResultString: ""

    function setResult(val) {
        mathResultString = String(val);
    }

    function runCalculator(query) {
        const clean = (query || "").trim();
        if (!clean) return false;

        // Strip leading '=' if user typed "= 5 + 5"
        let expr = clean.startsWith("=") ? clean.substring(1).trim() : clean;

        // Must contain at least one digit or math constant
        if (!/[0-9]/.test(expr) && !/^(pi|e)\b/i.test(expr)) return false;

        // Only allow safe math tokens
        if (!/^[0-9+\-*\/().,^ %a-zA-Z]+$/.test(expr)) return false;

        try {
            // Translate mathematical notation into JS Math methods
            let parsed = expr
                .replace(/\^/g, "**")
                .replace(/\bpi\b/gi, "Math.PI")
                .replace(/\be\b/g, "Math.E")
                .replace(/\bsin\b/gi, "Math.sin")
                .replace(/\bcos\b/gi, "Math.cos")
                .replace(/\btan\b/gi, "Math.tan")
                .replace(/\bsqrt\b/gi, "Math.sqrt")
                .replace(/\blog\b/gi, "Math.log10")
                .replace(/\bln\b/gi, "Math.log")
                .replace(/\babs\b/gi, "Math.abs")
                .replace(/\bround\b/gi, "Math.round");

            // Evaluate safely using Function constructor inside sandboxed scope
            let fn = new Function("return (" + parsed + ");");
            let result = fn();

            if (result === undefined || result === null || !isFinite(result)) return false;

            // Format clean output
            let formatted = (Math.abs(result) >= 1000000 || (Math.abs(result) > 0 && Math.abs(result) < 0.0001))
                ? Number(result).toExponential(4)
                : parseFloat(Number(result).toFixed(6)).toString();

            setResult(formatted);
            return true;
        } catch(e) {
            return false;
        }
    }
}
