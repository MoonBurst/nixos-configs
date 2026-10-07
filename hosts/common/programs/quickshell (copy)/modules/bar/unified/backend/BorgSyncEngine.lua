#!/usr/bin/env luajit
-- Merges /dev/shm/borg-offsite-status.json with live service/mount state.
-- Emits a single flat JSON object.

local function read_file(p)
    local f = io.open(p, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function get_field(json, key)
    -- Anchor the pattern at the colon, then use find's end offset (the
    -- second return value) so variable whitespace after the colon does
    -- not throw off where the value starts.
    local pat = '"' .. key .. '"%s*:%s*'
    local _, match_end = json:find(pat)
    if not match_end then return nil end
    local rest = json:sub(match_end + 1)
    local sv = rest:match('^"([^"]*)"')
    if sv then return sv end
    local nv = rest:match("^(%-?%d+%.?%d*)")
    if nv then return tonumber(nv) end
    if rest:match("^true")  then return true end
    if rest:match("^false") then return false end
    return nil
end

local function service_is_active(unit)
    local h = io.popen("systemctl is-active " .. unit .. " 2>/dev/null")
    if not h then return false end
    local state = (h:read("*a") or ""):gsub("%s+", "")
    h:close()
    return state == "active" or state == "activating"
end

local function is_mounted(path)
    local f = io.open("/proc/mounts", "r")
    if not f then return false end
    for line in f:lines() do
        if line:match("^%S+%s+(" .. path:gsub("%-", "%%-") .. ")") then
            f:close(); return true
        end
    end
    f:close()
    return false
end

local function esc(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub('\\', '\\\\'):gsub('"', '\\"'))
end

local status_json = read_file("/dev/shm/borg-offsite-status.json") or '{"status":"idle"}'
local act = service_is_active("sync-backup-to-nextcloud.service")
local mnt = is_mounted("/tmp/borg-mount")

local status   = get_field(status_json, "status")        or "idle"
local speed    = get_field(status_json, "speed")         or "0 MB/s"
local eta      = get_field(status_json, "eta")           or ""
-- Producer writes these as strings; coerce before any arithmetic.
local percent  = tonumber(get_field(status_json, "percent"))       or 0
local total    = tonumber(get_field(status_json, "total_size"))    or 0
local uploaded = tonumber(get_field(status_json, "uploaded_size")) or 0

print(string.format(
    '{"status":"%s","percent":%d,"speed":"%s","eta":"%s","total_size":%s,"uploaded_size":%s,"service_active":%s,"mounted":%s}',
    esc(status), math.floor(percent),
    esc(speed), esc(eta),
    tostring(total), tostring(uploaded),
    act and "true" or "false",
    mnt and "true" or "false"))
