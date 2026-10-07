#!/usr/bin/env lua
-- modules/bar/sound/backend/AudioEngine.lua
-- Pure Lua audio controller & real-time PipeWire event monitor

local action = arg[1] or "get-sink"

local function run_cmd(cmd)
    local p = io.popen(cmd)
    if not p then return "" end
    local out = p:read("*a") or ""
    p:close()
    return out
end

local function get_sink_status()
    local out = run_cmd("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null")
    local is_muted = out:find("%[MUTED%]") ~= nil and 1 or 0
    local num = out:match("([%d%.]+)")
    local vol = num and math.floor(tonumber(num) * 100 + 0.5) or 0
    return vol, is_muted
end

local function get_source_status()
    local out = run_cmd("wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null")
    local is_muted = out:find("%[MUTED%]") ~= nil and 1 or 0
    local num = out:match("([%d%.]+)")
    local vol = num and math.floor(tonumber(num) * 100 + 0.5) or 0
    return vol, is_muted
end

if action == "get-sink" then
    local vol, muted = get_sink_status()
    print(string.format("%d|%d", vol, muted))
    os.exit(0)
end

if action == "get-source" then
    local vol, muted = get_source_status()
    print(string.format("%d|%d", vol, muted))
    os.exit(0)
end

if action == "toggle-sink-mute" then
    os.execute("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null")
    os.exit(0)
end

if action == "toggle-source-mute" then
    os.execute("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null")
    os.exit(0)
end

if action == "set-sink-volume" then
    local step = arg[2] or "5%+"
    os.execute(string.format("wpctl set-volume @DEFAULT_AUDIO_SINK@ %s --limit 1.0 2>/dev/null", step))
    os.exit(0)
end

if action == "switch-sink" then
    -- Check user custom switcher script if present
    local custom_script = (os.getenv("HOME") or "") .. "/nix/hosts/common/scripts/sound_sink_switcher.sh"
    local cf = io.open(custom_script, "r")
    if cf then
        cf:close()
        os.execute(string.format("%q 2>/dev/null", custom_script))
        os.exit(0)
    end

    -- Pure Lua sink rotator parsing `wpctl status`
    local status = run_cmd("wpctl status 2>/dev/null")
    local sinks = {}
    local in_sinks = false

    for line in status:gmatch("[^\r\n]+") do
        if line:find("Sinks:") then
            in_sinks = true
        elseif line:find("Sources:") or line:find("Filters:") or line:find("Streams:") then
            in_sinks = false
        elseif in_sinks then
            local id = line:match("%s*(%d+)%.")
            if id then
                local is_active = line:find("%*") ~= nil
                table.insert(sinks, { id = id, active = is_active })
            end
        end
    end

    if #sinks > 1 then
        local cur_idx = 1
        for i, s in ipairs(sinks) do
            if s.active then cur_idx = i break end
        end
        local next_idx = (cur_idx % #sinks) + 1
        os.execute(string.format("wpctl set-default %s 2>/dev/null", sinks[next_idx].id))
    end
    os.exit(0)
end

-- Persistent real-time event monitor for sink / output audio (catches keyboard hotkeys)
if action == "monitor-sink" then
    local last_vol, last_muted = get_sink_status()
    print(string.format("%d|%d", last_vol, last_muted))
    io.flush()

    local p = io.popen("pactl subscribe 2>/dev/null")
    if not p then
        p = io.popen("pw-mon -b 2>/dev/null")
    end

    if p then
        for line in p:lines() do
            local l = line:lower()
            -- Triggers on sink changes, server volume events, and node props
            if l:find("sink") or l:find("server") or l:find("change") or l:find("node") then
                local vol, muted = get_sink_status()
                if vol ~= last_vol or muted ~= last_muted then
                    last_vol = vol
                    last_muted = muted
                    print(string.format("%d|%d", vol, muted))
                    io.flush()
                end
            end
        end
        p:close()
    end
    os.exit(0)
end

-- Persistent real-time event monitor for microphone / input audio
if action == "monitor-source" then
    local last_vol, last_muted = get_source_status()
    print(string.format("%d|%d", last_vol, last_muted))
    io.flush()

    local p = io.popen("pactl subscribe 2>/dev/null")
    if not p then
        p = io.popen("pw-mon -b 2>/dev/null")
    end

    if p then
        for line in p:lines() do
            local l = line:lower()
            if l:find("source") or l:find("server") or l:find("change") or l:find("node") then
                local vol, muted = get_source_status()
                if vol ~= last_vol or muted ~= last_muted then
                    last_vol = vol
                    last_muted = muted
                    print(string.format("%d|%d", vol, muted))
                    io.flush()
                end
            end
        end
        p:close()
    end
    os.exit(0)
end
