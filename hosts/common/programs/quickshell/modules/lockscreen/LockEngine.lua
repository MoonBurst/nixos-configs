-- modules/lockscreen/backend/LockEngine.lua
local primary = arg[1] or ""
local action  = arg[2] or "on" -- "on" or "off"

local function exec(cmd)
local p = io.popen(cmd)
if not p then return "" end
    local out = p:read("*a")
    p:close()
    return out or ""
    end

    local function run_cmd(cmd)
    os.execute(cmd .. " >/dev/null 2>&1")
    end

    local is_hyprland = os.getenv("HYPRLAND_INSTANCE_SIGNATURE") ~= nil
    local is_sway     = os.getenv("SWAYSOCK") ~= nil

    -- Turn everything back on
    if action == "on" then
        if is_hyprland then
            run_cmd("hyprctl dispatch dpms on")
            elseif is_sway then
                run_cmd("swaymsg output '*' dpms on")
                else
                    run_cmd("wlopm --on '*'")
                    end
                    return
                    end

                    -- Turn off secondary displays (keeping primary on)
                    if action == "off" and primary ~= "" then
                        local secondaries = {}

                        if is_hyprland then
                            local raw = exec("hyprctl monitors 2>/dev/null")
                            for name in raw:gmatch("Monitor%s+([%w%-%_]+)") do
                                if name ~= primary then
                                    table.insert(secondaries, name)
                                    end
                                    end
                                    for _, name in ipairs(secondaries) do
                                        run_cmd("hyprctl dispatch dpms off " .. name)
                                        end
                                        elseif is_sway then
                                            local raw = exec("swaymsg -t get_outputs 2>/dev/null")
                                            for name in raw:gmatch('"name":%s*"([^"]+)"') do
                                                if name ~= primary then
                                                    table.insert(secondaries, name)
                                                    end
                                                    end
                                                    for _, name in ipairs(secondaries) do
                                                        run_cmd("swaymsg output '" .. name .. "' dpms off")
                                                        end
                                                        else
                                                            local raw = exec("wlopm 2>/dev/null")
                                                            for name in raw:gmatch("([%w%-%_]+)") do
                                                                if name ~= primary then
                                                                    table.insert(secondaries, name)
                                                                    end
                                                                    end
                                                                    for _, name in ipairs(secondaries) do
                                                                        run_cmd("wlopm --off '" .. name .. "'")
                                                                        end
                                                                        end
                                                                        end
