#!/usr/bin/env lua
-- modules/bar/alarm/backend/AlarmEngine.lua
-- Pure Lua alarm state engine with 3-second auto-kill

local action = arg[1] or "check-player"

if action == "check-player" then
    local p = io.popen("command -v pw-play 2>/dev/null")
    if p then
        local out = p:read("*a") or ""
        p:close()
        print(out:find("pw%-play") and "1" or "0")
    else
        print("0")
    end
    os.exit(0)
end

if action == "save" then
    local state_file = arg[2]
    local current_epoch = tonumber(arg[3]) or os.time()
    local total_seconds = tonumber(arg[4]) or 0
    local msg = arg[5] or "Alarm Finished!"

    if state_file and total_seconds > 0 then
        local target_epoch = current_epoch + total_seconds
        local f = io.open(state_file, "w")
        if f then
            -- Format: target_epoch | total_seconds | msg | ringing_start_epoch (0 = not yet ringing)
            f:write(string.format("%d|%d|%s|0", target_epoch, total_seconds, msg))
            f:close()
        end
    end
    os.exit(0)
end

if action == "cancel" then
    local state_file = arg[2]
    if state_file then
        os.remove(state_file)
    end
    os.execute("pkill -f 'pw-play.*communicator' 2>/dev/null")
    print("No Alarm")
    os.exit(0)
end

if action == "poll" then
    local state_file = arg[2]
    local sound_path = arg[3] or ""

    if not state_file then
        print("No Alarm")
        os.exit(0)
    end

    local f = io.open(state_file, "r")
    if not f then
        print("No Alarm")
        os.exit(0)
    end

    local line = f:read("*l") or ""
    f:close()

    if line == "" then
        print("No Alarm")
        os.exit(0)
    end

    local target_str, total_str, msg, ringing_str = line:match("^(%d+)|(%d+)|(.-)|(%d+)$")
    if not target_str then
        print("No Alarm")
        os.exit(0)
    end

    local target = tonumber(target_str)
    local ringing_start = tonumber(ringing_str) or 0
    local now = os.time()
    local remaining = target - now

    if remaining > 0 then
        local hours = math.floor(remaining / 3600)
        local mins = math.floor((remaining % 3600) / 60)
        local secs = remaining % 60
        if hours > 0 then
            print(string.format("%d:%02d:%02d", hours, mins, secs))
        else
            print(string.format("%02d:%02d", mins, secs))
        end
    else
        -- Alarm is due / ringing
        if ringing_start == 0 then
            -- First trigger: start audio playback and record ringing timestamp
            ringing_start = now
            local wf = io.open(state_file, "w")
            if wf then
                wf:write(string.format("%d|%s|%s|%d", target, total_str, msg, ringing_start))
                wf:close()
            end
            if sound_path ~= "" then
                os.execute(string.format("pw-play %q &", sound_path))
            end
            print("00:00 Ringing!")
        elseif (now - ringing_start) >= 3 then
            -- 3 seconds elapsed: kill audio player, clean state file, and reset
            os.execute("pkill -f 'pw-play.*communicator' 2>/dev/null")
            os.remove(state_file)
            print("No Alarm")
        else
            print("00:00 Ringing!")
        end
    end
    os.exit(0)
end
