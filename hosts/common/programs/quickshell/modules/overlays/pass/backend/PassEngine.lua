#!/usr/bin/env lua

local cmd = arg[1] or "list"

local function get_store_dir()
local env_dir = os.getenv("PASSWORD_STORE_DIR")
if env_dir and env_dir ~= "" then
    return env_dir
    end
    local home = os.getenv("HOME") or "/home"
    return home .. "/.password-store"
    end

    if cmd == "check" then
        local dir = get_store_dir()
        local p = io.popen("command -v pass >/dev/null 2>&1 || [ -d '" .. dir .. "' ] && echo 1 || echo 0")
        if p then
            local res = p:read("*l") or "0"
            p:close()
            print(res:match("1") and "1" or "0")
            else
                print("0")
                end

                elseif cmd == "list" then
                    local dir = get_store_dir()
                    -- Recursively list all .gpg keys, strip base path & .gpg suffix, and sort
                    local find_cmd = 'find -L "' .. dir .. '" -type f -name "*.gpg" 2>/dev/null | sed -e "s|^' .. dir .. '/||" -e "s|\\.gpg$||" | sort'
                    local p = io.popen(find_cmd)
                    if p then
                        for line in p:lines() do
                            local clean = line:match("^%s*(.-)%s*$")
                            if clean and clean ~= "" then
                                print(clean)
                                end
                                end
                                p:close()
                                end

                                elseif cmd == "copy" then
                                    local key = arg[2]
                                    if not key or key == "" then return end
                                        local timeout = tonumber(arg[3]) or 20

                                        local runtime = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
                                        local lock = runtime .. "/quickshell-pass-copying"

                                        -- 1. Create lockfile so cliphist watcher ignores this copy
                                        os.execute("touch '" .. lock .. "' 2>/dev/null")

                                        -- 2. Decrypt only the first line (the password) into wl-copy
                                        os.execute('pass show "' .. key .. '" 2>/dev/null | head -n 1 | tr -d "\\r\\n" | wl-copy 2>/dev/null')

                                        -- 3. Detached background worker:
                                        --    - Releases lock after cliphist watch cycle
                                        --    - Purges secret from cliphist database if captured
                                        --    - Waits the full timeout, then wipes the active clipboard
                                        local background_worker = string.format([[
                                            (
                                                sleep 0.5
                                                rm -f '%s'
                                            cliphist list 2>/dev/null | head -n 1 | cliphist delete 2>/dev/null || true
                                            sleep %d
                                            wl-copy --clear 2>/dev/null || wl-copy </dev/null 2>/dev/null || true
                                            cliphist list 2>/dev/null | head -n 1 | cliphist delete 2>/dev/null || true
                                            ) >/dev/null 2>&1 &
                                        ]], lock, timeout)

                                        os.execute(background_worker)
                                        end
