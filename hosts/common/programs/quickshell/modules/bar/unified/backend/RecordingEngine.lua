#!/usr/bin/env luajit
-- RecordingEngine.lua — detect active screen recording and Twitch streaming.
--
-- Reads pid files from $XDG_RUNTIME_DIR and falls back to scanning
-- /proc/*/cmdline for the process names, so no external tools are forked on
-- each poll. Prints "REC STREAM" as two space-separated 0/1 flags, matching
-- the interface the QML side used to receive from the previous bash -c
-- invocation.

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function pid_alive(pid)
    if not pid or pid == "" then return false end
    local p = tonumber(pid)
    if not p or p <= 0 then return false end
    -- On Linux, /proc/<pid> existing and being a directory means the process
    -- is alive. This is cheaper than signalling.
    local f = io.open("/proc/" .. p, "r")
    if f then f:close(); return true end
    return false
end

local function read_pidfile(path)
    local s = read_file(path)
    if not s then return nil end
    local pid = s:match("^%s*(%d+)")
    return pid
end

local function any_proc_matches(needle)
    -- needle is a plain substring matched against each process's argv.
    -- Reads /proc/<pid>/cmdline (NUL-separated) and joins with spaces so a
    -- partial match against "wf-recorder --output …" works.
    local p = io.popen("ls /proc 2>/dev/null")
    if not p then return false end
    for entry in p:lines() do
        local pid = tonumber(entry)
        if pid then
            local cmd = read_file("/proc/" .. pid .. "/cmdline")
            if cmd then
                local joined = cmd:gsub("%z", " ")
                if joined:find(needle, 1, true) then
                    p:close()
                    return true
                end
            end
        end
    end
    p:close()
    return false
end

local runtime = os.getenv("XDG_RUNTIME_DIR") or "/tmp"

-- 1) Recording: pid file first, then process scan
local rec = 0
if pid_alive(read_pidfile(runtime .. "/record-region.pid")) then
    rec = 1
elseif any_proc_matches("wf-recorder") then
    rec = 1
end

-- 2) Streaming: pid file first, then process scan
local stream = 0
if pid_alive(read_pidfile(runtime .. "/twitch-stream.pid")) then
    stream = 1
elseif any_proc_matches("rtmp://live.twitch.tv") then
    stream = 1
end

io.write(rec .. " " .. stream .. "\n")
