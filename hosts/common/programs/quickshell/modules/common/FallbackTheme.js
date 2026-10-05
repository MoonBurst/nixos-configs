.pragma library

// Single shared fallback for when a parent `shell` context is absent.
// Because `.pragma library` files are loaded exactly once per engine, every
// window that imports this file reads the same object — no per-window
// QtObject instantiation, no duplicative memory.

var theme = {
    base00: "#0f0f0f",
    base01: "#181825",
    base02: "#313244",
    base03: "#003399",
    base04: "#45475a",
    base05: "#f7f700",
    base06: "#cdd6f4",
    base07: "#b4befe",
    base08: "#ff0000",
    base09: "#fe8019",
    base0A: "#fabd2f",
    base0B: "#a6adc8",
    base0C: "#04f100",
    base0D: "#003399",
    base0E: "#cba6f7",
    base0F: "#eba0ac",

    fontFamily: "monospace",
    globalFontSize: 16,
    globalHeaderSize: 16,
    globalBorderWidth: 3,
    controlBorderWidth: 2,
    globalPadding: 12,
    slantWidth: 12,

    defaultCardWidth: 420,
    defaultCardHeight: 140,
    defaultCardRadius: 10,

    outerBorderColor: "#003399",
    innerBorderColor: "#f7f700",
    scrollHandleColor: "#003399"
};
