.pragma library

// Formats bytes to clean human-readable units (e.g. 1048576 -> "1.0 MB")
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

// Formats duration in seconds to "Xh Ym Zs" or "M:SS"
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

// POSIX safe shell argument escaping
function escapeShell(str) {
    return "'" + String(str).replace(/'/g, "'\\''") + "'";
}

// Extracts the first HTTP/HTTPS link from plain text
function extractUrl(text) {
    if (!text) return "";
    var match = text.match(/(https?:\/\/[^\s<]+)/);
    return match ? match[0] : "";
}

// Strips HTML and XML tags from a string
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

// Subsequence fuzzy search (checks if needle chars exist in order in haystack)
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
