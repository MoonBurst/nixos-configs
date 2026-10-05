#!/usr/bin/env lua
-- AppLauncherEngine.lua: NixOS-aware desktop file scanner that follows symlinks

local function get_home()
    return os.getenv("HOME") or "/home"
end

local function get_user()
    return os.getenv("USER") or "user"
end

-- Collect all valid XDG & NixOS application directories
local search_dirs = {}
local seen_dirs = {}

local function add_dir(d)
    if d and d ~= "" and not seen_dirs[d] then
        seen_dirs[d] = true
        table.insert(search_dirs, d)
    end
end

-- Standard NixOS & Flatpak search paths
add_dir(get_home() .. "/.local/share/applications")
add_dir(get_home() .. "/.nix-profile/share/applications")
add_dir("/etc/profiles/per-user/" .. get_user() .. "/share/applications")
add_dir("/run/current-system/sw/share/applications")
add_dir("/var/lib/flatpak/exports/share/applications")
add_dir(get_home() .. "/.local/share/flatpak/exports/share/applications")
add_dir("/usr/local/share/applications")
add_dir("/usr/share/applications")

-- Also append anything in XDG_DATA_DIRS
local xdg_dirs = os.getenv("XDG_DATA_DIRS") or ""
for dir in string.gmatch(xdg_dirs, "([^:]+)") do
    add_dir(dir .. "/applications")
end

-- Parse recent apps history for relevance ranking
local recent_scores = {}
local recent_file = io.open(get_home() .. "/.cache/quickshell/recent_apps.txt", "r")
if recent_file then
    local rank = 50
    for line in recent_file:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" and not recent_scores[trimmed] then
            recent_scores[trimmed] = rank
            rank = math.max(1, rank - 1)
        end
    end
    recent_file:close()
end

-- Clean exec command removing %u, %F, %U, %k, and env wrappers for display
local function sanitize_exec(cmd)
    if not cmd then return "" end
    cmd = cmd:gsub("%%[a-zA-Z]", ""):match("^%s*(.-)%s*$")
    return cmd
end

-- Read desktop file following symlinks
local function parse_desktop_file(filepath)
    local f = io.open(filepath, "r")
    if not f then return nil end

    local name, exec, icon, nodisplay, is_desktop_entry = nil, nil, nil, false, false

    for line in f:lines() do
        local header = line:match("^%[(.+)%]$")
        if header then
            is_desktop_entry = (header == "Desktop Entry")
        elseif is_desktop_entry then
            local k, v = line:match("^([%w%-_]+)%s*=%s*(.*)$")
            if k and v then
                v = v:match("^%s*(.-)%s*$")
                if k == "Name" and not name then
                    name = v
                elseif k == "Exec" and not exec then
                    exec = sanitize_exec(v)
                elseif k == "Icon" and not icon then
                    icon = v
                elseif k == "NoDisplay" then
                    nodisplay = (v:lower() == "true")
                end
            end
        end
    end
    f:close()

    if nodisplay or not name or not exec or exec == "" then
        return nil
    end

    local rank = recent_scores[exec] or 0
    return string.format("%s|%s|%s|%d", name, exec, icon or "application-x-executable", rank)
end

-- Scan all directories following symlinks (-L)
local seen_apps = {}
for _, dir in ipairs(search_dirs) do
    local handle = io.popen("find -L " .. string.format("%q", dir) .. " -maxdepth 2 -name '*.desktop' 2>/dev/null")
    if handle then
        for filepath in handle:lines() do
            local clean_path = filepath:match("^%s*(.-)%s*$")
            if clean_path and clean_path ~= "" and not seen_apps[clean_path] then
                seen_apps[clean_path] = true
                local entry = parse_desktop_file(clean_path)
                if entry then
                    print(entry)
                end
            end
        end
        handle:close()
    end
end
