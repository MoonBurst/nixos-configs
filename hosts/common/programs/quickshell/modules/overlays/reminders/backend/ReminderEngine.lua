#!/usr/bin/env lua
-- modules/overlays/reminders/backend/ReminderEngine.lua
-- Pure Lua reminder engine: JSON storage, interval parsing, and due-check dispatcher

local action = arg[1] or "list"

local function get_data_path()
    local home = os.getenv("HOME") or "/tmp"
    local dir = (os.getenv("XDG_DATA_HOME") or (home .. "/.local/share")) .. "/quickshell"
    os.execute("mkdir -p " .. string.format("%q", dir))
    return dir .. "/reminders.json"
end

local data_file = get_data_path()

-- Minimal JSON decoder in Lua
local function decode_json(str)
    if not str or str:match("^%s*$") then return {} end
    local items = {}
    for entry in str:gmatch("%b{}") do
        local id = entry:match('"id":%s*([%-%d]+)')
        local text = entry:match('"text":%s*"([^"]+)"')
        local epoch = entry:match('"targetEpoch":%s*([%-%d]+)')
        local target_str = entry:match('"targetStr":%s*"([^"]+)"')
        if id and text and epoch then
            table.insert(items, {
                id = tonumber(id),
                text = text:gsub('\\"', '"'),
                targetEpoch = tonumber(epoch),
                targetStr = target_str or ""
            })
        end
    end
    return items
end

-- Minimal JSON array encoder in Lua
local function encode_json(items)
    local parts = {}
    for _, item in ipairs(items) do
        local safe_text = (item.text or ""):gsub('"', '\\"')
        local safe_str = (item.targetStr or ""):gsub('"', '\\"')
        table.insert(parts, string.format(
            '{"id":%d,"text":"%s","targetEpoch":%d,"targetStr":"%s"}',
            item.id or 0, safe_text, item.targetEpoch or 0, safe_str
        ))
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local function load_reminders()
    local f = io.open(data_file, "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()
    return decode_json(content)
end

local function save_reminders(items)
    local f = io.open(data_file, "w")
    if f then
        f:write(encode_json(items))
        f:close()
    end
end

-- Natural interval and time parser in pure Lua
local function parse_when_expression(when_str)
    local now = os.time()
    local str = (when_str or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if str == "" then return now + 900, "+15m" end

    -- Compound "+Xh Ym" or "Xh Ym"
    local h, m = str:match("(%d+)%s*h%w*%s*(%d+)%s*m")
    if h and m then
        local sec = (tonumber(h) * 3600) + (tonumber(m) * 60)
        return now + sec, "+" .. h .. "h " .. m .. "m"
    end

    -- Hours only ("1h", "2 hours")
    local hours = str:match("(%d+)%s*h")
    if hours then
        local sec = tonumber(hours) * 3600
        return now + sec, "+" .. hours .. "h"
    end

    -- Minutes only ("15m", "30 mins", "5m")
    local mins = str:match("(%d+)%s*m")
    if mins then
        local sec = tonumber(mins) * 60
        return now + sec, "+" .. mins .. "m"
    end

    -- Seconds only ("45s")
    local secs = str:match("(%d+)%s*s")
    if secs then
        local sec = tonumber(secs)
        return now + sec, "+" .. secs .. "s"
    end

    -- Tomorrow with time ("tomorrow 9am", "tomorrow 14:00")
    if str:find("tomorrow") then
        local now_table = os.date("*t", now)
        now_table.day = now_table.day + 1
        local th, tm = str:match("(%d+):(%d+)")
        if not th then
            local t12, ampm = str:match("(%d+)%s*(%a+)")
            if t12 then
                th = tonumber(t12)
                if ampm == "pm" and th < 12 then th = th + 12 end
                if ampm == "am" and th == 12 then th = 0 end
                tm = 0
            end
        end
        now_table.hour = tonumber(th) or 9
        now_table.min = tonumber(tm) or 0
        now_table.sec = 0
        local target = os.time(now_table)
        return target, os.date("Tomorrow at %I:%M %p", target)
    end

    -- Time of day ("5pm", "17:00", "9:30am")
    local th, tm = str:match("(%d+):(%d+)")
    if not th then
        local t12, ampm = str:match("(%d+)%s*([ap]m)")
        if t12 then
            th = tonumber(t12)
            if ampm == "pm" and th < 12 then th = th + 12 end
            if ampm == "am" and th == 12 then th = 0 end
            tm = 0
        end
    end

    if th then
        local now_table = os.date("*t", now)
        now_table.hour = tonumber(th) or 12
        now_table.min = tonumber(tm) or 0
        now_table.sec = 0
        local target = os.time(now_table)
        if target <= now then
            target = target + 86400 -- Schedule for next day if time has already passed
        end
        return target, os.date("%I:%M %p", target)
    end

    -- Raw minute digit fallback ("15")
    local raw_num = tonumber(str)
    if raw_num and raw_num > 0 then
        return now + (raw_num * 60), "+" .. raw_num .. "m"
    end

    -- Default fallback: 15 minutes
    return now + 900, "+15m"
end

if action == "list" then
    local items = load_reminders()
    table.sort(items, function(a, b) return (a.targetEpoch or 0) < (b.targetEpoch or 0) end)
    print(encode_json(items))
    os.exit(0)
end

if action == "add" then
    local text = arg[2] or "Reminder"
    local when_str = arg[3] or "15m"
    local target_epoch, display_str = parse_when_expression(when_str)
    local items = load_reminders()
    local new_id = os.time() + math.random(100, 999)

    table.insert(items, {
        id = new_id,
        text = text,
        targetEpoch = target_epoch,
        targetStr = display_str
    })
    table.sort(items, function(a, b) return (a.targetEpoch or 0) < (b.targetEpoch or 0) end)
    save_reminders(items)
    print(encode_json(items))
    os.exit(0)
end

if action == "delete" then
    local id_to_delete = tonumber(arg[2]) or 0
    local items = load_reminders()
    local filtered = {}
    for _, item in ipairs(items) do
        if item.id ~= id_to_delete then
            table.insert(filtered, item)
        end
    end
    save_reminders(filtered)
    print(encode_json(filtered))
    os.exit(0)
end

if action == "check" then
    local items = load_reminders()
    local now = os.time()
    local remaining = {}
    local triggered = false

    for _, item in ipairs(items) do
        if item.targetEpoch and item.targetEpoch <= now then
            triggered = true
            local safe_text = (item.text or "Scheduled reminder"):gsub('"', '\\"')
            os.execute(string.format('notify-send -u critical -a "Reminders" -i "alarm-symbolic" "⏰ REMINDER DUE" %q 2>/dev/null', safe_text))
            os.execute('pw-play /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &')
        else
            table.insert(remaining, item)
        end
    end

    if triggered then
        save_reminders(remaining)
    end
    print(encode_json(remaining))
    os.exit(0)
end
