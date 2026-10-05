#!/usr/bin/env lua
-- ClipboardEngine.lua: RFC-compliant JSON and execution bridge for cliphist

local action = arg[1] or "list"

local function json_escape(s)
    if not s then return '""' end
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    -- Strict escape for all ASCII control characters (0x00 to 0x1F) so JSON.parse never crashes
    s = s:gsub('[%z\1-\31]', function(c)
        if c == '\n' then return '\\n'
        elseif c == '\r' then return '\\r'
        elseif c == '\t' then return '\\t'
        else return string.format('\\u%04x', string.byte(c))
        end
    end)
    return '"' .. s .. '"'
end

if action == "list" then
    local handle = io.popen("cliphist list 2>/dev/null")
    if not handle then
        print("[]")
        os.exit(0)
    end

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
            -- Only categorize as image if it strictly starts with cliphist's binary signature
            if rest:match("^%[%[%s*binary data") or rest:match("^%[%s*binary data") then
                is_img = true
            end

            local dims = is_img and (rest:match("(%d+x%d+)") or "") or ""
            local size = is_img and (rest:match("(%d+%.?%d*%s*[KMG]?i?B)") or "") or ""
            local title = is_img and ("Screenshot" .. (dims ~= "" and (" (" .. dims .. ")") or "")) or rest

            local thumb = ""
            if is_img then
                thumb = "/tmp/qs_clip_thumb_" .. id_str .. ".png"
                local f = io.open(thumb, "r")
                if f then
                    f:close()
                else
                    os.execute(string.format("printf '%%s\\t\\n' '%s' | cliphist decode > '%s' 2>/dev/null", id_str, thumb))
                end
                thumb = "file://" .. thumb
            end

            local json_entry = string.format(
                '{"id":%s,"isImage":%s,"text":%s,"displayText":%s,"title":%s,"searchText":%s,"date":"","dims":%s,"size":%s,"thumbPath":%s}',
                json_escape(id_str),
                is_img and "true" or "false",
                json_escape(rest),
                json_escape(rest),
                json_escape(title),
                json_escape(rest:lower()),
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
