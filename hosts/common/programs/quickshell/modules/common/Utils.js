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
            h: Math.max(28, cut + 20),
            v: Math.max(18, Math.round(cut * 0.45) + 14)
        };
    } else if (shape === "slant") {
        var angle = Math.max(14, Math.round(settingsManager.overlaySlantAngle || 32));
        return {
            h: Math.max(28, angle + 20),
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
