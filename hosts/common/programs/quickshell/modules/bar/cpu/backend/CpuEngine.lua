#!/usr/bin/env lua

local cmd = arg[1]

-- 1. Discover CPU hwmon sensor path
if cmd == "find-hwmon" then
    local p = io.popen("ls -d /sys/class/hwmon/hwmon* 2>/dev/null")
    if p then
        for h in p:lines() do
            local nf = io.open(h .. "/name", "r")
            if nf then
                local name = (nf:read("*l") or ""):gsub("%s+", "")
                nf:close()
                if name == "k10temp" or name == "coretemp" or name == "zenpower" then
                    local p_temp = io.popen("ls " .. h .. "/temp*_input 2>/dev/null | head -n 1")
                    if p_temp then
                        local f = p_temp:read("*l")
                        p_temp:close()
                        if f and f ~= "" then
                            print(f)
                            os.exit(0)
                        end
                    end
                end
            end
        end
        p:close()
    end
    print("/sys/class/thermal/thermal_zone0/temp")
    os.exit(0)
end

-- 2. Fetch Top CPU Processes (Replaces ncpu/ps/awk shell script)
if cmd == "top-procs" then
    local ncpu = 1
    local p_ncpu = io.popen("nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null")
    if p_ncpu then ncpu = tonumber(p_ncpu:read("*l")) or 1; p_ncpu:close() end

    local p_ps = io.popen("ps -eo pid,comm,%cpu --sort=-%cpu 2>/dev/null | head -n 12")
    if p_ps then
        local first = true
        for line in p_ps:lines() do
            if first then
                first = false
            else
                local pid, comm, cpu = line:match("^%s*(%d+)%s+(%S+)%s+([%d%.]+)")
                if pid and comm and cpu then
                    local cpu_val = (tonumber(cpu) or 0) / ncpu
                    print(string.format("%s|%-10.10s %4.1f%%", pid, comm, cpu_val))
                end
            end
        end
        p_ps:close()
    end
    os.exit(0)
end
