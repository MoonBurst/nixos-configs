#!/usr/bin/env luajit
-- Fast system-health snapshot:
--   FAILED:unit1 unit2 user:unit3::ROOT:NN::BACKUP:NN

local function systemctl_failed(scope)
    local cmd = "systemctl "
    if scope == "user" then cmd = cmd .. "--user " end
    cmd = cmd .. "--failed --plain --no-legend 2>/dev/null"
    local h = io.popen(cmd)
    if not h then return {} end
    local units = {}
    for line in h:lines() do
        local u = line:match("^(%S+)")
        if u and not u:find("sync%-backup%-to%-nextcloud") then
            if scope == "user" then u = "user:" .. u end
            units[#units + 1] = u
        end
    end
    h:close()
    return units
end

local function df_percent(path)
    local h = io.popen("df --output=pcent " .. path .. " 2>/dev/null | tail -n 1")
    if not h then return 0 end
    local out = h:read("*a") or ""
    h:close()
    return tonumber(out:match("(%d+)")) or 0
end

local all = {}
for _, u in ipairs(systemctl_failed("system")) do all[#all + 1] = u end
for _, u in ipairs(systemctl_failed("user"))   do all[#all + 1] = u end

print(string.format("FAILED:%s::ROOT:%d::BACKUP:%d",
    table.concat(all, " "),
    df_percent("/"),
    df_percent("/mnt/main_backup")))
