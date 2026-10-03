#!/usr/bin/env lua

local cmd = arg[1]

-- 1. Query Real-Time GPU Telemetry Stats (Telemetry poller)
if cmd == "stats" then
    local card_id = arg[2] or "card0"
    local vendor = arg[3] or ""
    local is_nv = (arg[4] == "1") or (vendor == "10de")
    local nv_idx = arg[5] or "0"

    if is_nv then
        local p = io.popen(string.format("nvidia-smi -i %s --query-gpu=utilization.gpu,temperature.gpu,power.draw,memory.free --format=csv,noheader,nounits 2>/dev/null", nv_idx))
        if p then
            local out = p:read("*l")
            p:close()
            if out and out ~= "" then
                local parts = {}
                for c in out:gmatch("[^,]+") do table.insert(parts, c:gsub("^%s*(.-)%s*$", "%1")) end
                if #parts >= 4 then
                    local u = math.floor(tonumber(parts[1]) or 0)
                    local t = math.floor(tonumber(parts[2]) or 0)
                    local pwr = math.floor(tonumber(parts[3]) or 0)
                    local vram = math.floor((tonumber(parts[4]) or 0) / 1024)
                    print(string.format("%d:%d:%d:%d", u, t, pwr, vram))
                    os.exit(0)
                end
            end
        end
    end

    local dev_path = "/sys/class/drm/" .. card_id .. "/device"
    local check = io.open(dev_path .. "/uevent", "r")
    if not check then
        print("0:0:0:0")
        os.exit(0)
    end
    check:close()

    local usage = 0
    local uf = io.open(dev_path .. "/gpu_busy_percent", "r")
    if uf then usage = tonumber(uf:read("*l"):match("%d+")) or 0; uf:close() end

    local temp = 0
    local p_temp = io.popen("cat " .. dev_path .. "/hwmon/hwmon*/temp*_input 2>/dev/null | head -n 1")
    if p_temp then
        local raw_t = tonumber(p_temp:read("*l")) or 0
        temp = math.floor(raw_t / 1000)
        p_temp:close()
    end

    local power = 0
    local p_pwr = io.popen("cat " .. dev_path .. "/hwmon/hwmon*/power1_* 2>/dev/null | head -n 1")
    if p_pwr then
        local raw_p = tonumber(p_pwr:read("*l")) or 0
        power = math.floor(raw_p / 1000000)
        p_pwr:close()
    end

    local total = 0
    local used = 0
    local tf = io.open(dev_path .. "/mem_info_vram_total", "r")
    if tf then total = tonumber(tf:read("*l")) or 0; tf:close() end
    local utf = io.open(dev_path .. "/mem_info_vram_used", "r")
    if utf then used = tonumber(utf:read("*l")) or 0; utf:close() end

    if total == 0 then
        local gtf = io.open(dev_path .. "/mem_info_gtt_total", "r")
        if gtf then total = tonumber(gtf:read("*l")) or 0; gtf:close() end
        local gutf = io.open(dev_path .. "/mem_info_gtt_used", "r")
        if gutf then used = tonumber(gutf:read("*l")) or 0; gutf:close() end
    end

    local free_vram = 0
    if total > used then
        free_vram = math.floor((total - used) / 1073741824)
    end

    print(string.format("%d:%d:%d:%d", usage, temp, power, free_vram))
    os.exit(0)
end

-- 2. Query Active GPU Clients (Processes)
local card_id = arg[1] or "card0"
local vendor = arg[2] or ""
local is_nv = (arg[3] == "1") or (vendor == "10de")
local nv_idx = arg[4] or "0"

local results = {}

-- NVIDIA Client Scraper
if is_nv then
    local cmd_str = string.format("nvidia-smi -i %s --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits 2>/dev/null; " ..
                                  "nvidia-smi -i %s --query-graphics-apps=pid,process_name,used_memory --format=csv,noheader,nounits 2>/dev/null", nv_idx, nv_idx)
    local p = io.popen(cmd_str)
    if p then
        local seen = {}
        for line in p:lines() do
            local parts = {}
            for col in line:gmatch("[^,]+") do table.insert(parts, col:gsub("^%s*(.-)%s*$", "%1")) end
            if #parts >= 3 and not seen[parts[1]] then
                seen[parts[1]] = true
                local pid = parts[1]
                local name = parts[2]:match("[^/\\]+$") or parts[2]
                local mib = tonumber(parts[3]) or 0
                local vstr = (mib >= 1024) and string.format("%3.1fG", mib/1024) or string.format("%3dM", mib)
                table.insert(results, { mib = mib, line = string.format("%s|%-12.12s %5s    -  ", pid, name, vstr) })
            end
        end
        p:close()
    end
end

-- AMD / Intel DRM Client Scraper
if #results == 0 then
    -- Identify all DRM nodes associated with this card (e.g. card1, renderD129)
    local drm_nodes = { [card_id] = true }
    local p_drm = io.popen("ls /sys/class/drm/" .. card_id .. "/device/drm 2>/dev/null")
    if p_drm then
        for n in p_drm:lines() do drm_nodes[n] = true end
        p_drm:close()
    end

    -- Build a single fast find filter pattern
    local match_clauses = {}
    for node, _ in pairs(drm_nodes) do
        table.insert(match_clauses, string.format("-lname %q", "*" .. node .. "*"))
    end
    local find_cmd = "find /proc/[0-9]*/fd/ -maxdepth 1 " .. table.concat(match_clauses, " -o ") .. " 2>/dev/null"

    local function get_clients_snapshot()
        local clients = {}
        local p = io.popen(find_cmd)
        if not p then return clients end

        for line in p:lines() do
            local pid, fd = line:match("/proc/(%d+)/fd/(%d+)")
            if pid and fd then
                if not clients[pid] then
                    clients[pid] = { engine = 0, vram = 0, fds = {} }
                end
                table.insert(clients[pid].fds, fd)
            end
        end
        p:close()

        -- Read fdinfo directly in Lua for matched file descriptors
        for pid, info in pairs(clients) do
            for _, fd in ipairs(info.fds) do
                local f = io.open("/proc/" .. pid .. "/fdinfo/" .. fd, "r")
                if f then
                    for l in f:lines() do
                        if l:sub(1,15) == "drm-engine-gfx:" or l:sub(1,19) == "drm-engine-compute:" then
                            local ns = tonumber(l:match("%d+")) or 0
                            info.engine = info.engine + ns
                        elseif l:sub(1,15) == "drm-total-vram:" or l:sub(1,18) == "drm-resident-vram:" or l:sub(1,16) == "drm-memory-vram:" then
                            local bytes = tonumber(l:match("%d+")) or 0
                            if l:find("KiB") then bytes = bytes * 1024 end
                            if bytes > info.vram then info.vram = bytes end
                        end
                    end
                    f:close()
                end
            end
        end
        return clients
    end

    -- Two lightweight passes 100ms apart to calculate accurate GFX% deltas
    local snap1 = get_clients_snapshot()
    os.execute("sleep 0.1")
    local snap2 = get_clients_snapshot()

    for pid, c2 in pairs(snap2) do
        local c1 = snap1[pid] or { engine = c2.engine, vram = c2.vram }
        local diff = math.max(0, c2.engine - c1.engine)
        local pct = (diff / 100000000.0) * 100.0
        local mib = math.floor(c2.vram / (1024 * 1024))

        if mib > 0 or pct >= 0.1 then
            local comm = "unknown"
            local cf = io.open("/proc/" .. pid .. "/comm", "r")
            if cf then 
                comm = (cf:read("*l") or comm):gsub("^%.", ""):gsub("%-wrapped$", "")
                cf:close() 
            end

            local vstr = (mib >= 1024) and string.format("%3.1fG", mib/1024) or string.format("%3dM", mib)
            table.insert(results, { 
                mib = mib, 
                pct = pct,
                line = string.format("%s|%-12.12s %5s %4.1f%%", pid, comm, vstr, pct) 
            })
        end
    end
end

-- Sort: prioritize active GPU consumers, then VRAM footprint
table.sort(results, function(a, b) 
    if math.abs(a.pct - b.pct) > 1.0 then
        return a.pct > b.pct
    end
    return a.mib > b.mib 
end)

if #results == 0 then
    print("No active clients on this GPU")
else
    for i = 1, math.min(10, #results) do
        print(results[i].line)
    end
end
