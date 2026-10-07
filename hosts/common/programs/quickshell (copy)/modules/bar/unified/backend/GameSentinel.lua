#!/usr/bin/env luajit
-- Detects whether a listed game is running and whether a storm hold is
-- active. Emits {"gaming":bool,"storm":bool}.

local function read_file(p)
    local f = io.open(p, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function list_procs()
    local out = {}
    local h = io.popen("ls /proc 2>/dev/null")
    if not h then return out end
    for pid_str in h:lines() do
        local pid = tonumber(pid_str)
        if pid then
            local cmd = read_file("/proc/" .. pid .. "/cmdline")
            if cmd then
                out[#out + 1] = cmd:gsub("%z", " ")
            end
        end
    end
    h:close()
    return out
end

local function game_running(patterns)
    if #patterns == 0 then return false end
    for _, argv in ipairs(list_procs()) do
        for _, pat in ipairs(patterns) do
            if pat ~= "" and argv:find(pat, 1, true) then
                return true
            end
        end
    end
    return false
end

local home = os.getenv("HOME") or ""
local config_dir = home .. "/.config/quickshell"
local games_file = config_dir .. "/games_list.json"

os.execute(string.format("mkdir -p %q", config_dir))
if not read_file(games_file) then
    os.execute(string.format("printf '%%s' %q > %q",
        '["Overwatch.exe","MapleStory","MapleStory.exe"]', games_file))
end

local patterns = {}
for pat in (read_file(games_file) or ""):gmatch('"([^"]+)"') do
    patterns[#patterns + 1] = pat
end

local gaming = game_running(patterns)
local storm = read_file("/dev/shm/weather-storm-active.txt") ~= nil

print(string.format('{"gaming":%s,"storm":%s}',
    gaming and "true" or "false",
    storm and "true" or "false"))
