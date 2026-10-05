#!/usr/bin/env luajit
-- Reads /sys/class/power_supply/*/capacity, status, power_now.
-- Subcommands:
--   detect            prints the first battery device name, or nothing
--   poll [name]       prints "pct:status:watt" (auto-detects if name empty)

local function read_file(p)
    local f = io.open(p, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function list_batteries()
    local h = io.popen("ls /sys/class/power_supply/ 2>/dev/null")
    if not h then return {} end
    local bats = {}
    for line in h:lines() do
        if line:match("^BAT") or line:match("^sb") then
            bats[#bats + 1] = line
        end
    end
    h:close()
    return bats
end

local action = arg[1] or "poll"
local name = arg[2]

if action == "detect" then
    local bats = list_batteries()
    if #bats > 0 then print(bats[1]) end
    return
end

if action == "poll" then
    if not name or name == "" then
        local bats = list_batteries()
        if #bats == 0 then
            print("--:Unknown:0.0W")
            return
        end
        name = bats[1]
    end

    local dir = "/sys/class/power_supply/" .. name
    local cap = (read_file(dir .. "/capacity") or "0"):gsub("%s+", "")
    local stat = (read_file(dir .. "/status") or "Unknown"):gsub("%s+", "")

    local watt = "0.0"
    local power_now = read_file(dir .. "/power_now")
    if power_now then
        local n = tonumber(power_now:match("^(%d+)")) or 0
        watt = string.format("%.1f", n / 1000000)
    else
        local v = read_file(dir .. "/voltage_now")
        local c = read_file(dir .. "/current_now")
        if v and c then
            local vn = tonumber(v:match("^(%d+)")) or 0
            local cn = tonumber(c:match("^(%d+)")) or 0
            watt = string.format("%.1f", (vn * cn) / 1e12)
        end
    end

    print(string.format("%s:%s:%sW", cap, stat, watt))
end
