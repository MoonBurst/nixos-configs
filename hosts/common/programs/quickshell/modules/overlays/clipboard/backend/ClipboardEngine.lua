#!/usr/bin/env lua
-- modules/overlays/clipboard/backend/ClipboardEngine.lua
-- High-performance cliphist & wl-clipboard backend for Quickshell

local action = arg[1] or "list"
local target_id = arg[2]

local path_prefix = 'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"; '

local function run_cmd(cmd)
    local p = io.popen(path_prefix .. cmd)
    if not p then return "" end
    local out = p:read("*a") or ""
    p:close()
    return out
end

local function escape_json(s)
    if not s then return '""' end
    local escapes = {
        ['\\'] = '\\\\',
        ['"']  = '\\"',
        ['\b'] = '\\b',
        ['\f'] = '\\f',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\t'] = '\\t'
    }
    return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
        return escapes[c] or string.format('\\u%04x', c:byte())
    end) .. '"'
end

local function format_bytes(bytes)
    if not bytes or bytes <= 0 then return "" end
    if bytes >= 1048576 then
        return string.format("%.1f MB", bytes / 1048576)
    elseif bytes >= 1024 then
        return string.format("%.0f KB", bytes / 1024)
    else
        return string.format("%d B", bytes)
    end
end

-- Reads binary PNG header directly to obtain dimensions in <0.01ms
local function get_png_dimensions(path)
    local f = io.open(path, "rb")
    if not f then return nil, nil end
    local header = f:read(24)
    f:close()
    if header and #header >= 24 and header:sub(1, 4) == "\137PNG" then
        local w = header:byte(17) * 16777216 + header:byte(18) * 65536 + header:byte(19) * 256 + header:byte(20)
        local h = header:byte(21) * 16777216 + header:byte(22) * 65536 + header:byte(23) * 256 + header:byte(24)
        return w, h
    end
    return nil, nil
end

local function decode_image(id_num, dest_path)
    local existing = io.open(dest_path, "rb")
    if existing then
        local sz = existing:seek("end")
        existing:close()
        if sz and sz > 0 then return true end
    end

    -- Universal invocation: piped via stdin with tab delimiter so it never deadlocks
    local cmd = string.format("%sprintf '%%s\\t\\n' %s | cliphist decode > %q 2>/dev/null", path_prefix, id_num, dest_path)
    os.execute(cmd)

    local f = io.open(dest_path, "rb")
    if not f then return false end
    local sz = f:seek("end") or 0
    f:seek("set", 0)
    local header = f:read(8) or ""
    f:close()

    if sz == 0 then
        os.remove(dest_path)
        return false
    end

    local is_valid = header:sub(1, 4) == "\137PNG"
                  or header:sub(1, 3) == "\255\216\255"
                  or header:sub(1, 4) == "GIF8"
                  or header:sub(1, 4) == "RIFF"
                  or header:sub(1, 2) == "BM"

    if not is_valid then
        os.remove(dest_path)
        return false
    end
    return true
end

-- Index recent Quickshot files for screenshot name & watermark tag matching
local function load_screenshot_index()
    local index = {}
    local home_dir = os.getenv("HOME") or "/tmp"
    local hist_dir = home_dir .. "/.cache/quickshot_history"
    local meta_list = run_cmd(string.format("ls -1t %q/*.json 2>/dev/null | head -n 40", hist_dir))

    for json_file in meta_list:gmatch("[^\r\n]+") do
        local f = io.open(json_file, "r")
        if f then
            local data = f:read("*a") or ""
            f:close()
            local name = data:match('"name"%s*:%s*"([^"]+)"')
            local img_path = data:match('"path"%s*:%s*"([^"]+)"')
            local ts = json_file:match("quickshot_(%d%d%d%d%d%d%d%d_%d%d%d%d%d%d)")

            if img_path then
                local inf = io.open(img_path, "rb")
                if inf then
                    local sz = inf:seek("end")
                    inf:close()
                    if sz and sz > 0 then
                        index[sz] = {
                            name = name or "Screenshot",
                            timestamp = ts
                        }
                    end
                end
            end
        end
    end
    return index
end

-- ============================================================================
-- COMMAND ROUTING
-- ============================================================================

if action == "list" then
    if run_cmd("command -v cliphist") == "" then
        io.stderr:write("cliphist binary not found in PATH\n")
        print("[]")
        return
    end

    local raw_list = run_cmd("cliphist list 2>/dev/null")
    if not raw_list or #raw_list == 0 then
        io.stderr:write("cliphist database is currently empty\n")
        print("[]")
        return
    end

    local shot_index = load_screenshot_index()
    local entries = {}
    local max_items = 120
    local count = 0

    for line in raw_list:gmatch("[^\r\n]+") do
        count = count + 1
        if count > max_items then break end

        -- Capture ID (digits) and preview payload
        local raw_id, raw_prev = line:match("^(%d+)%s+(.*)$")
        if not raw_id then
            raw_id = line:match("^(%d+)")
            if raw_id then
                raw_prev = line:sub(#raw_id + 1):gsub("^%s+", "")
            end
        end

        local clip_id = raw_id and raw_id:match("(%d+)")

        if clip_id and raw_prev then
            raw_prev = raw_prev:gsub("^%s+", ""):gsub("%s+$", "")

            local is_img = raw_prev:match("^%[%[%s*binary%s+data") ~= nil
                        or raw_prev:match("^image/") ~= nil
                        or raw_prev:match("%.png") ~= nil
                        or raw_prev:match("%.jpg") ~= nil

            local img_path = "/tmp/qs-cliphist-preview-" .. clip_id .. ".png"
            local is_decoded = false

            if is_img then
                is_decoded = decode_image(clip_id, img_path)
            end

            if is_img and is_decoded then
                local f = io.open(img_path, "rb")
                local f_size = f and f:seek("end") or 0
                if f then f:close() end

                local w, h = get_png_dimensions(img_path)
                local dim_str = (w and h) and string.format("%d×%d", w, h) or (raw_prev:match("(%d+x%d+)") or "Image")
                local size_str = format_bytes(f_size)

                local matched_meta = shot_index[f_size]
                local title_name = "Screenshot"
                local date_display = ""

                if matched_meta then
                    if matched_meta.name and matched_meta.name ~= "" and matched_meta.name ~= "clean" and matched_meta.name ~= "Screenshot" then
                        title_name = "Shot (" .. matched_meta.name .. ")"
                    end
                    if matched_meta.timestamp then
                        local y, m, d, hh, mm = matched_meta.timestamp:match("(%d%d%d%d)(%d%d)(%d%d)_(%d%d)(%d%d)")
                        if y and m and d and hh and mm then
                            date_display = string.format("%s-%s-%s %s:%s", y, m, d, hh, mm)
                        end
                    end
                end

                if date_display == "" then
                    local f_attr = io.open(img_path, "r")
                    if f_attr then
                        f_attr:close()
                        date_display = os.date("%Y-%m-%d %H:%M")
                    end
                end

                local primary_label = string.format("📸 %s • %s [%s]",
                    title_name,
                    date_display,
                    dim_str .. (size_str ~= "" and (" • " .. size_str) or "")
                )

                local search_kw = string.format("image screenshot %s %s %s %s",
                    title_name:lower(),
                    date_display,
                    dim_str,
                    size_str
                )

                table.insert(entries, string.format(
                    '{"id":%q,"text":%s,"searchText":%s,"isImage":true,"title":%s,"date":%s,"dims":%s,"size":%s,"thumbPath":%q}',
                    clip_id,
                    escape_json(primary_label),
                    escape_json(search_kw),
                    escape_json(title_name),
                    escape_json(date_display),
                    escape_json(dim_str),
                    escape_json(size_str),
                    "file://" .. img_path
                ))
            else
                local clean_text = raw_prev:gsub("[\r\n\t]+", " "):gsub("%s+", " ")
                if #clean_text > 120 then
                    clean_text = clean_text:sub(1, 117) .. "..."
                end

                local date_display = os.date("%Y-%m-%d %H:%M")

                table.insert(entries, string.format(
                    '{"id":%q,"text":%s,"searchText":%s,"isImage":false,"title":%s,"date":%s,"dims":"","size":"","thumbPath":""}',
                    clip_id,
                    escape_json(clean_text),
                    escape_json(clean_text:lower()),
                    escape_json("Text"),
                    escape_json(date_display)
                ))
            end
        end
    end

    print("[" .. table.concat(entries, ",") .. "]")

elseif action == "preview" and target_id then
    local id_num = target_id:match("(%d+)")
    if id_num then
        local cmd = string.format("%sprintf '%%s\\t\\n' %s | cliphist decode 2>/dev/null", path_prefix, id_num)
        local content = run_cmd(cmd)
        io.write(content)
    end

elseif action == "copy" and target_id then
    local id_num = target_id:match("(%d+)")
    if id_num then
        local img_path = "/tmp/qs-cliphist-preview-" .. id_num .. ".png"
        local f = io.open(img_path, "rb")
        if f then
            f:close()
            os.execute(string.format('%swl-copy --type image/png < %q', path_prefix, img_path))
        else
            os.execute(string.format('%sprintf \'%%s\\t\\n\' %s | cliphist decode | wl-copy', path_prefix, id_num))
        end
    end

elseif action == "delete" and target_id then
    local id_num = target_id:match("(%d+)")
    if id_num then
        os.execute(string.format("%sprintf '%%s\\t\\n' %s | cliphist delete 2>/dev/null", path_prefix, id_num))
        os.remove("/tmp/qs-cliphist-preview-" .. id_num .. ".png")
    end

elseif action == "wipe" then
    os.execute(path_prefix .. "cliphist wipe 2>/dev/null")
    os.execute("rm -f /tmp/qs-cliphist-preview-*.png 2>/dev/null")
end
