#!/usr/bin/env lua

-- 1. Read MemTotal from /proc/meminfo
local total_mem_mb = 0
local mf = io.open("/proc/meminfo", "r")
if mf then
    for line in mf:lines() do
        local kb = line:match("^MemTotal:%s*(%d+)")
        if kb then total_mem_mb = (tonumber(kb) or 0) / 1024; break end
    end
    mf:close()
end

-- 2. Fetch processes sorted by memory
local p_ps = io.popen("ps -eo pid,comm,%mem --sort=-%mem 2>/dev/null")
if p_ps then
    local count = 0
    local first = true
    for line in p_ps:lines() do
        if first then
            first = false
        else
            local pid, comm, pct = line:match("^%s*(%d+)%s+(%S+)%s+([%d%.]+)")
            if pid and comm and pct then
                local pct_num = tonumber(pct) or 0
                local mem_mb = (pct_num / 100.0) * total_mem_mb
                if mem_mb > 0 then
                    local is_raw = 1
                    local sf = io.open("/proc/" .. pid .. "/status", "r")
                    if sf then
                        for sline in sf:lines() do
                            local sw = sline:match("^VmSwap:%s*(%d+)")
                            if sw and (tonumber(sw) or 0) > 0 then is_raw = 0; break end
                        end
                        sf:close()
                    end

                    local size_str = (mem_mb >= 1024) and string.format("%.1fG", mem_mb / 1024) or string.format("%dM", math.floor(mem_mb))
                    print(string.format("%s|%d|%-10.10s %5s %4.1f%%", pid, is_raw, comm, size_str, pct_num))
                    count = count + 1
                    if count >= 10 then break end
                end
            end
        end
    end
    p_ps:close()
end
