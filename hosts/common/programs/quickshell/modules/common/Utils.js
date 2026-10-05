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

function getSafeCardPadding(settingsManager) {
    if (!settingsManager) return { h: 18, v: 16 };
    var shape = settingsManager.overlayCardShape || "rounded";
    if (shape === "hexagon") {
        var cut = Math.max(16, Math.round(settingsManager.overlayHexagonCut || 36));
        return {
            h: Math.max(24, Math.round(cut * 1.0) + 20),
            v: Math.max(18, Math.round(cut * 0.45) + 14)
        };
    } else if (shape === "slant") {
        var angle = Math.max(14, Math.round(settingsManager.overlaySlantAngle || 32));
        return {
            h: Math.max(24, Math.round(angle * 0.90) + 16),
            v: 18
        };
    }
    return { h: 18, v: 16 };
}

function getSafeInputPadding(settingsManager) {
    if (!settingsManager) return { left: 14, right: 14 };
    var shape = settingsManager.inputFieldShape || "rounded";
    if (shape === "hexagon") {
        var cut = Math.max(8, Math.round(settingsManager.inputHexagonCut || 14));
        return { left: cut + 10, right: cut + 10 };
    } else if (shape === "slant") {
        var angle = Math.max(8, Math.round(settingsManager.inputSlantAngle || 14));
        return { left: angle + 10, right: angle + 10 };
    }
    return { left: 14, right: 14 };
}

const unitTables = {
    length: {
        base: "m",
        names: { "mm": "Millimeter", "cm": "Centimeter", "m": "Meter", "km": "Kilometer", "in": "Inch", "ft": "Foot", "yd": "Yard", "mi": "Mile" },
        rates: { "mm": 0.001, "cm": 0.01, "m": 1.0, "km": 1000.0, "in": 0.0254, "ft": 0.3048, "yd": 0.9144, "mi": 1609.344 },
        aliases: { "meter": "m", "meters": "m", "kilometer": "km", "kilometers": "km", "centimeter": "cm", "centimeters": "cm", "millimeter": "mm", "inch": "in", "inches": "in", "foot": "ft", "feet": "ft", "yard": "yd", "yards": "yd", "mile": "mi", "miles": "mi" }
    },
    mass: {
        base: "kg",
        names: { "mg": "Milligram", "g": "Gram", "kg": "Kilogram", "oz": "Ounce", "lb": "Pound", "st": "Stone", "ton": "US Ton" },
        rates: { "mg": 1e-6, "g": 0.001, "kg": 1.0, "oz": 0.0283495, "lb": 0.453592, "st": 6.35029, "ton": 907.185 },
        aliases: { "gram": "g", "grams": "g", "kilogram": "kg", "kilograms": "kg", "kilo": "kg", "kilos": "kg", "milligram": "mg", "ounce": "oz", "ounces": "oz", "pound": "lb", "pounds": "lb", "lbs": "lb", "stone": "st" }
    },
    storage: {
        base: "byte",
        names: { "b": "Bits", "byte": "Bytes", "kb": "Kilobytes", "mb": "Megabytes", "gb": "Gigabytes", "tb": "Terabytes", "kib": "Kibibytes", "mib": "Mebibytes", "gib": "Gibibytes", "tib": "Tebibytes" },
        rates: { "b": 0.125, "bit": 0.125, "bits": 0.125, "byte": 1.0, "bytes": 1.0, "kb": 1e3, "mb": 1e6, "gb": 1e9, "tb": 1e12, "kib": 1024.0, "mib": 1048576.0, "gib": 1073741824.0, "tib": 1099511627776.0 },
        aliases: { "bit": "b", "bits": "b", "bytes": "byte", "kbyte": "kb", "mbyte": "mb", "gbyte": "gb", "tbyte": "tb" }
    },
    volume: {
        base: "l",
        names: { "ml": "Milliliter", "l": "Liter", "floz": "Fluid Ounce", "tsp": "Teaspoon", "tbsp": "Tablespoon", "cup": "US Cup", "pint": "US Pint", "qt": "US Quart", "gal": "US Gallon" },
        rates: { "ml": 0.001, "l": 1.0, "floz": 0.0295735, "tsp": 0.00492892, "tbsp": 0.0147868, "cup": 0.236588, "pint": 0.473176, "qt": 0.946353, "gal": 3.78541 },
        aliases: { "fl oz": "floz", "fluid ounce": "floz", "fluid ounces": "floz", "fl.oz": "floz", "oz fl": "floz", "liter": "l", "liters": "l", "teaspoon": "tsp", "teaspoons": "tsp", "tablespoon": "tbsp", "tablespoons": "tbsp", "cups": "cup", "pints": "pint", "gallon": "gal", "gallons": "gal" }
    },
    pressure: {
        base: "bar",
        names: { "psi": "Pound/sq inch", "bar": "Bar", "kpa": "Kilopascal", "atm": "Atmosphere" },
        rates: { "psi": 0.0689476, "bar": 1.0, "kpa": 0.01, "atm": 1.01325 },
        aliases: { "pounds per square inch": "psi", "bars": "bar", "kilopascal": "kpa" }
    },
    power: {
        base: "kw",
        names: { "w": "Watt", "kw": "Kilowatt", "hp": "Horsepower" },
        rates: { "w": 0.001, "kw": 1.0, "hp": 0.7457 },
        aliases: { "watt": "w", "watts": "w", "kilowatt": "kw", "kilowatts": "kw", "horsepower": "hp" }
    },
    speed: {
        base: "m/s",
        names: { "m/s": "Meters/sec", "km/h": "Kilometers/hr", "mph": "Miles/hr" },
        rates: { "m/s": 1.0, "km/h": 0.277778, "mph": 0.44704 },
        aliases: { "kmh": "km/h", "mps": "m/s" }
    }
};

const currRates = { "usd": 1.0, "eur": 0.92, "gbp": 0.78, "jpy": 156.8, "cny": 7.24, "cad": 1.37, "aud": 1.52, "mxn": 18.7, "brl": 5.12, "inr": 83.2, "krw": 1370.0, "rub": 89.5, "chf": 0.91 };
const currSymbols = { "usd": "$", "eur": "€", "gbp": "£", "jpy": "¥", "cny": "元", "cad": "C$", "aud": "A$", "mxn": "$", "brl": "R$", "inr": "₹", "krw": "₩", "rub": "₽", "chf": "CHF" };
const currNames = { "usd": "US Dollar", "eur": "Euro", "gbp": "British Pound", "jpy": "Japanese Yen", "cny": "Chinese Yuan", "cad": "Canadian Dollar", "aud": "Australian Dollar", "mxn": "Mexican Peso", "brl": "Brazilian Real", "inr": "Indian Rupee", "krw": "South Korean Won", "rub": "Russian Ruble", "chf": "Swiss Franc" };
const currAliases = { "$": "usd", "dollar": "usd", "dollars": "usd", "usd": "usd", "€": "eur", "euro": "eur", "eur": "eur", "£": "gbp", "pound": "gbp", "gbp": "gbp", "¥": "jpy", "yen": "jpy", "jpy": "jpy", "元": "cny", "cny": "cny", "cad": "cad", "aud": "aud", "mxn": "mxn", "peso": "mxn", "brl": "brl", "inr": "inr", "rupee": "inr", "krw": "krw", "won": "krw", "rub": "rub", "chf": "chf" };

function fmtUnit(n) {
    let s = (Math.abs(n) >= 10000 || (Math.abs(n) > 0 && Math.abs(n) < 0.001)) ? Number(n).toExponential(3) : parseFloat(Number(n).toFixed(4)).toString();
    let parts = s.split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    return parts.join(".");
}

function formatMoney(num, code) {
    let decimals = (code === "jpy" || code === "krw") ? 0 : 2;
    let str = num.toFixed(decimals);
    let parts = str.split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    return parts.join(".");
}

function evaluate(query, isMathMode) {
    const clean = (query || "").trim();
    if (!clean) return null;
    let expr = clean.startsWith("=") ? clean.substring(1).trim() : clean;

    if (!clean.startsWith("=") && /^[a-zA-Z]+$/.test(expr)) {
        return null;
    }

    const transferMatch = expr.match(/^([+-]?\d*\.?\d+)\s*([a-zA-Z]+)\s*\/\s*([+-]?\d*\.?\d+)\s*([a-zA-Z]+)$/i);
    if (transferMatch) {
        const sizeVal = parseFloat(transferMatch[1]);
        const sizeUnit = transferMatch[2].toLowerCase();
        const speedVal = parseFloat(transferMatch[3]);
        const speedUnit = transferMatch[4].toLowerCase();

        const storageBits = { "b": 1, "bit": 1, "byte": 8, "kb": 8000, "mb": 8e6, "gb": 8e9, "tb": 8e12, "kib": 1024*8, "mib": 1048576*8, "gib": 1073741824*8, "tib": 1099511627776*8 };
        const speedBits = { "bps": 1, "kbps": 1000, "mbps": 1e6, "gbps": 1e9, "b/s": 8, "byte/s": 8, "kb/s": 8000, "mb/s": 8e6, "gb/s": 8e9 };

        const totalBits = sizeVal * (storageBits[sizeUnit] || 0);
        const rateBits = speedVal * (speedBits[speedUnit] || storageBits[speedUnit] || 0);

        if (totalBits > 0 && rateBits > 0) {
            let secs = Math.round(totalBits / rateBits);
            let days = Math.floor(secs / 86400); secs %= 86400;
            let hours = Math.floor(secs / 3600); secs %= 3600;
            let mins = Math.floor(secs / 60); secs %= 60;
            let parts = [];
            if (days) parts.push(days + "d");
            if (hours) parts.push(hours + "h");
            if (mins) parts.push(mins + "m");
            parts.push(secs + "s");
            return parts.join(" ") + " @ " + speedVal + " " + transferMatch[4];
        }
    }

    const pairMatch = expr.match(/^([$€£¥元]?\s*\d*\.?\d+)\s*([a-zA-Z$€£¥元°]+)\s*(?:to|in)\s*([a-zA-Z$€£¥元°]+)$/i);
    if (pairMatch) {
        let val = parseFloat(pairMatch[1].replace(/[$€£¥元]/g, ""));
        let from = pairMatch[2].toLowerCase().replace("°", "");
        let to = pairMatch[3].toLowerCase().replace("°", "");

        let cFrom = currAliases[from] || from;
        let cTo = currAliases[to] || to;
        if (currRates[cFrom] && currRates[cTo]) {
            let converted = (val / currRates[cFrom]) * currRates[cTo];
            let dec = (cTo === "jpy" || cTo === "krw") ? 0 : 2;
            return converted.toLocaleString(undefined, { minimumFractionDigits: dec, maximumFractionDigits: dec }) + " " + cTo.toUpperCase() + " (" + (currSymbols[cTo] || "") + ")";
        }

        if ((from === "c" || from === "f") && (to === "c" || to === "f")) {
            let res = (from === "c") ? (val * 9/5 + 32) : ((val - 32) * 5/9);
            return res.toFixed(2) + " " + (to === "c" ? "°C" : "°F");
        }

        for (let cat in unitTables) {
            let tbl = unitTables[cat];
            let uFrom = tbl.aliases[from] || from;
            let uTo = tbl.aliases[to] || to;
            if (tbl.rates[uFrom] && tbl.rates[uTo]) {
                let baseVal = val * tbl.rates[uFrom];
                let res = baseVal / tbl.rates[uTo];
                return fmtUnit(res) + " " + uTo;
            }
        }
    }

    const currSingle = expr.match(/^([$€£¥元]?\s*\d*\.?\d+)\s*([a-zA-Z$€£¥元]*)$/i);
    if (currSingle && (currSingle[1].match(/[$€£¥元]/) || currSingle[2])) {
        let numStr = currSingle[1].replace(/[$€£¥元]/g, "").trim();
        let symPrefix = (currSingle[1].match(/[$€£¥元]/) || [""])[0];
        let rawUnit = (symPrefix ? symPrefix : currSingle[2]).toLowerCase().trim();
        let baseCurr = currAliases[rawUnit];

        if (baseCurr && currRates[baseCurr]) {
            let val = parseFloat(numStr);
            if (!isNaN(val) && val > 0) {
                let inUsd = val / currRates[baseCurr];
                let rows = [];
                for (let c in currRates) {
                    if (c === baseCurr) continue;
                    let conv = inUsd * currRates[c];
                    let formatted = formatMoney(conv, c);
                    rows.push((currSymbols[c] || "") + "|" + c.toUpperCase() + "|" + (currNames[c] || "") + "|" + formatted);
                }
                return rows.join("\n");
            }
        }
    }

    const tempSingle = expr.match(/^([+-]?\d*\.?\d+)\s*(c|f|°c|°f)$/i);
    if (tempSingle) {
        let val = parseFloat(tempSingle[1]);
        let u = tempSingle[2].toLowerCase().replace("°", "");
        let rows = [];
        if (u === "c") {
            let f = val * 9/5 + 32;
            let k = val + 273.15;
            rows.push("°F|FAHRENHEIT|US Standard|" + f.toFixed(2));
            rows.push("K|KELVIN|Absolute Temp|" + k.toFixed(2));
        } else {
            let c = (val - 32) * 5/9;
            let k = c + 273.15;
            rows.push("°C|CELSIUS|Metric Standard|" + c.toFixed(2));
            rows.push("K|KELVIN|Absolute Temp|" + k.toFixed(2));
        }
        return rows.join("\n");
    }

    const singleUnit = expr.match(/^([+-]?\d*\.?\d+)\s*([a-zA-Z°\/]+)$/i);
    if (singleUnit) {
        let val = parseFloat(singleUnit[1]);
        let rawU = singleUnit[2].toLowerCase();

        for (let cat in unitTables) {
            let tbl = unitTables[cat];
            let baseU = tbl.aliases[rawU] || rawU;

            if (tbl.rates[baseU] !== undefined) {
                let inBase = val * tbl.rates[baseU];
                let rows = [];
                for (let targetU in tbl.rates) {
                    if (targetU === baseU) continue;
                    let conv = inBase / tbl.rates[targetU];
                    rows.push(targetU + "|" + targetU.toUpperCase() + "|" + (tbl.names[targetU] || targetU) + "|" + fmtUnit(conv));
                }
                return rows.join("\n");
            }
        }
    }

    let cleanExpr = expr.replace(/[+\-*\/^%(\s]+$/, "").trim();
    if (!cleanExpr) return isMathMode ? "" : null;

    if (!/^[0-9+\-*\/^%()., \t\r\n]|^(sqrt|sin|cos|tan|abs|log|ln|pi|e|round)\b/i.test(cleanExpr)) {
        return null;
    }
    if (/[;={}\[\]\\`$"'!@#&_]|process|require|import|window|shell|Quickshell/i.test(cleanExpr)) {
        return null;
    }

    try {
        let parsed = cleanExpr
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

        let fn = new Function("return (" + parsed + ");");
        let result = fn();
        if (result === undefined || result === null || !isFinite(result)) return null;

        let formatted = (Math.abs(result) >= 1000000 || (Math.abs(result) > 0 && Math.abs(result) < 0.0001))
            ? Number(result).toExponential(4)
            : parseFloat(Number(result).toFixed(6)).toString();

        return formatted;
    } catch(e) {
        return isMathMode ? "" : null;
    }
}
