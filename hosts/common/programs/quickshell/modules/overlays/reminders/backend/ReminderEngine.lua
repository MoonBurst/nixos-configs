#!/usr/bin/env lua

local action = arg[1] or "list"

local function get_storage_path()
    local xdg_data = os.getenv("XDG_DATA_HOME")
    local base = (xdg_data and xdg_data ~= "") and xdg_data or ((os.getenv("HOME") or "/tmp") .. "/.local/share")
    return base .. "/quickshell/reminders.json"
end

local function json_escape(str)
    if not str then return "" end
    str = str:gsub("\\", "\\\\")
    str = str:gsub('"', '\\"')
    str = str:gsub("\n", "\\n")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\t", "\\t")
    return str
end

local function load_reminders()
    local path = get_storage_path()
    local f = io.open(path, "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()
    if not content or content == "" then return {} end

    local list = {}
    for obj in content:gmatch("%{.-%}") do
        local id = tonumber(obj:match('"id"%s*:%s*(%d+)'))
        local text = obj:match('"text"%s*:%s*"(.-)"')
        local targetEpoch = tonumber(obj:match('"targetEpoch"%s*:%s*(%d+)'))
        local targetStr = obj:match('"targetStr"%s*:%s*"(.-)"')
        if id and text and targetEpoch then
            table.insert(list, {
                id = id,
                text = text:gsub('\\"', '"'):gsub('\\\\', '\\'),
                targetEpoch = targetEpoch,
                targetStr = targetStr or ""
            })
        end
    end
    return list
end

local function save_reminders(list)
    local path = get_storage_path()
    local dir = path:match("(.+)/[^/]+$")
    if dir then
        os.execute("mkdir -p '" .. dir .. "' 2>/dev/null")
    end

    local f = io.open(path, "w")
    if not f then return end

    f:write("[\n")
    for i, r in ipairs(list) do
        local comma = (i < #list) and "," or ""
        f:write(string.format('  {"id":%d,"text":"%s","targetEpoch":%d,"targetStr":"%s"}%s\n',
            r.id, json_escape(r.text), r.targetEpoch, json_escape(r.targetStr), comma))
    end
    f:write("]\n")
    f:close()
end

local function output_json(list)
    local entries = {}
    for _, r in ipairs(list) do
        table.insert(entries, string.format('{"id":%d,"text":"%s","targetEpoch":%d,"targetStr":"%s"}',
            r.id, json_escape(r.text), r.targetEpoch, json_escape(r.targetStr)))
    end
    print("[" .. table.concat(entries, ",") .. "]")
end

local function parse_time_expr(expr)
    if not expr or expr == "" then return nil, nil end
    local s = expr:lower():match("^%s*(.-)%s*$")
    local now = os.time()
    local total_sec = 0
    local matched_rel = false

    for num, unit in s:gmatch("(%d+)%s*([dhms])") do
        matched_rel = true
        local n = tonumber(num)
        if unit == "d" then total_sec = total_sec + n * 86400
        elseif unit == "h" then total_sec = total_sec + n * 3600
        elseif unit == "m" then total_sec = total_sec + n * 60
        elseif unit == "s" then total_sec = total_sec + n
        end
    end

    if matched_rel and total_sec > 0 then
        local target = now + total_sec
        return target, os.date("%a, %b %d at %I:%M %p", target)
    end

    if s:match("^%d+$") then
        local target = now + tonumber(s) * 60
        return target, os.date("%a, %b %d at %I:%M %p", target)
    end

    local is_tomorrow = s:find("tomorrow") ~= nil
    local clean = s:gsub("tomorrow", ""):match("^%s*(.-)%s*$")
    local h, m, ampm = clean:match("^(%d+):?(%d*)%s*(%a*)$")
    if h then
        local hours = tonumber(h)
        local mins = tonumber(m) or 0
        ampm = ampm:lower()
        if ampm == "pm" and hours < 12 then hours = hours + 12 end
        if ampm == "am" and hours == 12 then hours = 0 end

        local now_t = os.date("*t", now)
        local target_t = {
            year = now_t.year,
            month = now_t.month,
            day = now_t.day,
            hour = hours,
            min = mins,
            sec = 0
        }
        local target = os.time(target_t)
        if is_tomorrow or target <= now then
            target = target + 86400
        end
        return target, os.date("%a, %b %d at %I:%M %p", target)
    end

    return nil, nil
end

if action == "list" then
    output_json(load_reminders())

elseif action == "check" then
    local now = os.time()
    local list = load_reminders()
    local remaining = {}
    local changed = false

    for _, r in ipairs(list) do
        if now >= r.targetEpoch then
            changed = true
            local safe_text = r.text:gsub("'", "'\\''")
            local notify_cmd = string.format("notify-send -u critical -a 'Reminder' -i 'alarm' '⏰ CRITICAL REMINDER' '%s'", safe_text)
            os.execute(notify_cmd)
            os.execute("pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || pw-play /usr/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null || true")
        else
            table.insert(remaining, r)
        end
    end

    if changed then
        save_reminders(remaining)
    end
    output_json(remaining)

elseif action == "add" then
    local text = arg[2]
    local when_expr = arg[3]
    if not text or text == "" or not when_expr or when_expr == "" then
        output_json(load_reminders())
        return
    end

    local epoch, target_str = parse_time_expr(when_expr)
    if not epoch or epoch <= os.time() then
        output_json(load_reminders())
        return
    end

    local list = load_reminders()
    table.insert(list, {
        id = math.floor(os.time() * 1000 + math.random(100, 999)),
        text = text,
        targetEpoch = epoch,
        targetStr = target_str
    })
    table.sort(list, function(a, b) return a.targetEpoch < b.targetEpoch end)
    save_reminders(list)

    local safe_text = text:gsub("'", "'\\''")
    local sched_msg = string.format("'%s' scheduled for %s", safe_text, target_str)
    os.execute("notify-send -a 'Reminder' -i 'alarm' '⏰ Reminder Scheduled' " .. string.format("'%s'", sched_msg))

    output_json(list)

elseif action == "delete" then
    local target_id = tonumber(arg[2])
    if not target_id then
        output_json(load_reminders())
        return
    end

    local list = load_reminders()
    local next_list = {}
    for _, r in ipairs(list) do
        if r.id ~= target_id then
            table.insert(next_list, r)
        end
    end
    save_reminders(next_list)
    output_json(next_list)

elseif action == "clear" then
    save_reminders({})
    output_json({})
end
