#!/usr/bin/env lua

local function check_active(unit)
    local p = io.popen("systemctl is-active " .. unit .. " 2>/dev/null")
    if not p then return false end
    local res = p:read("*l") or ""
    p:close()
    return res:match("^active$") ~= nil
end

local function get_logs(unit)
    local p = io.popen("journalctl -u " .. unit .. " -n 15 --no-pager -o cat 2>/dev/null")
    if not p then return "" end
    local content = p:read("*a") or ""
    p:close()
    return content
end

local function parse_miner(logs)
    local watching, claim, err = "", "", false
    local lines = {}
    for line in logs:gmatch("[^\r\n]+") do table.insert(lines, line) end

    local tail_count = 8
    local tail8 = ""
    for i = math.max(1, #lines - tail_count + 1), #lines do
        tail8 = tail8 .. " " .. lines[i]
    end

    local idle = tail8:find("Exiting") or tail8:find("All drops claimed") or
                 tail8:find("No active campaigns") or tail8:find("No channels available") or tail8:find("Idle")

    for _, line in ipairs(lines) do
        if line:find("Watching:") then
            watching = line:match("Watching:%s*(%S+)") or ""
        end
        if line:find("Claimed drop:") then
            claim = line:match("Claimed drop:%s*(.-)$") or ""
            claim = claim:sub(1, 35)
        end
    end

    if idle then watching = "" end

    local tail5 = ""
    for i = math.max(1, #lines - 4), #lines do tail5 = tail5 .. " " .. lines[i] end
    if tail5:find("401 Unauthorized") or tail5:find("403 Forbidden") or tail5:find("rate limit") or tail5:find("integrity check failed") then
        err = true
    end

    return watching, claim, err
end

local m_run = check_active("podman-twitch-miner.service")
local b_run = check_active("podman-twitchminer-berrydrop.service")

local m_watch, m_claim, m_err = "", "", false
local b_watch, b_claim, b_err = "", "", false

if m_run then m_watch, m_claim, m_err = parse_miner(get_logs("podman-twitch-miner.service")) end
if b_run then b_watch, b_claim, b_err = parse_miner(get_logs("podman-twitchminer-berrydrop.service")) end

local function esc(s) return s:gsub('\\', '\\\\'):gsub('"', '\\"') end

io.write(string.format(
    '{"main_running":%s,"berry_running":%s,"main_watching":"%s","berry_watching":"%s","main_claim":"%s","berry_claim":"%s","main_err":%s,"berry_err":%s}\n',
    m_run and "1" or "0", b_run and "1" or "0",
    esc(m_watch), esc(b_watch), esc(m_claim), esc(b_claim),
    m_err and "1" or "0", b_err and "1" or "0"
))
