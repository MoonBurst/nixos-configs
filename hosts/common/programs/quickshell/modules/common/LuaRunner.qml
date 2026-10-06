pragma Singleton
import QtQuick
import Quickshell

// Centralized execution engine for backend scripts across the entire shell.
//
// Benefits:
//  1. Unified PATH: Ensures NixOS profiles, local user bins, and system bins
//     are searched so `luajit` is preferred over `lua` when available.
//  2. Safe Argument Forwarding: Passes arguments positionally ($1, $2, ... $@),
//     preventing shell injection and unescaped quote syntax errors.
//  3. Path Normalization: Strips leading slashes from relative paths so callers
//     can safely pass either "modules/..." or "/modules/...".
//  4. Resource Efficiency: Uses `exec` to replace the shell process, avoiding
//     unnecessary dangling child processes in memory.
//
// Usage:
//   Process {
//       command: Common.LuaRunner.cmd("modules/bar/cpu/backend/CpuEngine.lua", "top-procs")
//   }
Singleton {
    id: runner

    // Dispatches a Lua script using the preferred LuaJIT/Lua runtime.
    //  - relPath: Path relative to Quickshell.shellDir
    //  - ...rest: Optional arguments forwarded as positional parameters to the script
    function cmd(relPath) {
        // Strip leading slashes to prevent double-slash path expansion
        var cleanRel = String(relPath || "").replace(/^\/+/, "");
        var rest = Array.prototype.slice.call(arguments, 1);

        var parts = [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="$1/$2"; shift 2; ' +
            'CMD="lua"; command -v luajit >/dev/null 2>&1 && CMD="luajit"; ' +
            'exec "$CMD" "$SCR" "$@"',
            "sh",
            Quickshell.shellDir,
            cleanRel
        ];

        for (var i = 0; i < rest.length; i++) {
            parts.push(String(rest[i]));
        }
        return parts;
    }

    // Dispatches a Python script using python3.
    //  - relPath: Path relative to Quickshell.shellDir
    //  - ...rest: Optional arguments forwarded as positional parameters
    function py(relPath) {
        var cleanRel = String(relPath || "").replace(/^\/+/, "");
        var rest = Array.prototype.slice.call(arguments, 1);

        var parts = [
            "sh", "-c",
            'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"; ' +
            'SCR="$1/$2"; shift 2; ' +
            'exec python3 "$SCR" "$@"',
            "sh",
            Quickshell.shellDir,
            cleanRel
        ];

        for (var i = 0; i < rest.length; i++) {
            parts.push(String(rest[i]));
        }
        return parts;
    }
}
