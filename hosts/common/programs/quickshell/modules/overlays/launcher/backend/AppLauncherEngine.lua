#!/usr/bin/env lua

local seen_execs = {}

local function escape_str(s)
    return s:gsub("^%s*(.-)%s*$", "%1")
end

-- 1. Read Recently Launched Apps
local recent_file = (os.getenv("HOME") or "") .. "/.cache/quickshell/recent_apps.txt"
local recent_ranks = {}
local rf = io.open(recent_file, "r")
if rf then
    local score = 1000
    for line in rf:lines() do
        local clean = escape_str(line):lower()
        if clean ~= "" and not recent_ranks[clean] then
            recent_ranks[clean] = score
            score = score - 1
            if score <= 1 then break end
        end
    end
    rf:close()
end

local xdg_dirs = {}
local xdg_data = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
table.insert(xdg_dirs, xdg_data .. "/applications")

local xdg_dirs_env = os.getenv("XDG_DATA_DIRS")
if xdg_dirs_env then
    for dir in xdg_dirs_env:gmatch("[^:]+") do
        table.insert(xdg_dirs, dir .. "/applications")
    end
else
    table.insert(xdg_dirs, "/usr/local/share/applications")
    table.insert(xdg_dirs, "/usr/share/applications")
end

local u = os.getenv("USER") or ""
local extra_dirs = {
    os.getenv("HOME") .. "/.nix-profile/share/applications",
    "/etc/profiles/per-user/" .. u .. "/share/applications",
    "/run/current-system/sw/share/applications",
    "/nix/var/nix/profiles/default/share/applications",
    "/var/lib/flatpak/exports/share/applications",
    os.getenv("HOME") .. "/.local/share/flatpak/exports/share/applications",
    os.getenv("HOME") .. "/Desktop"
}
for _, d in ipairs(extra_dirs) do table.insert(xdg_dirs, d) end

local app_list = {}

-- 2. Scan .desktop files
for _, app_dir in ipairs(xdg_dirs) do
    local p = io.popen("find " .. string.format("%q", app_dir) .. " -maxdepth 3 -type f -name '*.desktop' 2>/dev/null")
    if p then
        for file in p:lines() do
            local f = io.open(file, "r")
            if f then
                local in_entry = false
                local name, exec_cmd, icon = nil, nil, "application-x-executable"
                local nodisp = false
                for line in f:lines() do
                    line = escape_str(line)
                    if line == "[Desktop Entry]" then
                        in_entry = true
                    elseif line:sub(1,1) == "[" and in_entry then
                        break
                    elseif in_entry then
                        if line:sub(1,5) == "Name=" and not name then
                            name = line:sub(6)
                        elseif line:sub(1,5) == "Exec=" and not exec_cmd then
                            exec_cmd = line:sub(6):gsub("%%[a-zA-Z]", ""):gsub("^%s*(.-)%s*$", "%1")
                        elseif line:sub(1,5) == "Icon=" and icon == "application-x-executable" then
                            icon = line:sub(6)
                        elseif line:lower() == "nodisplay=true" then
                            nodisp = true
                        end
                    end
                end
                f:close()

                if not nodisp and name and exec_cmd and exec_cmd ~= "" then
                    local key = exec_cmd:lower()
                    if not seen_execs[key] then
                        seen_execs[key] = true
                        if icon:sub(1,11) == "steam_icon_" then
                            local resolved = nil
                            for _, sz in ipairs({"256x256", "128x128", "64x64", "48x48", "32x32"}) do
                                local ip = os.getenv("HOME") .. "/.local/share/icons/hicolor/" .. sz .. "/apps/" .. icon .. ".png"
                                local check = io.open(ip, "r")
                                if check then check:close(); resolved = "file://" .. ip; break end
                            end
                            icon = resolved or "steam"
                        end
                        local rank = recent_ranks[key] or 0
                        table.insert(app_list, { name = name, exec = exec_cmd, icon = icon, rank = rank })
                    end
                end
            end
        end
        p:close()
    end
end

-- 3. Index system PATH
local path_env = os.getenv("PATH") or ""
for dir in path_env:gmatch("[^:]+") do
    local p = io.popen("find " .. string.format("%q", dir) .. " -maxdepth 1 -type f -executable 2>/dev/null")
    if p then
        for exec_path in p:lines() do
            local bin = exec_path:match("[^/]+$")
            if bin and not seen_execs[bin:lower()] then
                seen_execs[bin:lower()] = true
                local rank = recent_ranks[bin:lower()] or 0
                table.insert(app_list, { name = bin, exec = bin, icon = "application-x-executable", rank = rank })
            end
        end
        p:close()
    end
end

-- 4. Sort: Most recent first, then alphabetical
table.sort(app_list, function(a, b)
    if a.rank ~= b.rank then
        return a.rank > b.rank
    end
    return a.name:lower() < b.name:lower()
end)

for _, app in ipairs(app_list) do
    io.write(app.name .. "|" .. app.exec .. "|" .. app.icon .. "|" .. tostring(app.rank) .. "\n")
end
