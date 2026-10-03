#!/usr/bin/env lua

local cmd = arg[1]
local raw_url = arg[2] or ""

local function resolve_target(url)
    local target = ""
    if url:sub(1,7) == "file://" then
        target = url:sub(8)
    end

    if target == "" then
        local p = io.popen("mpc current -f '%file%' 2>/dev/null")
        if p then
            local mpc_file = (p:read("*l") or ""):gsub("^%s*(.-)%s*$", "%1")
            p:close()
            if mpc_file ~= "" then
                local mpd_dir = (os.getenv("HOME") or "") .. "/Music"
                local mf = io.open((os.getenv("HOME") or "") .. "/.config/mpd/mpd.conf", "r")
                if mf then
                    for line in mf:lines() do
                        local d = line:match('^%s*music_directory%s*["\']?([^"\']+)["\']?')
                        if d then mpd_dir = d:gsub("^~", os.getenv("HOME") or ""); break end
                    end
                    mf:close()
                end
                local candidate = mpd_dir .. "/" .. mpc_file
                local check = io.open(candidate, "r")
                if check then check:close(); target = candidate end
            end
        end
    end
    return target
end

-- 1. Open directory in file manager
if cmd == "open-dir" then
    local target = resolve_target(raw_url)
    local dir = (os.getenv("HOME") or "") .. "/Music"
    if target ~= "" then
        local p_test = io.popen("test -d " .. string.format("%q", target) .. " && echo 1 || echo 0")
        local is_dir = p_test and (p_test:read("*l") == "1") or false
        if p_test then p_test:close() end
        if is_dir then
            dir = target
        else
            dir = target:match("(.+)/[^/]+$") or dir
        end
    end

    local fm_candidates = { "xdg-open", "gio open", "nemo", "dolphin", "thunar", "nautilus", "pcmanfm" }
    for _, fm in ipairs(fm_candidates) do
        local bin = fm:match("(%S+)")
        local check = os.execute("command -v " .. bin .. " >/dev/null 2>&1")
        if check == 0 or check == true then
            os.execute(string.format("systemd-run --user --scope --quiet %s %q &", fm, dir))
            break
        end
    end
    os.exit(0)
end

-- 2. Trash current track
if cmd == "trash-track" then
    local target = resolve_target(raw_url)
    if target ~= "" then
        local check = io.open(target, "r")
        if check then
            check:close()
            local fname = target:match("[^/]+$") or target
            local trashed = false

            local gio_check = os.execute("command -v gio >/dev/null 2>&1")
            if gio_check == 0 or gio_check == true then
                os.execute("gio trash " .. string.format("%q", target))
                trashed = true
            else
                local tp_check = os.execute("command -v trash-put >/dev/null 2>&1")
                if tp_check == 0 or tp_check == true then
                    os.execute("trash-put " .. string.format("%q", target))
                    trashed = true
                else
                    local tdir = (os.getenv("XDG_DATA_HOME") or ((os.getenv("HOME") or "") .. "/.local/share")) .. "/Trash/files"
                    os.execute("mkdir -p " .. string.format("%q", tdir) .. " && mv " .. string.format("%q", target) .. " " .. string.format("%q", tdir .. "/"))
                    trashed = true
                end
            end
            if trashed then
                os.execute(string.format("notify-send -a Music -i user-trash 'Moved to Trash' %q", fname))
            end
        end
    end

    -- Update mpc playlist
    os.execute("pos=$(mpc current -f %position% 2>/dev/null); [ -n \"$pos\" ] && mpc del \"$pos\" 2>/dev/null; mpc next 2>/dev/null")
    os.exit(0)
end
