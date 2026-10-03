#!/usr/bin/env lua

local cmd = arg[1]

-- Action: Delete a specific item
if cmd == "--delete" then
    local target = arg[2] or ""
    local state_file = "/tmp/native_clipboard_history.txt"
    local f = io.open(state_file, "r")
    if not f then return end
    local content = f:read("*a")
    f:close()

    local out = io.open(state_file, "w")
    if not out then return end
    for b in content:gmatch("([^\0]+)") do
        local txt = b
        if b:sub(1, 5) == "##TS:" then
            local sep = b:find("|", 1, true)
            if sep then txt = b:sub(sep + 1) end
        end
        if txt:gsub("^%s*(.-)%s*$", "%1") ~= target:gsub("^%s*(.-)%s*$", "%1") then
            out:write(b .. "\0")
        end
    end
    out:close()
    os.exit(0)
end

-- Action: Load and Interleave History
local items_pool = {}

-- 1. Harvest Quickshot History images
local hist_dir = (os.getenv("HOME") or "") .. "/.cache/quickshot_history"
local p = io.popen("find " .. string.format("%q", hist_dir) .. " -maxdepth 1 -name '*.json' 2>/dev/null")
if p then
    for jfile in p:lines() do
        local img = jfile:gsub("%.json$", ".png")
        local check = io.open(img, "r")
        if check then
            check:close()
            local ts = 0
            local stat_p = io.popen("stat -c %Y " .. string.format("%q", jfile) .. " 2>/dev/null")
            if stat_p then
                local res = stat_p:read("*l")
                ts = tonumber(res) or 0
                stat_p:close()
            end
            local jf = io.open(jfile, "r")
            local name = "Screenshot"
            if jf then
                local txt = jf:read("*a")
                jf:close()
                name = txt:match('"name"%s*:%s*"([^"]+)"') or name
            end
            table.insert(items_pool, {
                ts = ts,
                data = {
                    id = img,
                    text = "[Image: " .. name .. "]",
                    searchText = name:lower(),
                    isImage = true,
                    imagePath = img,
                    fullRawText = ""
                }
            })
        end
    end
    p:close()
end

-- 2. Harvest Null-Terminated Text Blocks
local state_file = "/tmp/native_clipboard_history.txt"
local sf = io.open(state_file, "r")
if sf then
    local content = sf:read("*a")
    sf:close()
    local stat_p = io.popen("stat -c %Y " .. state_file .. " 2>/dev/null")
    local file_ts = tonumber(stat_p and stat_p:read("*l")) or os.time()
    if stat_p then stat_p:close() end

    local blocks = {}
    for b in content:gmatch("([^\0]+)") do
        local clean = b:gsub("^%s*(.-)%s*$", "%1")
        if clean ~= "" then table.insert(blocks, clean) end
    end

    local fallback_ts = 0
    for i = #blocks, 1, -1 do
        local b = blocks[i]
        local txt = b
        local ts = file_ts - fallback_ts
        fallback_ts = fallback_ts + 1

        if b:sub(1, 5) == "##TS:" then
            local sep = b:find("|", 1, true)
            if sep then
                ts = tonumber(b:sub(6, sep - 1)) or ts
                txt = b:sub(sep + 1)
            end
        end

        local first_line = txt:match("[^\r\n]+") or txt
        first_line = first_line:gsub("^%s*(.-)%s*$", "%1")
        local display_text = first_line
        if #first_line >= 55 then display_text = first_line:sub(1, 52) .. "..." end
        if txt:find("[\r\n]") then display_text = display_text .. " ↵" end

        table.insert(items_pool, {
            ts = ts,
            data = {
                id = "",
                text = display_text,
                searchText = txt:lower(),
                isImage = false,
                imagePath = "",
                fullRawText = txt
            }
        })
    end
end

-- 3. Sort Chronologically & Deduplicate
table.sort(items_pool, function(a, b) return a.ts > b.ts end)

local final_items = {}
local seen_text = {}
for _, item in ipairs(items_pool) do
    local d = item.data
    if not d.isImage then
        if not seen_text[d.fullRawText] then
            seen_text[d.fullRawText] = true
            table.insert(final_items, d)
        end
    else
        table.insert(final_items, d)
    end
end

for idx, item in ipairs(final_items) do
    if not item.isImage then item.id = tostring(#final_items - idx + 1) end
end

-- JSON Output
local function json_escape(s)
    return s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
end

local json_parts = {}
for _, it in ipairs(final_items) do
    table.insert(json_parts, string.format(
        '{"id":"%s","text":"%s","searchText":"%s","isImage":%s,"imagePath":"%s","fullRawText":"%s"}',
        json_escape(it.id), json_escape(it.text), json_escape(it.searchText),
        it.isImage and "true" or "false", json_escape(it.imagePath), json_escape(it.fullRawText)
    ))
end
io.write("[" .. table.concat(json_parts, ",") .. "]\n")
