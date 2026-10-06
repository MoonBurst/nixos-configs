#!/usr/bin/env lua
-- Clean audio sink switcher: cycles to the next available output sink
local handle = io.popen("wpctl status 2>/dev/null")
if not handle then return end
local content = handle:read("*a")
handle:close()

local in_sinks = false
local sinks = {}
local current_sink = nil

for line in content:gmatch("[^\r\n]+") do
    if line:find("Sinks:") then
        in_sinks = true
    elseif line:find("Sources:") or line:find("Filters:") or line:find("Streams:") then
        in_sinks = false
    elseif in_sinks then
        local is_default = line:find("%*") ~= nil
        local id = line:match("(%d+)%.")
        if id then
            table.insert(sinks, id)
            if is_default then current_sink = id end
        end
    end
end

if #sinks > 1 then
    local next_id = sinks[1]
    for i, id in ipairs(sinks) do
        if id == current_sink and i < #sinks then
            next_id = sinks[i + 1]
            break
        end
    end
    os.execute("wpctl set-default " .. next_id)
end
