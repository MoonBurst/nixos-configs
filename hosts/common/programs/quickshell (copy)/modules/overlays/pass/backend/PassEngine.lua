#!/usr/bin/env lua

local cmd = arg[1]

local function get_store_dir()
    local dir = os.getenv("PASSWORD_STORE_DIR") or ((os.getenv("HOME") or "") .. "/.password-store")
    local check = io.open(dir .. "/.gpg-id", "r")
    if not check then
        local alt = (os.getenv("HOME") or "") .. "/.local/share/pass"
        local check_alt = io.open(alt .. "/.gpg-id", "r")
        if check_alt then check_alt:close(); dir = alt end
    else
        check:close()
    end
    return dir
end

-- 1. Check if pass CLI exists
if cmd == "check" then
    local p = io.popen("command -v pass 2>/dev/null")
    if p then
        local out = p:read("*l")
        p:close()
        io.write((out and out ~= "") and "1\n" or "0\n")
    else
        io.write("0\n")
    end
    os.exit(0)
end

-- 2. List GPG password keys
if cmd == "list" then
    local dir = get_store_dir()
    local p = io.popen(string.format("cd %q && find . -type f -name '*.gpg' 2>/dev/null | sed 's|^\\./||; s|\\.gpg$||' | sort", dir))
    if p then
        for line in p:lines() do
            if line ~= "" then print(line) end
        end
        p:close()
    end
    os.exit(0)
end

-- 3. Decrypt and copy
if cmd == "copy" then
    local key = arg[2] or ""
    if key ~= "" then
        local dir = get_store_dir()
        local run_cmd = string.format("PASSWORD_STORE_DIR=%q pass -c %q >/dev/null 2>&1 && notify-send -a Pass -u normal -i dialog-password '🔑 Password Copied' 'Auto-clearing clipboard in 45s...'", dir, key)
        os.execute(run_cmd)
    end
    os.exit(0)
end
