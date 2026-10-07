.pragma library

function formatBytes(bytes, decimals) {
    if (isNaN(bytes) || bytes <= 0) return "0 B";
    decimals = (decimals !== undefined) ? decimals : 1;
    var k = 1024;
    var sizes = ["B", "KB", "MB", "GB", "TB"];
    var i = Math.floor(Math.log(bytes) / Math.log(k));
    if (i < 0) i = 0;
    if (i >= sizes.length) i = sizes.length - 1;
    var val = bytes / Math.pow(k, i);
    return (i === 0 ? Math.round(val) : val.toFixed(decimals)) + " " + sizes[i];
}

function formatDuration(secs, detailed) {
    secs = Math.round(secs);
    if (isNaN(secs) || secs < 0) return detailed ? "0s" : "0:00";
    var h = Math.floor(secs / 3600);
    var m = Math.floor((secs % 3600) / 60);
    var s = Math.floor(secs % 60);
    if (detailed) {
        var parts = [];
        if (h > 0) parts.push(h + "h");
        if (m > 0 || h > 0) parts.push(m + "m");
        parts.push(s + "s");
        return parts.join(" ");
    }
    return (h > 0 ? (h + ":" + (m < 10 ? "0" : "") + m) : m) + ":" + (s < 10 ? "0" : "") + s;
}

function escapeShell(str) {
    return "'" + String(str).replace(/'/g, "'\\''") + "'";
}

function sanitizeIdentifier(str) {
    if (!str) return "";
    return String(str).replace(/[^a-zA-Z0-9_\-\.]/g, "").trim();
}

function extractUrl(text) {
    if (!text) return "";
    var match = text.match(/(https?:\/\/[^\s<]+)/);
    return match ? match[0] : "";
}

function extractImageUrl(text) {
    if (!text) return "";
    var match = text.match(/(https?:\/\/[^\s<]+\.(?:png|jpg|jpeg|gif|svg|webp)(?:\?[^\s<]+)?)/i);
    return match ? match[0] : "";
}

function stripHtml(html) {
    if (!html) return "";
    return html.replace(/<[^>]*>/g, "")
               .replace(/&quot;/g, '"')
               .replace(/&amp;/g, '&')
               .replace(/&#39;/g, "'")
               .replace(/&lt;/g, '<')
               .replace(/&gt;/g, '>')
               .trim();
}

function fuzzyMatch(needle, haystack) {
    var n = needle.toLowerCase();
    var h = haystack.toLowerCase();
    var nlen = n.length;
    var hlen = h.length;
    if (nlen > hlen) return false;
    if (nlen === hlen) return n === h;
    var nIdx = 0;
    var hIdx = 0;
    while (nIdx < nlen && hIdx < hlen) {
        if (n.charCodeAt(nIdx) === h.charCodeAt(hIdx)) nIdx++;
        hIdx++;
    }
    return nIdx === nlen;
}

// Safe padding inside a card of the given shape. Guarantees the returned
// rectangle is fully contained within the visible shape outline so no
// content spills past a chamfered corner or slanted edge.
//
// Hexagon geometry: the top-left chamfer runs from (0, c) to (c, 0), so the
// only horizontal span that is safe at *every* y is x ∈ [c + border, W - c -
// border]. The top and bottom edges are flat between x=c and x=W-c, so no
// vertical compensation is needed beyond the border itself.
//
// Slant geometry: the top-left corner sits at (border, border) and the
// bottom-left at (slant + border, H - border); the horizontal inset must be
// at least `slant + border` to keep content inside the parallelogram.
function getSafeCardPadding(settingsManager) {
    if (!settingsManager) return { h: 18, v: 16 };
    var shape = settingsManager.overlayCardShape || "rounded";
    var border = Math.max(1, settingsManager.globalBorderWidth || 3);

    if (shape === "hexagon") {
        var cut = Math.min(120, Math.max(4, Math.round(settingsManager.overlayHexagonCut || 36)));
        return {
            h: cut + border + 6,
            v: border + 8
        };
    }
    if (shape === "slant") {
        var angle = Math.min(100, Math.max(8, Math.round(settingsManager.overlaySlantAngle || 32)));
        return {
            h: angle + border + 6,
            v: border + 8
        };
    }
    return { h: border + 8, v: border + 8 };
}

function getSafeInputPadding(settingsManager) {
    if (!settingsManager) return { left: 14, right: 14 };
    var shape = settingsManager.inputFieldShape || "rounded";
    if (shape === "hexagon") {
        var cut = Math.min(24, Math.max(8, Math.round(settingsManager.inputHexagonCut || 14)));
        return { left: cut + 8, right: cut + 8 };
    } else if (shape === "slant") {
        var angle = Math.min(24, Math.max(8, Math.round(settingsManager.inputSlantAngle || 14)));
        return { left: angle + 8, right: angle + 8 };
    }
    return { left: 14, right: 14 };
}

// ---------------------------------------------------------------------------
// Safe arithmetic evaluator. Hand-rolled recursive descent parser — never
// calls eval(). Returns a formatted result string, or null if the input is
// not a well-formed arithmetic expression.
//
//   evaluate("2 + 3 * 4")        -> "14"
//   evaluate("=10 / 4")          -> "2.5"
//   evaluate("2 ^ 8")            -> "256"
//   evaluate("hello")            -> null
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Physical unit conversion. Each entry: [dimension, scale] where scale is
// "how many base units per 1 of this unit". Base units: liter, gram, meter,
// byte, second, celsius. Temperature is special-cased (affine, not linear).
// ---------------------------------------------------------------------------
var UNIT_TABLE = {
    // Volume — base liter
    "l": ["volume", 1], "liter": ["volume", 1], "liters": ["volume", 1], "litre": ["volume", 1], "litres": ["volume", 1],
    "ml": ["volume", 0.001], "milliliter": ["volume", 0.001], "milliliters": ["volume", 0.001],
    "gal": ["volume", 3.785411784], "gallon": ["volume", 3.785411784], "gallons": ["volume", 3.785411784],
    "qt": ["volume", 0.946352946], "quart": ["volume", 0.946352946], "quarts": ["volume", 0.946352946],
    "pt": ["volume", 0.473176473], "pint": ["volume", 0.473176473], "pints": ["volume", 0.473176473],
    "cup": ["volume", 0.2365882365], "cups": ["volume", 0.2365882365],
    "floz": ["volume", 0.0295735295625], "tbsp": ["volume", 0.01478676478125], "tsp": ["volume", 0.00492892159375],

    // Mass — base gram
    "g": ["mass", 1], "gram": ["mass", 1], "grams": ["mass", 1],
    "kg": ["mass", 1000], "kilogram": ["mass", 1000], "kilograms": ["mass", 1000],
    "mg": ["mass", 0.001], "milligram": ["mass", 0.001], "milligrams": ["mass", 0.001],
    "lb": ["mass", 453.59237], "lbs": ["mass", 453.59237], "pound": ["mass", 453.59237], "pounds": ["mass", 453.59237],
    "oz": ["mass", 28.349523125], "ounce": ["mass", 28.349523125], "ounces": ["mass", 28.349523125],
    "st": ["mass", 6350.29318], "stone": ["mass", 6350.29318],
    "tonne": ["mass", 1000000], "tonnes": ["mass", 1000000],

    // Length — base meter
    "m": ["length", 1], "meter": ["length", 1], "meters": ["length", 1], "metre": ["length", 1], "metres": ["length", 1],
    "km": ["length", 1000], "kilometer": ["length", 1000], "kilometers": ["length", 1000],
    "cm": ["length", 0.01], "centimeter": ["length", 0.01], "centimeters": ["length", 0.01],
    "mm": ["length", 0.001], "millimeter": ["length", 0.001], "millimeters": ["length", 0.001],
    "mi": ["length", 1609.344], "mile": ["length", 1609.344], "miles": ["length", 1609.344],
    "ft": ["length", 0.3048], "foot": ["length", 0.3048], "feet": ["length", 0.3048],
    "inch": ["length", 0.0254], "inches": ["length", 0.0254],
    "yd": ["length", 0.9144], "yard": ["length", 0.9144], "yards": ["length", 0.9144],
    "nmi": ["length", 1852],

    // Data — base byte
    "b": ["data", 1], "byte": ["data", 1], "bytes": ["data", 1],
    "kb": ["data", 1000], "kilobyte": ["data", 1000], "kilobytes": ["data", 1000],
    "mb": ["data", 1e6], "megabyte": ["data", 1e6], "megabytes": ["data", 1e6],
    "gb": ["data", 1e9], "gigabyte": ["data", 1e9], "gigabytes": ["data", 1e9],
    "tb": ["data", 1e12], "terabyte": ["data", 1e12], "terabytes": ["data", 1e12],
    "kib": ["data", 1024], "mib": ["data", 1048576], "gib": ["data", 1073741824], "tib": ["data", 1099511627776],
    "bit": ["data", 0.125], "bits": ["data", 0.125], "kbit": ["data", 125], "mbit": ["data", 125000], "gbit": ["data", 125000000],

    // Time — base second
    "s": ["time", 1], "sec": ["time", 1], "secs": ["time", 1], "second": ["time", 1], "seconds": ["time", 1],
    "min": ["time", 60], "mins": ["time", 60], "minute": ["time", 60], "minutes": ["time", 60],
    "h": ["time", 3600], "hr": ["time", 3600], "hrs": ["time", 3600], "hour": ["time", 3600], "hours": ["time", 3600],
    "day": ["time", 86400], "days": ["time", 86400], "week": ["time", 604800], "weeks": ["time", 604800],
    "year": ["time", 31536000], "years": ["time", 31536000]
};

var TEMP_UNITS = {
    "c": 1, "celsius": 1, "°c": 1,
    "f": 1, "fahrenheit": 1, "°f": 1,
    "k": 1, "kelvin": 1
};

// Default counterpart for one-unit inputs. Lets "1gallon" produce a useful
// answer without the user having to type "in liters".
var AUTO_COUNTERPART = {
    "l": "gal", "liter": "gal", "liters": "gal", "litre": "gal", "litres": "gal",
    "gal": "l", "gallon": "l", "gallons": "l",
    "ml": "floz", "floz": "ml",
    "g": "oz", "gram": "oz", "grams": "oz", "oz": "g", "ounce": "g", "ounces": "g",
    "kg": "lbs", "kilogram": "lbs", "kilograms": "lbs", "lb": "kg", "lbs": "kg", "pound": "kg", "pounds": "kg",
    "m": "ft", "meter": "ft", "meters": "ft", "ft": "m", "foot": "m", "feet": "m",
    "km": "mi", "kilometer": "mi", "kilometers": "mi", "mi": "km", "mile": "km", "miles": "km",
    "cm": "inch", "inch": "cm", "inches": "cm", "mm": "inch",
    "b": "kb", "kb": "mb", "mb": "mib", "mib": "mb", "gb": "gib", "gib": "gb", "tb": "tib", "tib": "tb",
    "bit": "byte", "byte": "bit",
    "s": "min", "min": "s", "h": "min", "hr": "min", "day": "h", "week": "day",
    "c": "f", "celsius": "f", "°c": "f", "f": "c", "fahrenheit": "c", "°f": "c", "k": "c", "kelvin": "c"
};

function convertTemperature(value, from, to) {
    var fromKey = from.toLowerCase().replace(/^°/, "").trim();
    var toKey = to.toLowerCase().replace(/^°/, "").trim();
    // Normalize to celsius first
    var c;
    if (fromKey === "c" || fromKey === "celsius") c = value;
    else if (fromKey === "f" || fromKey === "fahrenheit") c = (value - 32) * 5 / 9;
    else if (fromKey === "k" || fromKey === "kelvin") c = value - 273.15;
    else return null;

    // Then to target
    var out;
    if (toKey === "c" || toKey === "celsius") out = c;
    else if (toKey === "f" || toKey === "fahrenheit") out = c * 9 / 5 + 32;
    else if (toKey === "k" || toKey === "kelvin") out = c + 273.15;
    else return null;

    return out;
}

function canonicalizeUnit(u) {
    var aliases = {
        "liter": "l", "liters": "l", "litre": "l", "litres": "l",
        "gallon": "gal", "gallons": "gal",
        "gram": "g", "grams": "g", "kilogram": "kg", "kilograms": "kg",
        "pound": "lb", "pounds": "lb", "ounce": "oz", "ounces": "oz",
        "meter": "m", "meters": "m", "metre": "m", "metres": "m",
        "kilometer": "km", "kilometers": "km",
        "mile": "mi", "miles": "mi",
        "foot": "ft", "feet": "ft",
        "byte": "byte", "bytes": "byte", "bit": "bit", "bits": "bit",
        "second": "s", "seconds": "s", "sec": "s", "secs": "s",
        "minute": "min", "minutes": "min", "mins": "min",
        "hour": "h", "hours": "h", "hr": "h", "hrs": "h",
        "celsius": "c", "fahrenheit": "f", "kelvin": "k"
    };
    return aliases[u] || u;
}

var CANONICAL_BY_DIM = {
    "volume": ["ml", "l", "gal", "qt", "pt", "cup", "floz", "tbsp", "tsp"],
    "mass":   ["mg", "g", "kg", "oz", "lb", "st", "tonne"],
    "length": ["mm", "cm", "m", "km", "inch", "ft", "yd", "mi", "nmi"],
    "data":   ["bit", "byte", "kb", "mb", "gb", "tb", "kib", "mib", "gib", "tib"],
    "time":   ["s", "min", "h", "day", "week", "year"]
};

function tryUnitConversion(expr) {
    if (!expr || typeof expr !== "string") return null;
    var s = expr.trim();
    if (!s) return null;

    // "NUMBER UNIT in UNIT2" — single explicit conversion
    var m = s.match(/^(-?\d+(?:\.\d+)?(?:e[+-]?\d+)?)\s*([a-z\u00b0\u00b5]+)\s+(?:in|to|as|->|\u2192)\s+([a-z\u00b0\u00b5]+)\s*$/i);
    if (m) {
        return doConvert(parseFloat(m[1]), m[2].toLowerCase(), m[3].toLowerCase());
    }

    // "NUMBER UNIT" — grid of all same-dimension counterparts
    m = s.match(/^(-?\d+(?:\.\d+)?(?:e[+-]?\d+)?)\s*([a-z\u00b0\u00b5]+)\s*$/i);
    if (m) {
        return buildUnitGrid(parseFloat(m[1]), m[2].toLowerCase());
    }

    return null;
}

function buildUnitGrid(value, unit) {
    if (isNaN(value)) return null;
    var u = canonicalizeUnit(unit);

    // Temperature has its own dedicated grid path (affine math)
    if (TEMP_UNITS[u] !== undefined) return buildTempGrid(value, u);

    var entry = UNIT_TABLE[u];
    if (!entry) return null;
    var dim = entry[0];
    var canonical = CANONICAL_BY_DIM[dim];
    if (!canonical) return null;

    // Ensure the input unit appears first
    var ordered = [u].concat(canonical.filter(function(c) { return c !== u; }));

    var rows = [];
    for (var i = 0; i < ordered.length; i++) {
        var target = ordered[i];
        var single = doConvert(value, u, target);
        if (!single) continue;
        var pieces = single.split(" ");
        var label = pieces[pieces.length - 1];
        var num = pieces.slice(0, pieces.length - 1).join(" ");
        rows.push("unit|" + label + "|x|" + num);
    }
    return rows.join("\n");
}

function buildTempGrid(value, unit) {
    var units = ["c", "f", "k"];
    var ordered = [unit].concat(units.filter(function(u) { return u !== unit; }));

    var rows = [];
    for (var i = 0; i < ordered.length; i++) {
        var u = ordered[i];
        var t = convertTemperature(value, unit, u);
        if (t === null) continue;
        rows.push("temp|" + displayUnit(u) + "|x|" + trimNum(t, 4));
    }
    return rows.join("\n");
}

function doConvert(value, fromUnit, toUnit) {
    if (isNaN(value)) return null;
    var from = canonicalizeUnit(fromUnit);
    var to = canonicalizeUnit(toUnit);

    if (TEMP_UNITS[from] !== undefined && TEMP_UNITS[to] !== undefined) {
        var t = convertTemperature(value, from, to);
        if (t === null) return null;
        return trimNum(t, 4) + " " + displayUnit(to);
    }

    var fromEntry = UNIT_TABLE[from];
    var toEntry = UNIT_TABLE[to];
    if (!fromEntry || !toEntry) return null;
    if (fromEntry[0] !== toEntry[0]) return null;

    var result = value * fromEntry[1] / toEntry[1];
    return trimNum(result, 4) + " " + displayUnit(to);
}

function displayUnit(u) {
    var map = {
        "l": "L", "gal": "gal", "qt": "qt", "pt": "pt", "cup": "cup",
        "ml": "mL", "floz": "fl oz", "tbsp": "tbsp", "tsp": "tsp",
        "g": "g", "kg": "kg", "mg": "mg", "lb": "lbs", "oz": "oz", "st": "st", "tonne": "t",
        "m": "m", "km": "km", "cm": "cm", "mm": "mm",
        "mi": "mi", "ft": "ft", "inch": "in", "yd": "yd", "nmi": "nmi",
        "mb": "MB", "mib": "MiB", "gb": "GB", "gib": "GiB",
        "kb": "KB", "kib": "KiB", "tb": "TB", "tib": "TiB",
        "b": "B", "byte": "B", "bit": "bit",
        "s": "s", "min": "min", "h": "h", "day": "d", "week": "wk", "year": "yr",
        "c": "\u00b0C", "f": "\u00b0F", "k": "K"
    };
    return map[u] || u;
}

function trimNum(n, digits) {
    if (!isFinite(n)) return "\u2014";
    var rounded = Number(n.toFixed(digits));
    if (Number.isInteger(rounded)) return String(rounded);
    return String(rounded);
}

// Main dispatcher for the calculator engine.
function evaluate(expr, strict) {
    if (!expr || typeof expr !== "string") return null;

    var unitResult = tryUnitConversion(expr);
    if (unitResult !== null) return unitResult;

    return tryArithmetic(expr, strict);
}

function tryArithmetic(expr, strict) {
    if (!expr || typeof expr !== "string") return null;
    var src = expr.trim();
    if (src === "") return null;
    if (src.charAt(0) === "=") src = src.substring(1).trim();
    if (src === "") return null;

    // Whitelist: digits, whitespace, operators, parens, decimal point, e-notation.
    if (!/^[0-9eE+\-*/%^().,\s]+$/.test(src)) return null;

    var pos = 0;

    function skipWs() {
        while (pos < src.length && /\s/.test(src.charAt(pos))) pos++;
    }

    function peek() {
        skipWs();
        return pos < src.length ? src.charAt(pos) : "";
    }

    function parseNumber() {
        skipWs();
        var start = pos;
        while (pos < src.length) {
            var c = src.charAt(pos);
            if (/[0-9.]/.test(c)) {
                pos++;
            } else if ((c === "e" || c === "E") && pos > start) {
                var nxt = pos + 1 < src.length ? src.charAt(pos + 1) : "";
                if (nxt === "+" || nxt === "-") { pos += 2; }
                else { pos++; }
            } else {
                break;
            }
        }
        if (pos === start) return null;
        var n = parseFloat(src.substring(start, pos));
        return isNaN(n) ? null : n;
    }

    function parseFactor() {
        skipWs();
        if (pos >= src.length) return null;
        var c = src.charAt(pos);
        if (c === "(") {
            pos++;
            var v = parseExpression();
            if (v === null) return null;
            skipWs();
            if (src.charAt(pos) !== ")") return null;
            pos++;
            return v;
        }
        if (c === "-") { pos++; var a = parseFactor(); return a === null ? null : -a; }
        if (c === "+") { pos++; return parseFactor(); }
        return parseNumber();
    }

    function parseTerm() {
        var left = parseFactor();
        if (left === null) return null;
        while (true) {
            skipWs();
            var c = pos < src.length ? src.charAt(pos) : "";
            if (c !== "*" && c !== "/" && c !== "%" && c !== "^") return left;
            pos++;
            var right = parseFactor();
            if (right === null) return null;
            if (c === "*") left = left * right;
            else if (c === "/") { if (right === 0) return null; left = left / right; }
            else if (c === "%") { if (right === 0) return null; left = left % right; }
            else if (c === "^") left = Math.pow(left, right);
        }
    }

    function parseExpression() {
        var left = parseTerm();
        if (left === null) return null;
        while (true) {
            skipWs();
            var c = pos < src.length ? src.charAt(pos) : "";
            if (c !== "+" && c !== "-") return left;
            pos++;
            var right = parseTerm();
            if (right === null) return null;
            left = (c === "+") ? (left + right) : (left - right);
        }
    }

    var result = parseExpression();
    skipWs();
    if (pos < src.length) return null;
    if (result === null || !isFinite(result)) return null;
    return formatNumber(result);
}

function formatNumber(n) {
    if (Number.isInteger(n)) return String(n);
    var rounded = Math.round(n * 1e10) / 1e10;
    var s = String(rounded);
    if (s.indexOf("e") !== -1) s = rounded.toFixed(10).replace(/\.?0+$/, "");
    return s;
}

