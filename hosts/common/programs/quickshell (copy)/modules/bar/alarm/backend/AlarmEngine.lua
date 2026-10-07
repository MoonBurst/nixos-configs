#!/usr/bin/env lua

local cmd = arg[1]

-- 1. Check if pw-play or audio player is available
if cmd == "check-player" then
    local p = io.popen("command -v pw-play 2>/dev/null || command -v paplay 2>/dev/null")
    if p then
        local out = p:read("*l")
        p:close()
        io.write((out and out ~= "") and "1\n" or "0\n")
    else
        io.write("0\n")
    end
    os.exit(0)
end

-- 2. Poll alarm state
if cmd == "poll" then
    local state_file = arg[2] or "/tmp/waybar_alarm_state"
    local sound_path = arg[3] or ""

    local f = io.open(state_file, "r")
    if not f then
        print("No Alarm")
        os.exit(0)
    end

    local line = f:read("*l") or ""
    f:close()

    local start_time, total_secs, msg = line:match("(%d+)%s+(%d+)%s+(.+)")
    start_time = tonumber(start_time)
    total_secs = tonumber(total_secs)

    if not start_time or not total_secs then
        print("No Alarm")
        os.remove(state_file)
        os.exit(0)
    end

    local now = os.time()
    local elapsed = now - start_time
    local remaining = total_secs - elapsed

    if remaining <= 0 then
        -- Alarm finished: trigger notification and playback
        local clean_msg = (msg or "Alarm Finished!"):gsub('"', '')
        os.execute(string.format('notify-send -t 10000 -u critical "Alarm Alert" %q', clean_msg))

        local snd = sound_path
        local test_snd = io.open(snd, "r")
        if not test_snd then
            local home = os.getenv("HOME") or ""
            local fallbacks = {
                home .. "/Documents/communicator.mp3",
                home .. "/Music/communicator.mp3"
            }
            for _, fb in ipairs(fallbacks) do
                local check = io.open(fb, "r")
                if check then check:close(); snd = fb; break end
            end
        else
            test_snd:close()
        end

        local play_cmd = string.format('(timeout -k 0.5s 3s pw-play --volume 0.5 %q 2>/dev/null || timeout 3s paplay %q 2>/dev/null || timeout 3s speaker-test -t sine -f 800 2>/dev/null) &', snd, snd)
        os.execute(play_cmd)
        os.remove(state_file)
        print("No Alarm")
    else
        local h = math.floor(remaining / 3600)
        local m = math.floor((remaining % 3600) / 60)
        local s = remaining % 60
        print(string.format("%02dh %02dm %02ds", h, m, s))
    end
    os.exit(0)
end

-- 3. Save alarm state
if cmd == "save" then
    local state_file = arg[2]
    local start_time = arg[3] or tostring(os.time())
    local total_secs = arg[4] or "0"
    local msg = arg[5] or "Alarm Finished!"

    if state_file then
        local f = io.open(state_file, "w")
        if f then
            f:write(string.format('%s %s "%s"\n', start_time, total_secs, msg))
            f:close()
        end
    end
    os.exit(0)
end

-- 4. Cancel alarm
if cmd == "cancel" then
    local state_file = arg[2]
    if state_file then os.remove(state_file) end
    os.execute("pkill -f 'communicator.mp3' 2>/dev/null")
    os.exit(0)
end
