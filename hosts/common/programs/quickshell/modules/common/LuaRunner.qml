pragma Singleton
import QtQuick
import Quickshell

// Centralized Lua launcher. Every `Process { command: [...] }` that invokes a
// backend Lua script in this shell should go through `LuaRunner.cmd(...)`.
//
// What this gives us:
//
//  * One place to set up PATH so `luajit` is preferred over `lua` when present.
//  * Positional-argument passing (never string-concatenated) so script paths
//    and user-supplied arguments cannot break out of their shell context.
//  * A single line at every call site instead of a 4-6 line sh -c wrapper.
//
// Usage:
//   Process {
//       command: LuaRunner.cmd("modules/bar/cpu/backend/CpuEngine.lua", "top-procs")
//   }
Singleton {
    id: runner

    // Returns a `command: [...]` array. `relPath` is relative to shellDir;
    // every subsequent argument is forwarded verbatim as a positional
    // parameter ($1, $2, ... to the Lua script via `arg`).
    function cmd(relPath) {
        var rest = Array.prototype.slice.call(arguments, 1);
        var parts = [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="$1/$2"; shift 2; ' +
            'CMD="lua"; command -v luajit >/dev/null 2>&1 && CMD="luajit"; ' +
            'exec "$CMD" "$SCR" "$@"',
            "sh",
            Quickshell.shellDir,
            String(relPath)
        ];
        for (var i = 0; i < rest.length; i++) {
            parts.push(String(rest[i]));
        }
        return parts;
    }

    // Same as `cmd` but for Python scripts. Uses python3 unconditionally so
    // the shell does not have to detect the interpreter on every call.
    function py(relPath) {
        var rest = Array.prototype.slice.call(arguments, 1);
        var parts = [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="$1/$2"; shift 2; ' +
            'exec python3 "$SCR" "$@"',
            "sh",
            Quickshell.shellDir,
            String(relPath)
        ];
        for (var i = 0; i < rest.length; i++) {
            parts.push(String(rest[i]));
        }
        return parts;
    }
}
