import QtQuick
import Quickshell
import Quickshell.Io

// Live exchange rates from frankfurter.app (free, no API key).
// Provides two output modes:
//   - explicit target ("$10 in eur")  -> single string "9.35 EUR"
//   - no target ("$10" / "10 usd")    -> grid string
//     "cur|EUR|x|9.35\ncur|GBP|x|8.12\n..."
Item {
    id: cache

    property var rates: ({ "USD": 1 })
    property string lastFetched: ""
    property bool ready: false

    readonly property int refreshIntervalMs: 6 * 60 * 60 * 1000
    readonly property int maxGridCurrencies: 12

    // Preferred display order for the grid.
    readonly property var preferredCurrencies: [
        "USD", "EUR", "GBP", "JPY", "CNY", "CAD",
        "AUD", "CHF", "HKD", "NZD", "KRW", "SGD"
    ]

    Timer {
        interval: cache.refreshIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fetchProc.running = false;
            fetchProc.running = true;
        }
    }

    Process {
        id: fetchProc
        command: [
            "sh", "-c",
            'curl -fsSL --connect-timeout 4 --max-time 8 "https://api.frankfurter.app/latest?from=USD" 2>/dev/null'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = (text || "").trim();
                if (!raw) return;
                try {
                    var obj = JSON.parse(raw);
                    if (obj && obj.rates) {
                        var merged = Object.assign({}, obj.rates);
                        merged["USD"] = 1;
                        cache.rates = merged;
                        cache.lastFetched = obj.date || "";
                        cache.ready = true;
                    }
                } catch (e) {}
            }
        }
    }

    function parseQuery(expr) {
        if (!expr) return null;
        var s = expr.trim();

        // "$10 in EUR"
        var m = s.match(/^\$\s*(-?\d+(?:\.\d+)?)\s+(?:in|to|as|->|\u2192)\s+([a-z]{3})\s*$/i);
        if (m) return { amount: parseFloat(m[1]), from: "USD", to: m[2].toUpperCase(), explicitTarget: true };

        // "$10"
        m = s.match(/^\$\s*(-?\d+(?:\.\d+)?)\s*$/);
        if (m) return { amount: parseFloat(m[1]), from: "USD", to: "EUR", explicitTarget: false };

        // "10 USD in EUR"
        m = s.match(/^(-?\d+(?:\.\d+)?)\s*([a-z]{3})\s+(?:in|to|as|->|\u2192)\s+([a-z]{3})\s*$/i);
        if (m) return { amount: parseFloat(m[1]), from: m[2].toUpperCase(), to: m[3].toUpperCase(), explicitTarget: true };

        // "10 USD"
        m = s.match(/^(-?\d+(?:\.\d+)?)\s*([a-z]{3})\s*$/i);
        if (m) {
            var fc = m[2].toUpperCase();
            return { amount: parseFloat(m[1]), from: fc, to: fc === "USD" ? "EUR" : "USD", explicitTarget: false };
        }

        return null;
    }

    function isCurrencyQuery(expr) {
        return parseQuery(expr) !== null;
    }

    function buildResult(expr) {
        var q = parseQuery(expr);
        if (!q) return null;
        if (!cache.ready) return "\u23f3 Fetching exchange rates...";
        if (cache.rates[q.from] === undefined) return "Unknown currency: " + q.from;

        if (q.explicitTarget) {
            var v = convertAmountOnly(q.amount, q.from, q.to);
            if (v === null) return "Unknown currency: " + q.to;
            return formatMoney(v) + " " + q.to;
        }

        // Grid mode: build the ordered currency list
        var ordered = cache.preferredCurrencies.filter(function(c) {
            return c !== q.from && cache.rates[c] !== undefined;
        });
        ordered = [q.from].concat(ordered);
        if (ordered.length > cache.maxGridCurrencies) {
            ordered = ordered.slice(0, cache.maxGridCurrencies);
        }

        var rows = [];
        for (var i = 0; i < ordered.length; i++) {
            var c = ordered[i];
            var amt = convertAmountOnly(q.amount, q.from, c);
            if (amt === null) continue;
            rows.push("cur|" + c + "|x|" + formatMoney(amt));
        }
        return rows.join("\n");
    }

    function convertAmountOnly(amount, from, to) {
        var fromRate = cache.rates[from];
        var toRate = cache.rates[to];
        if (fromRate === undefined || toRate === undefined) return null;
        return amount / fromRate * toRate;
    }

    function formatMoney(n) {
        if (!isFinite(n)) return "\u2014";
        var abs = Math.abs(n);
        var digits = abs >= 100 ? 2 : (abs >= 1 ? 3 : 6);
        var s = n.toFixed(digits);
        s = s.replace(/\.?0+$/, "");
        return s;
    }
}
