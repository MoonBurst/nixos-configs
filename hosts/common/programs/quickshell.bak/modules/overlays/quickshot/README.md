# Quickshot

A fast region-selection **screenshot + annotation** tool built with **Qt Quick**
and **[Quickshell](https://quickshell.outfoxxed.me)**, for wlroots-based Wayland
compositors (Hyprland, Sway, river, …).

Quickshot freezes the screen, lets you rubber-band a region, mark it up with a
full set of annotation tools, and then copy it to the clipboard or save it to a
file — all from a single keystroke.

## Features

- **Frozen-frame region selection** across every monitor, with a dimmed veil and
  a live pixel-dimension readout.
- **Move & resize** the selection with eight drag handles.
- **Annotation tools:**
  - ▭ Rectangle &nbsp; ◯ Ellipse
  - ↗ Arrow &nbsp; ╱ Line &nbsp; ✎ Freehand pen
  - ▬ Highlighter (translucent) &nbsp; **T** Text
  - ① Numbered steps &nbsp; ▦ Redact / redact
- **8-colour palette** and four stroke widths.
- **Undo / clear**, keyboard shortcuts for everything.
- **Copy to clipboard** (via `wl-copy`) or **save** to
  `~/Pictures/Screenshots/quickshot_<timestamp>.png`, with a desktop
  notification.
- Annotations are cropped to the selection and exported at **native resolution**
  (HiDPI-aware).

## Requirements

- `quickshell` (with the Wayland **screencopy** feature enabled — it is by
  default)
- A wlroots-style compositor supporting `wlr-screencopy` or
  `ext-image-copy-capture` and `wlr-layer-shell`
- `wl-clipboard` (`wl-copy`) for clipboard support
- `libnotify` (`notify-send`) for save/copy notifications *(optional)*

## Usage

Run it directly:

```sh
./quickshot
```

or point Quickshell at the directory:

```sh
qs -n -p /path/to/quickshot
```

Bind it to your screenshot key. For **Hyprland** (`~/.config/hypr/hyprland.conf`):

```conf
bind = , Print, exec, /path/to/quickshot/quickshot
```

For **Sway**:

```conf
bindsym Print exec /path/to/quickshot/quickshot
```

### Workflow

1. Launch — the screen freezes and dims.
2. **Drag** to select a region.
3. Pick a tool / colour from the toolbar (or use a hotkey) and draw on the
   selection. Switch back to the **Move** tool (`V`) to reposition or resize.
4. **Enter** to copy, **Ctrl+S** to save, **Esc** to cancel.

### Keyboard shortcuts

| Key | Action |
| --- | --- |
| `Esc` | Cancel / quit |
| `Enter` | Copy selection to clipboard |
| `Ctrl+S` | Save selection to file |
| `Ctrl+C` | Copy to clipboard |
| `Ctrl+Z` | Undo last annotation |
| `V` | Move / resize selection |
| `R` `O` `A` `L` `P` `H` `T` `N` `X` | Rectangle, ellipse, arrow, line, pen, highlight, text, number, redact |

## Architecture

A flat Quickshell config directory; Quickshell auto-synthesises the `qmldir`.

| File | Responsibility |
| --- | --- |
| `shell.qml` | Entry point — one `ScreenOverlay` per monitor via `Variants`. |
| `ScreenOverlay.qml` | Per-monitor layershell overlay: frozen `ScreencopyView` backdrop, dim veil, region create/move/resize, keyboard handling, and the grab → crop → save/copy export pipeline. |
| `AnnotationCanvas.qml` | Owns the annotation model + in-progress draft and the inline text editor; exposes the drawing-gesture API. |
| `AnnotationShape.qml` | Renders a single annotation of any type (`QtQuick.Shapes` for vector tools, `ShaderEffectSource` for redact). |
| `Toolbar.qml` | Tool palette, colour/stroke pickers, action buttons. |
| `IconButton.qml`, `Handle.qml`, `ToolbarSeparator.qml` | Reusable UI primitives. |
| `ShotState.qml` *(singleton)* | Shared tool/colour state + cross-monitor coordination. |
| `Style.qml` *(singleton)* | Design tokens (colours, sizes, fonts). |

### How the crop works

The exportable scene (`ScreencopyView` + annotations) lives inside a clipped
`exportClip` item. To export, `exportClip` is resized to the selection and the
scene is shifted by `-(x, y)` so the region aligns to the clip's origin; a single
`grabToImage()` at native pixel dimensions then yields the cropped screenshot.
The dim veil, handles and toolbar are siblings *outside* that subtree, so they
never appear in the output.
