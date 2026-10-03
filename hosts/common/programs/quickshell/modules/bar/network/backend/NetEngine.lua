#!/usr/bin/env lua

local cmd = arg[1]

-- 1. Gather network statistics and interface information
if cmd == "stats" then
    local target = ""

    local p_route = io.popen("ip -4 route show default 2>/dev/null")
    if p_route then
        local line = p_route:read("*l") or ""
        target = line:match("default%s+via%s+%S+%s+dev%s+(%S+)") or ""
        p_route:close()
    end

    if target == "" then
        local rf = io.open("/proc/net/route", "r")
        if rf then
            for rline in rf:lines() do
                local iface, dest = rline:match("^(%S+)%s+(%S+)")
                if dest == "00000000" then target = iface; break end
            end
            rf:close()
        end
    end

    if target == "" then
        local p_devs = io.popen("ls -d /sys/class/net/*/device 2>/dev/null")
        if p_devs then
            for d in p_devs:lines() do
                local iface = d:match("/sys/class/net/([^/]+)/device")
                if iface then
                    local op = io.open("/sys/class/net/" .. iface .. "/operstate", "r")
                    if op then
                        local st = op:read("*l") or ""
                        op:close()
                        if st == "up" then target = iface; break end
                    end
                end
            end
            p_devs:close()
        end
    end

    if target == "" then
        print("0:0:unknown:unknown:none:none")
        os.exit(0)
    end

    local rx = 0
    local rxf = io.open("/sys/class/net/" .. target .. "/statistics/rx_bytes", "r")
    if rxf then rx = tonumber(rxf:read("*l")) or 0; rxf:close() end

    local tx = 0
    local txf = io.open("/sys/class/net/" .. target .. "/statistics/tx_bytes", "r")
    if txf then tx = tonumber(txf:read("*l")) or 0; txf:close() end

    local ip = ""
    local p_ip = io.popen("ip -4 addr show " .. target .. " 2>/dev/null")
    if p_ip then
        for l in p_ip:lines() do
            local matched = l:match("inet%s+([%d%.]+)")
            if matched then ip = matched; break end
        end
        p_ip:close()
    end
    if ip == "" then ip = "none" end

    local speed = ""
    local sf = io.open("/sys/class/net/" .. target .. "/speed", "r")
    if sf then speed = sf:read("*l") or ""; sf:close() end
    if speed == "" then speed = "none" end

    local is_wifi = "Ethernet"
    local wf1 = io.open("/sys/class/net/" .. target .. "/wireless", "r")
    local wf2 = io.open("/sys/class/net/" .. target .. "/phy80211", "r")
    if wf1 then wf1:close(); is_wifi = "Wi-Fi" end
    if wf2 then wf2:close(); is_wifi = "Wi-Fi" end

    print(string.format("%d:%d:%s:%s:%s:%s", rx, tx, target, is_wifi, ip, speed))
    os.exit(0)
end

-- 2. Ping Measurement
if cmd == "ping" then
    local host = "1.1.1.1"
    local p_gw = io.popen("ip route show default 2>/dev/null")
    if p_gw then
        local line = p_gw:read("*l") or ""
        local gw = line:match("default%s+via%s+([%d%.]+)")
        if gw and gw ~= "" then host = gw end
        p_gw:close()
    end

    local p_ping = io.popen(string.format("timeout 1.5s ping -c 1 -W 1 %q 2>/dev/null", host))
    if p_ping then
        local out = p_ping:read("*a") or ""
        p_ping:close()
        local ms = out:match("time=([%d%.]+)%s*ms")
        if ms then
            print(string.format("OK:%s", ms))
            os.exit(0)
        end
    end
    print("ERR:OFFLINE")
    os.exit(1)
end
