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
