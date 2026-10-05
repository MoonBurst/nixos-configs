#!/usr/bin/env luajit
-- escwatcher.lua — watch every keyboard input device for the ESC key.
-- Emits a single line "ESC" on each key-down. Uses poll(2) via LuaJIT FFI so
-- one process multiplexes every device without blocking on any single fd.

local ffi = require("ffi")
local bit = require("bit")

ffi.cdef[[
    struct input_event {
        long tv_sec;
        long tv_usec;
        unsigned short type;
        unsigned short code;
        int value;
    };
    struct pollfd {
        int fd;
        short events;
        short revents;
    };
    int open(const char *pathname, int flags);
    int close(int fd);
    long read(int fd, void *buf, unsigned long count);
    int poll(struct pollfd *fds, unsigned long nfds, int timeout);
]]

local O_RDONLY = 0
local POLLIN   = 0x001
local EV_KEY   = 1
local KEY_ESC  = 1
local EVENT_SZ = ffi.sizeof("struct input_event")

local function list_glob(pattern)
    local out = {}
    local p = io.popen("ls " .. pattern .. " 2>/dev/null")
    if not p then return out end
    for line in p:lines() do
        if line ~= "" then out[#out + 1] = line end
    end
    p:close()
    return out
end

-- Prefer the by-id symlinks (keyboards only); fall back to every event node.
local paths = list_glob("/dev/input/by-id/*-event-kbd")
if #paths == 0 then paths = list_glob("/dev/input/event*") end
if #paths == 0 then
    io.stderr:write("escwatcher: no input devices found\n")
    os.exit(0)
end

local pollfds = ffi.new("struct pollfd[?]", #paths)
local nfds = 0
for _, path in ipairs(paths) do
    local fd = ffi.C.open(path, O_RDONLY)
    if fd >= 0 then
        pollfds[nfds].fd = fd
        pollfds[nfds].events = POLLIN
        pollfds[nfds].revents = 0
        nfds = nfds + 1
    end
end

if nfds == 0 then
    io.stderr:write("escwatcher: could not open any input device\n")
    os.exit(0)
end

local buf = ffi.new("struct input_event[1]")

while true do
    local ready = ffi.C.poll(pollfds, nfds, -1)
    if ready < 0 then break end
    for i = 0, nfds - 1 do
        if bit.band(pollfds[i].revents, POLLIN) ~= 0 then
            while ffi.C.read(pollfds[i].fd, buf, EVENT_SZ) == EVENT_SZ do
                if buf[0].type == EV_KEY and buf[0].code == KEY_ESC and buf[0].value == 1 then
                    io.write("ESC\n")
                    io.flush()
                end
            end
        end
    end
end

for i = 0, nfds - 1 do ffi.C.close(pollfds[i].fd) end
