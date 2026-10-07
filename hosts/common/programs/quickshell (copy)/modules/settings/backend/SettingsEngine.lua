#!/usr/bin/env lua

local cmd = arg[1]

local function json_esc(s)
    if not s then return "" end
    return s:gsub('\\', '\\\\')
            :gsub('"', '\\"')
            :gsub('\n', '\\n')
            :gsub('\r', '')
            :gsub('\t', '\\t')
end

local function resolve_gpu_name(dev, cid, vram_gb, vendor, device_id)
    -- 1. Direct hardware PCI Device ID matching (100% definitive)
    if vendor == "1002" then
        if device_id == "744c" then return (vram_gb >= 22) and "RX 7900 XTX" or "RX 7900 XT", "Navi 31"
        elseif device_id == "7448" then return "RX 7900 GRE", "Navi 31"
        elseif device_id == "743f" then return "RX 6400", "Navi 24"
        elseif device_id == "73ff" then return "RX 6500 XT", "Navi 24"
        elseif device_id == "73bf" then return (vram_gb >= 16) and "RX 6800 XT" or "RX 6800", "Navi 21"
        elseif device_id == "73df" or device_id == "73a5" then return "RX 6700 XT", "Navi 22"
        elseif device_id == "73e3" then return "RX 6600 XT", "Navi 23"
        end
    end

    -- 2. Query udev properties for any other GPU (Intel, NVIDIA, or unlisted AMD)
    local raw_name = ""
    local p_udev = io.popen("udevadm info -q property -p " .. string.format("%q", dev) .. " 2>/dev/null")
    if p_udev then
        local subsys, model = "", ""
        for line in p_udev:lines() do
            local s = line:match("^ID_PCI_SUBFSYS_MODEL_FROM_DATABASE=(.+)")
            local m = line:match("^ID_MODEL_FROM_DATABASE=(.+)")
            if s and s ~= "" and not s:lower():find("^device") then subsys = s end
            if m and m ~= "" then model = m end
        end
        p_udev:close()
        raw_name = (subsys ~= "") and subsys or model
    end

    -- 3. Extract the clean model designation (e.g. RTX 4090, Arc A770, RX 7800 XT)
    local clean = raw_name
    local model_token = clean:match("(R[TX]%s*%d+%s*X?T?X?)") or clean:match("(Arc%s*%a%d+)")
    if model_token then
        clean = model_token:gsub("%s+", " ")
    else
        clean = clean:gsub("^AMD%s+Radeon%s+", ""):gsub("^Radeon%s+", "")
                     :gsub("^NVIDIA%s+GeForce%s+", ""):gsub("^NVIDIA%s+", "")
                     :gsub("%b[]", ""):gsub("%b()", ""):gsub("^%s*(.-)%s*$", "%1")
        if clean:find("/") then clean = clean:match("([^/]+)") or clean end
    end

    if clean == "" then clean = cid end
    return clean, raw_name
end

-- 1. Scan GPUs
if cmd == "scan-gpus" then
    local gpus = {}
    local nv_info = {}

    local p_nv = io.popen("nvidia-smi --query-gpu=index,gpu_name,pci.bus_id --format=csv,noheader,nounits 2>/dev/null")
    if p_nv then
        for line in p_nv:lines() do
            local parts = {}
            for col in line:gmatch("[^,]+") do 
                table.insert(parts, col:gsub("^%s*(.-)%s*$", "%1")) 
            end
            if #parts >= 3 then
                local bus = parts[3]:lower()
                local bparts = {}
                for seg in bus:gmatch("[^:]+") do table.insert(bparts, seg) end
                if #bparts >= 2 then
                    local short = bparts[#bparts-1] .. ":" .. bparts[#bparts]
                    nv_info[short] = { parts[1], parts[2] }
                end
            end
        end
        p_nv:close()
    end

    local p_cards = io.popen("ls -d /sys/class/drm/card[0-9] 2>/dev/null | sort")
    if p_cards then
        for card_path in p_cards:lines() do
            local cid = card_path:match("[^/]+$")
            local dev = card_path .. "/device"
            
            local test_f = io.open(dev .. "/uevent", "r")
            if test_f then
                test_f:close()
                local vendor = ""
                local vf = io.open(dev .. "/vendor", "r")
                if vf then 
                    vendor = (vf:read("*l") or ""):gsub("0x", ""):lower():gsub("%s+", "")
                    vf:close() 
                end

                local device_id = ""
                local df = io.open(dev .. "/device", "r")
                if df then 
                    device_id = (df:read("*l") or ""):gsub("0x", ""):lower():gsub("%s+", "")
                    df:close() 
                end

                local vram_gb = 0
                local mf = io.open(dev .. "/mem_info_vram_total", "r")
                if mf then
                    local bytes = tonumber(mf:read("*l") or "0") or 0
                    mf:close()
                    vram_gb = math.floor((bytes / 1073741824) + 0.5)
                end

                local is_nv = (vendor == "10de")
                local short_name, full_name = "", ""
                local nv_idx = "0"

                if is_nv then
                    for _, info in pairs(nv_info) do 
                        nv_idx = info[1]
                        full_name = info[2]
                        short_name = full_name:gsub("^NVIDIA%s+GeForce%s+", ""):gsub("^NVIDIA%s+", "")
                        break 
                    end
                else
                    short_name, full_name = resolve_gpu_name(dev, cid, vram_gb, vendor, device_id)
                end

                local is_discrete = is_nv or (vendor == "1002" and vram_gb >= 4)

                table.insert(gpus, {
                    id = cid,
                    vendor = vendor,
                    device = device_id,
                    name = short_name,
                    fullName = full_name,
                    render = "renderD128",
                    nv_index = nv_idx,
                    vram_gb = vram_gb,
                    is_discrete = is_discrete
                })
            end
        end
        p_cards:close()
    end

    table.sort(gpus, function(a, b)
        if a.is_discrete ~= b.is_discrete then 
            return a.is_discrete == true 
        end
        return a.vram_gb > b.vram_gb
    end)

    local json_out = {}
    for _, g in ipairs(gpus) do
        table.insert(json_out, string.format(
            '{"id":"%s","vendor":"%s","device":"%s","name":"%s","fullName":"%s","render":"%s","nv_index":"%s","vram_gb":%d,"is_discrete":%s}',
            json_esc(g.id), json_esc(g.vendor), json_esc(g.device), json_esc(g.name), json_esc(g.fullName),
            json_esc(g.render), json_esc(g.nv_index), g.vram_gb, g.is_discrete and "true" or "false"
        ))
    end
    print("[" .. table.concat(json_out, ",") .. "]")
    os.exit(0)
end

-- 2. Save settings JSON atomically
if cmd == "write-settings" then
    local payload = io.read("*a")
    if (not payload or payload:match("^%s*$")) and arg[2] then
        payload = arg[2]
    end
    if payload and payload:find("^{") then
        local home = os.getenv("HOME") or ""
        local dir = home .. "/.config/quickshell"
        local f_path = dir .. "/settings.json"
        os.execute("mkdir -p " .. string.format("%q", dir))
        local tmp_path = f_path .. ".tmp"
        local f = io.open(tmp_path, "w")
        if f then
            f:write(payload)
            f:close()
            os.rename(tmp_path, f_path)
        end
    end
    os.exit(0)
end

-- 3. Save Stylix Colors
if cmd == "save-stylix" then
    local prop = arg[2] or "base05"
    local hex_val = (arg[3] or "ffffff"):gsub("#", "")
    local theme_nix = arg[4]
    local theme_qml = arg[5]

    local updated_nix = false
    if theme_nix then
        local fn = io.open(theme_nix, "r")
        if fn then
            local c = fn:read("*a")
            fn:close()
            local new_c = c:gsub("(" .. prop .. "%s*=%s*\"#?)[^\"]+(\";)", "%1" .. hex_val .. "%2")
            if new_c ~= c then
                local out = io.open(theme_nix, "w")
                if out then out:write(new_c); out:close(); updated_nix = true end
            end
        end
    end

    local updated_qml = false
    if theme_qml then
        local fq = io.open(theme_qml, "r")
        if fq then
            local c = fq:read("*a")
            fq:close()
            local new_c = c:gsub("(property%s+color%s+" .. prop .. "%s*:%s*\")[^\"]+(\")", "%1#" .. hex_val .. "%2")
            if new_c ~= c then
                local out = io.open(theme_qml, "w")
                if out then out:write(new_c); out:close(); updated_qml = true end
            end
        end
    end

    local detail = (updated_nix and updated_qml) and "Updated theme.nix and Theme.qml" or "Saved"
    os.execute(string.format("notify-send -a Settings '💾 Saved to Stylix' 'Saved %s (#%s): %s'", prop, hex_val, detail))
    os.exit(0)
end
