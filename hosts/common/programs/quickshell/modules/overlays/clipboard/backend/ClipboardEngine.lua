#!/usr/bin/env lua
-- ClipboardEngine.lua: RFC-compliant JSON and execution bridge for cliphist
--
-- Recovers human-assigned watermark names from Quickshot's sidecar .json
-- files. cliphist rounds byte sizes to KiB in its display string ("71 KiB"),
-- so we cannot match on that. Instead we decode each image entry to a temp
-- PNG and stat the decoded file, whose byte count is exactly the original
-- PNG size. That exact size is then looked up in the name table.

local action = arg[1] or "list"

local function json_escape(s)
    if not s then return '""' end
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('[%z\1-\31]', function(c)
        if c == '\n' then return '\\n'
        elseif c == '\r' then return '\\r'
        elseif c == '\t' then return '\\t'
        else return string.format('\\u%04x', string.byte(c))
        end
    end)
    return '"' .. s .. '"'
end

-- Build { exact_byte_size => "assigned_name" } from Quickshot history.
-- Skips sentinel names used for unnamed screenshots so they stay as generic
-- "Screenshot" entries in the list.
local function build_name_lookup()
    local lookup = {}
    local home = os.getenv("HOME") or ""
    if home == "" then return lookup end
    local hist_dir = home .. "/.cache/quickshot_history"

    local cmd = "for f in \"" .. hist_dir .. "\"/*.png; do " ..
                "[ -f \"$f\" ] || continue; " ..
                "sz=$(stat -c%s \"$f\" 2>/dev/null) || continue; " ..
                "printf '%s|%s\\n' \"$sz\" \"$f\"; " ..
                "done"
    local h = io.popen(cmd)
    if not h then return lookup end

    -- Lexicographic filename order == chronological for Quickshot's
    -- quickshot_YYYYMMDD_HHMMSS_<name>.png scheme, so later iterations
    -- overwrite older entries on size collision — newest name wins.
    for line in h:lines() do
        local size_str, path = line:match("^(%d+)|(.+)$")
        if size_str and path then
            local json_path = path:gsub("%.png$", ".json")
            local jf = io.open(json_path, "r")
            if jf then
                local content = jf:read("*a") or ""
                jf:close()
                local name = content:match('"name"%s*:%s*"([^"]*)"')
                if name and name ~= ""
                   and name ~= "Screenshot"
                   and name ~= "REVEALED PROOF" then
                    lookup[tonumber(size_str)] = name
                end
            end
        end
    end
    h:close()
    return lookup
end

-- Decode a cliphist entry to a temp PNG (reused as the thumbnail) and
-- return its exact byte size, or nil.
local function decode_and_stat(id_str)
    local tmp = "/tmp/qs_clip_thumb_" .. id_str .. ".png"
    local f = io.open(tmp, "r")
    if not f then
        os.execute(string.format("printf '%%s\\t\\n' '%s' | cliphist decode > '%s' 2>/dev/null", id_str, tmp))
    else
        f:close()
    end

    local h = io.popen("stat -c%s '" .. tmp .. "' 2>/dev/null")
    if not h then return nil end
    local sz = tonumber((h:read("*a") or ""):match("%d+"))
    h:close()
    return sz
end

if action == "list" then
    local handle = io.popen("cliphist list 2>/dev/null")
    if not handle then
        print("[]")
        os.exit(0)
    end

    local name_lookup = nil
    local items = {}

    for line in handle:lines() do
        local tab_pos = line:find("\t")
        local id_str, rest
        if tab_pos then
            id_str = line:sub(1, tab_pos - 1):match("^%s*(%d+)%s*$")
            rest = line:sub(tab_pos + 1)
        else
            id_str, rest = line:match("^(%d+)%s+(.*)$")
        end

        if id_str and rest then
            local is_img = false
            if rest:match("^%[%[%s*binary data") or rest:match("^%[%s*binary data") then
                is_img = true
            end

            local dims = is_img and (rest:match("(%d+x%d+)") or "") or ""
            local size = is_img and (rest:match("(%d+%.?%d*%s*[KMG]?i?B)") or "") or ""
            local title = ""
            local search_text = ""
            local thumb = ""

            if is_img then
                if name_lookup == nil then
                    name_lookup = build_name_lookup()
                end

                -- Decode once; the resulting temp file is both our thumbnail
                -- and our exact-size source for the name lookup.
                local exact_size = decode_and_stat(id_str)
                local human = exact_size and name_lookup[exact_size] or nil

                if human then
                    title = human
                    search_text = human:lower() .. " screenshot image"
                else
                    title = "Screenshot" .. (dims ~= "" and (" (" .. dims .. ")") or "")
                    search_text = rest:lower()
                end

                thumb = "file:///tmp/qs_clip_thumb_" .. id_str .. ".png"
            else
                title = rest
                search_text = rest:lower()
            end

            local json_entry = string.format(
                '{"id":%s,"isImage":%s,"text":%s,"displayText":%s,"title":%s,"searchText":%s,"date":"","dims":%s,"size":%s,"thumbPath":%s}',
                json_escape(id_str),
                is_img and "true" or "false",
                json_escape(rest),
                json_escape(rest),
                json_escape(title),
                json_escape(search_text),
                json_escape(dims),
                json_escape(size),
                json_escape(thumb)
            )
            table.insert(items, json_entry)
        end
    end
    handle:close()

    print("[" .. table.concat(items, ",") .. "]")

elseif action == "preview" then
    local id = arg[2]
    if id and id ~= "" then
        os.execute(string.format("printf '%%s\\t\\n' '%s' | cliphist decode", id))
    end

elseif action == "ocr" then
    local id = arg[2]
    if id and id ~= "" then
        local tmp = "/tmp/qs_ocr_" .. id .. ".png"
        os.execute(string.format("printf '%%s\\t\\n' '%s' | cliphist decode > '%s' 2>/dev/null", id, tmp))
        os.execute(string.format("tesseract '%s' stdout 2>/dev/null || true; rm -f '%s' 2>/dev/null", tmp, tmp))
    end

elseif action == "copy" then
    local id = arg[2]
    if id and id ~= "" then
        os.execute(string.format("printf '%%s\\t\\n' '%s' | cliphist decode | wl-copy", id))
    end

elseif action == "delete" then
    local id = arg[2]
    if id and id ~= "" then
        os.execute(string.format("printf '%%s\\t\\n' '%s' | cliphist delete", id))
        os.remove("/tmp/qs_clip_thumb_" .. id .. ".png")
    end

elseif action == "wipe" then
    os.execute("cliphist wipe 2>/dev/null; rm -f /tmp/qs_clip_thumb_*.png 2>/dev/null")
end
