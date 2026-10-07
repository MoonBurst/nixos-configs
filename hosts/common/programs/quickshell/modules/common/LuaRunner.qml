pragma Singleton
import QtQuick
import Quickshell

// Centralized Lua launcher. Directly spawns the Lua interpreter
// without spawning /bin/sh or /bin/bash.
Singleton {
    id: runner

    // Returns a process command array invoking lua directly with positional arguments.
    function cmd(relPath) {
        var rest = Array.prototype.slice.call(arguments, 1);
        var cleanRelPath = String(relPath).replace(/^\/+/, "");
        var scriptPath = Quickshell.shellDir + "/" + cleanRelPath;

        var parts = [
            "lua",
            scriptPath
        ];

        for (var i = 0; i < rest.length; i++) {
            parts.push(String(rest[i]));
        }

        return parts;
    }
}
